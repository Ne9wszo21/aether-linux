#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QProcess>
#include <QTimer>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QVariantList>
#include <QVariantMap>
#include <QStringList>
#include <QUrl>
#include <QObject>
#include <QCoreApplication>
#include <QProcess>
#include <QRegularExpression>
#include <QTemporaryFile>
#include <QFile>
#include <unistd.h>
#include <QStandardPaths>
#include <QIcon>

// Read-only drive discovery via `lsblk`. Runs asynchronously so the UI (and its
// animations) never block. It never partitions, formats, mounts or erases anything.
// Aether needs at least 8 GB (decimal) to install.
static constexpr double kMinInstallBytes = 8000000000.0;

class DiskScanner final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList devices READ devices NOTIFY devicesChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QVariantList partitions READ partitions NOTIFY devicesChanged)
    Q_PROPERTY(bool hasPartitioner READ hasPartitioner CONSTANT)

public:
    explicit DiskScanner(QObject *parent = nullptr) : QObject(parent)
    {
        m_timeout.setSingleShot(true);
        m_timeout.setInterval(5000);
        connect(&m_timeout, &QTimer::timeout, this, [this] {
            m_timedOut = true;
            if (m_process)
                m_process->kill();
        });
    }

    QVariantList devices() const { return m_devices; }
    QString status() const { return m_status; }
    QString error() const { return m_error; }
    bool busy() const { return m_busy; }
    QVariantList partitions() const { return m_partitions; }
    bool hasPartitioner() const { return !QStandardPaths::findExecutable(QStringLiteral("gparted")).isEmpty(); }

    Q_INVOKABLE void openPartitioner()
    {
        if (::geteuid() == 0)
            QProcess::startDetached(QStringLiteral("gparted"), {});
        else
            QProcess::startDetached(QStringLiteral("pkexec"), {QStringLiteral("gparted")});
    }

    Q_INVOKABLE void refresh()
    {
        if (m_busy)
            return;

        setBusy(true);
        m_timedOut = false;
        if (!m_error.isEmpty()) {
            m_error.clear();
            emit errorChanged();
        }
        setStatus(QStringLiteral("Checking available drives…"));

        if (m_process) {
            m_process->deleteLater();
            m_process = nullptr;
        }
        m_process = new QProcess(this);
        connect(m_process, &QProcess::errorOccurred, this, [this](QProcess::ProcessError err) {
            if (err == QProcess::FailedToStart) {
                m_timeout.stop();
                fail(QStringLiteral("Could not start lsblk. Install the util-linux package to enable drive detection."));
            }
        });
        connect(m_process, &QProcess::finished, this, [this](int exitCode, QProcess::ExitStatus exitStatus) {
            m_timeout.stop();
            if (m_timedOut) {
                fail(QStringLiteral("Drive detection timed out. Please try refreshing."));
                return;
            }
            if (exitStatus != QProcess::NormalExit || exitCode != 0) {
                const QString detail = QString::fromLocal8Bit(m_process->readAllStandardError()).trimmed();
                fail(detail.isEmpty() ? QStringLiteral("lsblk could not read the available drive list.") : detail);
                return;
            }
            const QByteArray output = m_process->readAllStandardOutput();
            // Short pause so the "scanning" animation is visible instead of flashing by.
            QTimer::singleShot(650, this, [this, output] { applyOutput(output); });
        });

        m_timeout.start();
        m_process->start(QStringLiteral("lsblk"), {
            QStringLiteral("--json"),
            QStringLiteral("--bytes"),
            QStringLiteral("--paths"),
            QStringLiteral("--output"),
            QStringLiteral("NAME,PATH,SIZE,TYPE,MODEL,TRAN,RM,RO,MOUNTPOINTS,FSTYPE,PTTYPE,PARTTYPE,LABEL")
        }, QIODevice::ReadOnly);
    }

signals:
    void devicesChanged();
    void statusChanged();
    void errorChanged();
    void busyChanged();

private:
    QVariantList m_devices;
    QVariantList m_partitions;
    QString m_status = QStringLiteral("Drive detection has not run yet.");
    QString m_error;
    bool m_busy = false;
    bool m_timedOut = false;
    QProcess *m_process = nullptr;
    QTimer m_timeout;

    void setBusy(bool busy)
    {
        if (m_busy == busy)
            return;
        m_busy = busy;
        emit busyChanged();
    }

    void setStatus(const QString &status)
    {
        m_status = status;
        emit statusChanged();
    }

    void fail(const QString &message)
    {
        m_error = message;
        m_devices.clear();
        m_partitions.clear();
        emit devicesChanged();
        emit errorChanged();
        setStatus(QStringLiteral("Drive detection unavailable."));
        setBusy(false);
    }

    void applyOutput(const QByteArray &output)
    {
        QJsonParseError parseError;
        const QJsonDocument document = QJsonDocument::fromJson(output, &parseError);
        if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
            fail(QStringLiteral("Could not parse the drive list returned by lsblk."));
            return;
        }

        QVariantList found;
        QVariantList foundParts;
        const QJsonArray blocks = document.object().value(QStringLiteral("blockdevices")).toArray();
        for (const QJsonValue &value : blocks) {
            if (!value.isObject())
                continue;
            const QJsonObject block = value.toObject();
            if (block.value(QStringLiteral("type")).toString() != QStringLiteral("disk"))
                continue;

            const QString name = block.value(QStringLiteral("name")).toString();
            QString path = block.value(QStringLiteral("path")).toString();
            if (path.isEmpty())
                path = name;

            const double rawSize = block.value(QStringLiteral("size")).toVariant().toDouble();
            const quint64 bytes = rawSize > 0.0 ? static_cast<quint64>(rawSize) : 0;
            const QString model = block.value(QStringLiteral("model")).toString().trimmed();
            const QString transport = block.value(QStringLiteral("tran")).toString().trimmed();
            const bool removable = truthy(block.value(QStringLiteral("rm")));
            const bool readOnly = truthy(block.value(QStringLiteral("ro")));

            QStringList mounts;
            appendMountpoints(block.value(QStringLiteral("mountpoints")), mounts);
            QStringList partitionLines;
            QStringList osHints;
            double partsBytes = 0.0;
            bool hasEsp = false;
            const QJsonArray children = block.value(QStringLiteral("children")).toArray();
            for (const QJsonValue &childValue : children) {
                if (!childValue.isObject())
                    continue;
                const QJsonObject child = childValue.toObject();
                if (child.value(QStringLiteral("type")).toString() != QStringLiteral("part"))
                    continue;
                QString partPath = child.value(QStringLiteral("path")).toString();
                if (partPath.isEmpty())
                    partPath = child.value(QStringLiteral("name")).toString();
                const QString fs = child.value(QStringLiteral("fstype")).toString().trimmed();
                const QString fsl = fs.toLower();
                const QString label = child.value(QStringLiteral("label")).toString().trimmed();
                const bool isEsp = child.value(QStringLiteral("parttype")).toString().toLower()
                    == QStringLiteral("c12a7328-f81f-11d2-ba4b-00a0c93ec93b");
                const double childBytes = child.value(QStringLiteral("size")).toVariant().toDouble();
                partsBytes += childBytes;
                if (isEsp)
                    hasEsp = true;

                QStringList childMounts;
                appendMountpoints(child.value(QStringLiteral("mountpoints")), childMounts);
                for (const QString &mount : std::as_const(childMounts)) {
                    if (!mounts.contains(mount))
                        mounts.append(mount);
                }

                if (!isEsp) {
                    QString hint;
                    if (fsl == QStringLiteral("ntfs") || fsl == QStringLiteral("bitlocker")
                        || label.contains(QStringLiteral("windows"), Qt::CaseInsensitive))
                        hint = QStringLiteral("Windows (NTFS)");
                    else if (fsl == QStringLiteral("ext4") || fsl == QStringLiteral("btrfs") || fsl == QStringLiteral("xfs")
                             || fsl == QStringLiteral("f2fs") || fsl == QStringLiteral("ext3") || fsl == QStringLiteral("ext2"))
                        hint = QStringLiteral("Linux (%1)").arg(fsl);
                    else if (fsl == QStringLiteral("apfs") || fsl == QStringLiteral("hfsplus"))
                        hint = QStringLiteral("macOS");
                    if (!hint.isEmpty() && !osHints.contains(hint))
                        osHints.append(hint);
                }

                QString partLine = partPath;
                if (!fs.isEmpty())
                    partLine += QStringLiteral(" · ") + fs;
                if (!partPath.isEmpty())
                    partitionLines.append(partLine);

                QVariantMap pm;
                pm.insert(QStringLiteral("path"), partPath);
                pm.insert(QStringLiteral("isEsp"), isEsp);
                pm.insert(QStringLiteral("enough"), childBytes >= kMinInstallBytes);
                pm.insert(QStringLiteral("fstype"), fs);
                pm.insert(QStringLiteral("mounted"), !childMounts.isEmpty());
                pm.insert(QStringLiteral("text"), partPath + QStringLiteral("  ·  ")
                    + humanSize(childBytes > 0.0 ? static_cast<quint64>(childBytes) : 0)
                    + QStringLiteral("  ·  ") + (fs.isEmpty() ? QStringLiteral("no filesystem") : fs)
                    + (label.isEmpty() ? QString() : QStringLiteral("  ·  ") + label));
                foundParts.append(pm);
            }

            const bool isGpt = block.value(QStringLiteral("pttype")).toString().toLower() == QStringLiteral("gpt");
            double freeBytes = static_cast<double>(bytes) - partsBytes - 2.0 * 1024 * 1024;
            if (freeBytes < 0.0)
                freeBytes = 0.0;
            const double need = kMinInstallBytes + (hasEsp ? 0.0 : 512.0 * 1024 * 1024);
            const bool alongsideOk = isGpt && freeBytes >= need;
            QString alongsideNote;
            if (!isGpt)
                alongsideNote = QStringLiteral("Needs a GPT disk. This one has no GPT table, so use Erase or Manual.");
            else if (!alongsideOk)
                alongsideNote = QStringLiteral("Insufficient space: only %1 unallocated, Aether needs at least %2. Shrink a partition first.")
                    .arg(humanSize(static_cast<quint64>(freeBytes)), humanSize(static_cast<quint64>(need)));
            else
                alongsideNote = QStringLiteral("Aether will use the largest unallocated block (about %1).")
                    .arg(humanSize(static_cast<quint64>(freeBytes)));

            QStringList badges;
            if (removable)
                badges.append(QStringLiteral("Removable"));
            if (readOnly)
                badges.append(QStringLiteral("Read-only"));
            if (!mounts.isEmpty())
                badges.append(QStringLiteral("Mounted"));
            if (badges.isEmpty())
                badges.append(QStringLiteral("Device detected"));

            QVariantMap item;
            item.insert(QStringLiteral("path"), path);
            item.insert(QStringLiteral("name"), name.isEmpty() ? path : name);
            item.insert(QStringLiteral("modelText"), model.isEmpty() ? QStringLiteral("Model not reported") : model);
            item.insert(QStringLiteral("sizeText"), humanSize(bytes));
            item.insert(QStringLiteral("enoughSpace"), static_cast<double>(bytes) >= kMinInstallBytes);
            item.insert(QStringLiteral("transport"), transport.isEmpty() ? QStringLiteral("Unknown connection") : transport.toUpper());
            item.insert(QStringLiteral("badges"), badges);
            item.insert(QStringLiteral("badgeText"), badges.join(QStringLiteral("  ·  ")));
            item.insert(QStringLiteral("partitionText"), partitionLines.isEmpty()
                ? QStringLiteral("No partitions reported")
                : partitionLines.join(QStringLiteral("   |   ")));
            item.insert(QStringLiteral("freeText"), humanSize(static_cast<quint64>(freeBytes)));
            item.insert(QStringLiteral("hasEsp"), hasEsp);
            item.insert(QStringLiteral("isGpt"), isGpt);
            item.insert(QStringLiteral("alongsideOk"), alongsideOk);
            item.insert(QStringLiteral("alongsideNote"), alongsideNote);
            item.insert(QStringLiteral("otherOsText"), osHints.join(QStringLiteral("  ·  ")));
            item.insert(QStringLiteral("mountText"), mounts.isEmpty()
                ? QStringLiteral("No mountpoints reported")
                : QStringLiteral("Mounted at: ") + mounts.join(QStringLiteral(", ")));
            found.append(item);
        }

        m_devices = found;
        m_partitions = foundParts;
        emit devicesChanged();
        setStatus(found.isEmpty()
            ? QStringLiteral("No physical disks were reported by lsblk.")
            : QStringLiteral("Found %1 disk(s). Information only — no drives have been changed.").arg(found.size()));
        setBusy(false);
    }

    // lsblk prints booleans as true/false or 0/1 depending on version.
    static bool truthy(const QJsonValue &value)
    {
        if (value.isBool())
            return value.toBool();
        if (value.isString()) {
            const QString s = value.toString().trimmed().toLower();
            return s == QStringLiteral("1") || s == QStringLiteral("true");
        }
        return value.toInt(0) != 0;
    }

    static void appendMountpoints(const QJsonValue &value, QStringList &result)
    {
        if (value.isString()) {
            const QString mount = value.toString().trimmed();
            if (!mount.isEmpty() && !result.contains(mount))
                result.append(mount);
        } else if (value.isArray()) {
            const QJsonArray array = value.toArray();
            for (const QJsonValue &item : array) {
                if (item.isString()) {
                    const QString mount = item.toString().trimmed();
                    if (!mount.isEmpty() && !result.contains(mount))
                        result.append(mount);
                }
            }
        }
    }

    static QString humanSize(quint64 bytes)
    {
        if (bytes == 0)
            return QStringLiteral("Unknown size");
        const char *units[] = {"B", "KB", "MB", "GB", "TB", "PB"};
        double amount = static_cast<double>(bytes);
        int unit = 0;
        while (amount >= 1024.0 && unit < 5) {
            amount /= 1024.0;
            ++unit;
        }
        return QStringLiteral("%1 %2").arg(amount, 0, 'f', unit == 0 ? 0 : 1).arg(QString::fromLatin1(units[unit]));
    }
};

// Runs the real installation: a generated bash script (partition, format, pacstrap,
// configure, GRUB). Progress and log lines stream back to the UI. With --dry-run
// (or AETHER_DRYRUN=1) the script only prints the commands it would run.
class SystemInstaller final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool running READ running NOTIFY stateChanged)
    Q_PROPERTY(bool finished READ finished NOTIFY stateChanged)
    Q_PROPERTY(bool failed READ failed NOTIFY stateChanged)
    Q_PROPERTY(double progress READ progress NOTIFY stateChanged)
    Q_PROPERTY(QString stage READ stage NOTIFY stateChanged)
    Q_PROPERTY(QString error READ error NOTIFY stateChanged)
    Q_PROPERTY(QString log READ log NOTIFY logChanged)
    Q_PROPERTY(bool dryRun READ dryRun CONSTANT)

public:
    explicit SystemInstaller(DiskScanner *scanner, QObject *parent = nullptr)
        : QObject(parent), m_scanner(scanner)
    {
        m_dryRun = QCoreApplication::arguments().contains(QStringLiteral("--dry-run"))
            || qEnvironmentVariableIsSet("AETHER_DRYRUN");
        m_flush.setInterval(120);
        connect(&m_flush, &QTimer::timeout, this, [this] { flushLog(); });
    }

    bool running() const { return m_running; }
    bool finished() const { return m_finished; }
    bool failed() const { return m_failed; }
    double progress() const { return m_progress; }
    QString stage() const { return m_stage; }
    QString error() const { return m_error; }
    QString log() const { return m_log; }
    bool dryRun() const { return m_dryRun; }

    Q_INVOKABLE void reset()
    {
        if (m_running)
            return;
        m_finished = false;
        m_failed = false;
        m_progress = 0.0;
        m_stage.clear();
        m_error.clear();
        m_log.clear();
        m_pending.clear();
        emit stateChanged();
        emit logChanged();
    }

    Q_INVOKABLE void reboot()
    {
        if (!m_dryRun)
            QProcess::startDetached(QStringLiteral("systemctl"), {QStringLiteral("reboot")});
    }

    Q_INVOKABLE void start(const QVariantMap &cfg)
    {
        if (m_running)
            return;
        reset();

        const QString mode = cfg.value(QStringLiteral("mode")).toString();
        const QString disk = cfg.value(QStringLiteral("disk")).toString();
        const QString rootPart = cfg.value(QStringLiteral("rootPart")).toString();
        const QString espPart = cfg.value(QStringLiteral("espPart")).toString();
        const bool formatEsp = cfg.value(QStringLiteral("formatEsp")).toBool();
        const QString tz = cfg.value(QStringLiteral("timezone")).toString();
        const QString locale = cfg.value(QStringLiteral("locale")).toString();
        const QString keymap = cfg.value(QStringLiteral("keymap")).toString();
        const QString host = cfg.value(QStringLiteral("hostname")).toString();
        const QString user = cfg.value(QStringLiteral("username")).toString();
        QString fullName = cfg.value(QStringLiteral("fullName")).toString();
        QString password = cfg.value(QStringLiteral("password")).toString();

        fullName.remove(QRegularExpression(QStringLiteral("[\\x00-\\x1f:,]")));
        fullName = fullName.trimmed();
        password.remove(QRegularExpression(QStringLiteral("[\\r\\n]")));

        const QString devRe = QStringLiteral("/dev/[A-Za-z0-9._/-]+");
        if (mode != QStringLiteral("erase") && mode != QStringLiteral("alongside") && mode != QStringLiteral("manual"))
            return rejectStart(QStringLiteral("Unknown install mode."));

        if (mode == QStringLiteral("manual")) {
            bool rootOk = false, espOk = false, rootEnough = false;
            for (const QVariant &p : m_scanner->partitions()) {
                const QString path = p.toMap().value(QStringLiteral("path")).toString();
                if (path == rootPart) { rootOk = true; rootEnough = p.toMap().value(QStringLiteral("enough")).toBool(); }
                if (path == espPart) espOk = true;
            }
            if (!rootOk || !espOk || rootPart == espPart || !matches(rootPart, devRe) || !matches(espPart, devRe)
                || rootPart.contains(QStringLiteral("..")) || espPart.contains(QStringLiteral("..")))
                return rejectStart(QStringLiteral("Choose a root partition and a different EFI partition from the detected list."));
            if (!rootEnough)
                return rejectStart(QStringLiteral("Insufficient space: the root partition needs at least 8 GB."));
        } else {
            bool diskKnown = false, alongsideOk = false, enoughSpace = false;
            for (const QVariant &d : m_scanner->devices()) {
                const QVariantMap dm = d.toMap();
                if (dm.value(QStringLiteral("path")).toString() == disk) {
                    diskKnown = true;
                    alongsideOk = dm.value(QStringLiteral("alongsideOk")).toBool();
                    enoughSpace = dm.value(QStringLiteral("enoughSpace")).toBool();
                }
            }
            if (!diskKnown || !matches(disk, devRe) || disk.contains(QStringLiteral("..")))
                return rejectStart(QStringLiteral("The selected drive is not in the detected drive list."));
            if (mode == QStringLiteral("erase") && !enoughSpace)
                return rejectStart(QStringLiteral("Insufficient space: the drive needs at least 8 GB."));
            if (mode == QStringLiteral("alongside") && !alongsideOk)
                return rejectStart(QStringLiteral("This drive does not have enough unallocated space to install alongside."));
        }
        if (!matches(tz, QStringLiteral("[A-Za-z0-9_+-]+(/[A-Za-z0-9_+-]+)*")))
            return rejectStart(QStringLiteral("Invalid time zone."));
        if (!matches(locale, QStringLiteral("[a-z]{2,3}_[A-Z]{2}\\.UTF-8")))
            return rejectStart(QStringLiteral("Invalid locale."));
        if (!matches(keymap, QStringLiteral("[A-Za-z0-9_-]+")))
            return rejectStart(QStringLiteral("Invalid keyboard layout."));
        if (!matches(host, QStringLiteral("[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?")))
            return rejectStart(QStringLiteral("Invalid computer name."));
        if (!matches(user, QStringLiteral("[a-z_][a-z0-9_-]{0,31}")))
            return rejectStart(QStringLiteral("Invalid username."));
        const bool strong = cfg.value(QStringLiteral("strongPassword"), true).toBool();
        if (strong) {
            if (password.size() < 8)
                return rejectStart(QStringLiteral("Password must be at least 8 characters."));
            int score = 1;
            if (password.size() >= 12)
                score++;
            if (password.contains(QRegularExpression(QStringLiteral("[a-z]"))) && password.contains(QRegularExpression(QStringLiteral("[A-Z]"))))
                score++;
            if (password.contains(QRegularExpression(QStringLiteral("\\d"))) && password.contains(QRegularExpression(QStringLiteral("[^A-Za-z0-9]"))))
                score++;
            if (score < 3)
                return rejectStart(QStringLiteral("Password is too weak."));
        } else if (password.isEmpty()) {
            return rejectStart(QStringLiteral("Password is empty."));
        }

        auto kv = [](const QString &k, const QString &v) {
            return k + QLatin1Char('=') + quote(v) + QLatin1Char('\n');
        };
        QString script = QStringLiteral("#!/usr/bin/env bash\n");
        script += kv(QStringLiteral("DRY"), m_dryRun ? QStringLiteral("1") : QStringLiteral("0"));
        script += kv(QStringLiteral("MODE"), mode);
        script += kv(QStringLiteral("DISK"), mode == QStringLiteral("manual") ? QString() : disk);
        script += kv(QStringLiteral("ROOT_PART"), mode == QStringLiteral("manual") ? rootPart : QString());
        script += kv(QStringLiteral("ESP_PART"), mode == QStringLiteral("manual") ? espPart : QString());
        script += kv(QStringLiteral("FORMAT_ESP"), formatEsp ? QStringLiteral("1") : QStringLiteral("0"));
        script += kv(QStringLiteral("TZ_NAME"), tz);
        script += kv(QStringLiteral("LOCALE"), locale);
        script += kv(QStringLiteral("KEYMAP"), keymap);
        script += kv(QStringLiteral("HOST_NAME"), host);
        script += kv(QStringLiteral("USERNAME"), user);
        QString live = qEnvironmentVariable("AETHER_LIVE_USER", QStringLiteral("aether"));
        if (!matches(live, QStringLiteral("[a-z_][a-z0-9_-]{0,31}")) || live == QStringLiteral("root"))
            live = QStringLiteral("aether");
        script += kv(QStringLiteral("LIVE_USER"), live);
        script += kv(QStringLiteral("FULLNAME"), fullName);
        script += QString::fromLatin1(kScriptBody);

        auto *file = new QTemporaryFile(QStringLiteral("/tmp/aether-install-XXXXXX.sh"), this);
        file->setAutoRemove(false);
        if (!file->open())
            return rejectStart(QStringLiteral("Could not create the install script."));
        file->write(script.toUtf8());
        file->close();
        m_scriptPath = file->fileName();
        file->deleteLater();

        m_buffer.clear();
        m_running = true;
        setStage(QStringLiteral("Starting…"), 0.01);

        m_process = new QProcess(this);
        m_process->setProcessChannelMode(QProcess::MergedChannels);
        connect(m_process, &QProcess::readyRead, this, [this] { consume(m_process->readAll()); });
        connect(m_process, &QProcess::errorOccurred, this, [this](QProcess::ProcessError err) {
            if (err == QProcess::FailedToStart)
                done(-1, QStringLiteral("Could not start the installer process (is bash/pkexec installed?)."));
        });
        connect(m_process, &QProcess::finished, this, [this](int code, QProcess::ExitStatus st) {
            if (!m_buffer.isEmpty()) {
                handleLine(QString::fromUtf8(m_buffer));
                m_buffer.clear();
            }
            done(st == QProcess::NormalExit ? code : -1, QString());
        });

        connect(m_process, &QProcess::started, this, [this, pw = password.toUtf8()] {
            m_process->write(pw + '\n');
            m_process->closeWriteChannel();
        });

        m_flush.start();
        const bool needsRoot = !m_dryRun && ::geteuid() != 0;
        if (needsRoot)
            m_process->start(QStringLiteral("pkexec"), {QStringLiteral("bash"), m_scriptPath});
        else
            m_process->start(QStringLiteral("bash"), {m_scriptPath});
        // The password goes over stdin, never onto a command line or into the script file.
    }

signals:
    void stateChanged();
    void logChanged();

private:
    DiskScanner *m_scanner;
    QProcess *m_process = nullptr;
    QTimer m_flush;
    QString m_scriptPath;
    QByteArray m_buffer;
    QString m_log, m_pending, m_stage, m_error;
    double m_progress = 0.0;
    bool m_running = false, m_finished = false, m_failed = false, m_dryRun = false;

    static bool matches(const QString &s, const QString &re)
    {
        return QRegularExpression(QStringLiteral("^(?:%1)$").arg(re)).match(s).hasMatch();
    }

    static QString quote(QString s)
    {
        s.replace(QLatin1Char('\''), QStringLiteral("'\\''"));
        return QLatin1Char('\'') + s + QLatin1Char('\'');
    }

    void rejectStart(const QString &message)
    {
        m_failed = true;
        m_error = message;
        emit stateChanged();
    }

    void setStage(const QString &stage, double progress)
    {
        m_stage = stage;
        m_progress = qBound(m_progress, progress, 1.0);
        emit stateChanged();
    }

    void consume(QByteArray data)
    {
        data.replace('\r', '\n');
        m_buffer += data;
        int nl;
        while ((nl = m_buffer.indexOf('\n')) >= 0) {
            handleLine(QString::fromUtf8(m_buffer.left(nl)));
            m_buffer.remove(0, nl + 1);
        }
    }

    void handleLine(const QString &raw)
    {
        const QString line = raw.trimmed();
        if (line.isEmpty())
            return;
        if (line.startsWith(QStringLiteral("@@STEP "))) {
            const QStringList parts = line.mid(7).split(QLatin1Char('|'));
            if (parts.size() == 2)
                setStage(parts.at(1), parts.at(0).toDouble());
            m_pending += QStringLiteral("» ") + parts.value(1) + QLatin1Char('\n');
        } else if (line.startsWith(QStringLiteral("@@P "))) {
            const double p = line.mid(4).toDouble();
            if (p > m_progress) {
                m_progress = p;
                emit stateChanged();
            }
        } else {
            if (line.startsWith(QStringLiteral("ERROR:")))
                m_error = line.mid(6).trimmed();
            m_pending += line + QLatin1Char('\n');
        }
    }

    void flushLog()
    {
        if (m_pending.isEmpty())
            return;
        m_log += m_pending;
        m_pending.clear();
        if (m_log.size() > 60000)
            m_log = m_log.right(50000);
        emit logChanged();
    }

    void done(int code, const QString &forced)
    {
        if (!m_running)
            return;
        m_flush.stop();
        flushLog();
        m_running = false;
        QFile::remove(m_scriptPath);
        if (m_process) {
            m_process->deleteLater();
            m_process = nullptr;
        }
        if (code == 0 && forced.isEmpty()) {
            m_finished = true;
            m_progress = 1.0;
            m_stage = QStringLiteral("Installation complete");
        } else {
            m_failed = true;
            if (!forced.isEmpty())
                m_error = forced;
            else if (code == 126 || code == 127)
                m_error = QStringLiteral("Administrator authentication was cancelled or is unavailable (pkexec).");
            else if (m_error.isEmpty())
                m_error = QStringLiteral("The installer stopped unexpectedly (exit code %1).").arg(code);
        }
        emit stateChanged();
    }

    static constexpr const char *kScriptBody = R"SH(
set -Eeuo pipefail
trap 'echo "ERROR: a step failed (line $LINENO): $BASH_COMMAND"' ERR
IFS= read -r PASSWORD || true
T=/mnt/aether-target
ESP_GUID=c12a7328-f81f-11d2-ba4b-00a0c93ec93b
FMT_ESP="$FORMAT_ESP"

step() { echo "@@STEP $1|$2"; }
run() { if [ "$DRY" = 1 ]; then echo "+ $*"; sleep 0.3; else "$@"; fi; }
put() {
  local app=0
  if [ "$1" = "-a" ]; then app=1; shift; fi
  if [ "$DRY" = 1 ]; then echo "+ write $1"; cat >/dev/null
  elif [ "$app" = 1 ]; then cat >> "$1"
  else cat > "$1"; fi
}
fail() { echo "ERROR: $*"; exit 1; }
cleanup() { if [ "$DRY" != 1 ]; then umount -R "$T" 2>/dev/null || true; fi; }
trap cleanup EXIT
mounted_any() { [ -n "$(lsblk -nr -o MOUNTPOINTS "$1" 2>/dev/null | tr -d '[:space:]')" ]; }

step 0.02 "Checking this system"
if [ "$DRY" != 1 ]; then
  [ "$(id -u)" = 0 ] || fail "The installer must run as root."
  [ -d /sys/firmware/efi ] || fail "This installer needs the computer to be booted in UEFI mode."
  for c in sgdisk wipefs mkfs.fat mkfs.btrfs btrfs rsync genfstab arch-chroot partprobe blkid lsblk blockdev; do
    command -v "$c" >/dev/null 2>&1 || fail "Missing required tool: $c"
  done
  if [ "$MODE" = manual ]; then
    [ -b "$ROOT_PART" ] || fail "$ROOT_PART is not a block device."
    [ "$(blockdev --getsize64 "$ROOT_PART")" -ge 8000000000 ] || fail "Insufficient space: $ROOT_PART needs at least 8 GB."
    [ -b "$ESP_PART" ] || fail "$ESP_PART is not a block device."
    mounted_any "$ROOT_PART" && fail "$ROOT_PART is mounted. Unmount it first."
  else
    [ -b "$DISK" ] || fail "$DISK is not a block device."
    [ "$(blockdev --getsize64 "$DISK")" -ge 8000000000 ] || fail "Insufficient space: $DISK needs at least 8 GB."
    case "$(lsblk -nr -o MOUNTPOINTS "$DISK")" in
      *archiso*) fail "$DISK holds the installation media you booted from." ;;
    esac
    if [ "$MODE" = erase ] && mounted_any "$DISK"; then
      fail "$DISK (or one of its partitions) is mounted. It may be the drive you booted from."
    fi
  fi
  ping -c1 -W4 archlinux.org >/dev/null 2>&1 || fail "No internet connection. Connect to a network and try again."
fi

case "$DISK" in *[0-9]) P="${DISK}p" ;; *) P="$DISK" ;; esac
EFI=""
ROOT=""

step 0.06 "Preparing the drive"
case "$MODE" in
  erase)
    run wipefs -af "$DISK"
    run sgdisk --zap-all "$DISK"
    run sgdisk -n1:0:+512M -t1:ef00 -c1:AETHER-EFI -n2:0:0 -t2:8300 -c2:AETHER-ROOT "$DISK"
    EFI="${P}1"; ROOT="${P}2"; FMT_ESP=1
    ;;
  alongside)
    if [ "$DRY" = 1 ]; then
      echo "+ (find the largest unallocated block on $DISK and add partitions there)"
      EFI="${P}1"; ROOT="${P}9"
    else
      [ "$(blkid -p -o value -s PTTYPE "$DISK")" = gpt ] || fail "Installing alongside needs a GPT partition table on $DISK."
      ss=$(blockdev --getss "$DISK")
      first=$(sgdisk -F "$DISK" | tail -n1)
      last=$(sgdisk -E "$DISK" | tail -n1)
      free=$(( (last - first + 1) * ss ))
      need=8000000000
      EFI=$(lsblk -nrpo NAME,PARTTYPE "$DISK" | awk -v g="$ESP_GUID" 'tolower($2)==g { print $1; exit }')
      [ -n "$EFI" ] || need=$(( need + 512 * 1024 * 1024 ))
      [ "$free" -ge "$need" ] || fail "Insufficient space on $DISK. Shrink a partition first (needs about $(( need / 1000000000 )) GB unallocated)."
      n=1
      existing=$(lsblk -nrpo NAME,TYPE "$DISK" | awk '$2=="part" { print $1 }')
      while printf '%s\n' "$existing" | grep -qx "${P}${n}"; do n=$((n + 1)); done
      if [ -z "$EFI" ]; then
        sgdisk -n "$n:0:+512M" -t "$n:ef00" -c "$n:AETHER-EFI" "$DISK"
        EFI="${P}${n}"; FMT_ESP=1; n=$((n + 1))
      fi
      sgdisk -n "$n:0:0" -t "$n:8300" -c "$n:AETHER-ROOT" "$DISK"
      ROOT="${P}${n}"
    fi
    ;;
  manual)
    EFI="$ESP_PART"; ROOT="$ROOT_PART"
    ;;
esac
if [ "$MODE" != manual ]; then
  run partprobe "$DISK" || true
  run partx -a "$DISK" 2>/dev/null || true
  run udevadm settle
  if [ "$DRY" != 1 ]; then
    for i in $(seq 1 20); do [ -b "$ROOT" ] && [ -b "$EFI" ] && break; sleep 0.5; done
    [ -b "$ROOT" ] || fail "The new partition $ROOT did not appear."
  fi
fi

step 0.12 "Formatting"
if [ "$FMT_ESP" = 1 ]; then
  run mkfs.fat -F32 -n AETHERBOOT "$EFI"
elif [ "$DRY" != 1 ] && [ "$(blkid -o value -s TYPE "$EFI")" != vfat ]; then
  fail "$EFI is not FAT. Tick the option to format it, or pick a different EFI partition."
fi
run wipefs -af "$ROOT"
run mkfs.btrfs -f -L aether "$ROOT"

step 0.16 "Creating subvolumes"
run mkdir -p "$T"
run mount "$ROOT" "$T"
run btrfs subvolume create "$T/@"
run btrfs subvolume create "$T/@home"
run umount "$T"
run mount -o subvol=@,compress=zstd,noatime "$ROOT" "$T"
run mkdir -p "$T/home" "$T/boot/efi"
run mount -o subvol=@home,compress=zstd,noatime "$ROOT" "$T/home"
run mount "$EFI" "$T/boot/efi"

step 0.20 "Copying the system"
EXCL=(--exclude='/dev/*' --exclude='/proc/*' --exclude='/sys/*' --exclude='/tmp/*' --exclude='/run/*'
      --exclude='/mnt/*' --exclude='/media/*' --exclude='/lost+found' --exclude='/home/*'
      --exclude='/root/*' --exclude='/root/.*' --exclude='/var/cache/pacman/pkg/*' --exclude='/var/log/*'
      --exclude='/etc/fstab' --exclude='/etc/machine-id' --exclude='/etc/hostname'
      --exclude='/etc/pacman.d/gnupg/*')
if [ "$DRY" = 1 ]; then
  echo "+ rsync -aAXHx / $T/"
  for p in 20 40 60 80 100; do echo "@@P $(awk -v p="$p" 'BEGIN { printf "%.3f", 0.20 + 0.42 * p / 100 }')"; sleep 0.4; done
else
  last=""
  set +o pipefail
  rsync -aAXHx --numeric-ids --no-inc-recursive --info=progress2,name0,stats0 "${EXCL[@]}" / "$T/" 2>&1 \
    | tr '\r' '\n' | while IFS= read -r l; do
      if [[ $l =~ ([0-9]+)% ]]; then
        pc="${BASH_REMATCH[1]}"
        if [ "$pc" != "$last" ]; then
          last="$pc"
          echo "@@P $(awk -v p="$pc" 'BEGIN { printf "%.3f", 0.20 + 0.42 * p / 100 }')"
        fi
      elif [ -n "$l" ]; then
        echo "$l"
      fi
    done
  rc="${PIPESTATUS[0]}"
  set -o pipefail
  if [ "$rc" != 0 ] && [ "$rc" != 24 ]; then fail "Copying the system failed (rsync exit code $rc)."; fi
fi

step 0.62 "Cleaning up live-session files"
if [ "$DRY" = 1 ]; then echo "+ genfstab -U $T > $T/etc/fstab"; else genfstab -U "$T" > "$T/etc/fstab"; fi
run rm -f "$T/etc/mkinitcpio.conf.d/archiso.conf" "$T/etc/mkinitcpio.d/linux.preset" \
  "$T/etc/systemd/system/getty@tty1.service.d/autologin.conf" "$T/etc/sudoers.d/g_wheel" \
  "$T/etc/systemd/system/pacman-init.service" "$T/etc/systemd/system/etc-pacman.d-gnupg.mount" \
  "$T/etc/systemd/system/multi-user.target.wants/pacman-init.service" \
  "$T/etc/udev/rules.d/81-dhcpcd.rules"
run arch-chroot "$T" systemd-machine-id-setup

step 0.64 "Updating packages (pacman -Syu)"
run arch-chroot "$T" pacman-key --init
run arch-chroot "$T" pacman-key --populate archlinux
PKGS=(linux linux-firmware grub efibootmgr btrfs-progs os-prober ntfs-3g plymouth networkmanager sudo rsync)
if [ "$DRY" = 1 ]; then
  echo "+ arch-chroot $T pacman -Syu --noconfirm --needed ${PKGS[*]}"
  for i in 1 2 3 4; do echo "(dry run) upgrading package $i..."; echo "@@P 0.$((66 + i * 4))"; sleep 0.3; done
  echo "+ arch-chroot $T pacman -S --noconfirm linux"
else
  n=0
  arch-chroot "$T" pacman -Syu --noconfirm --needed "${PKGS[@]}" 2>&1 | while IFS= read -r l; do
    echo "$l"
    case "$l" in
      *"installing "*|*"upgrading "*)
        n=$((n + 1))
        echo "@@P $(awk -v n="$n" 'BEGIN { printf "%.3f", 0.64 + 0.20 * (1 - exp(-n / 40)) }')"
        ;;
    esac
  done
  arch-chroot "$T" pacman -S --noconfirm linux 2>&1
fi

step 0.85 "Configuring the system"
run ln -sf "/usr/share/zoneinfo/$TZ_NAME" "$T/etc/localtime"
run arch-chroot "$T" hwclock --systohc || true
printf '%s\n' "en_US.UTF-8 UTF-8" "$LOCALE UTF-8" | put "$T/etc/locale.gen"
printf 'LANG=%s\n' "$LOCALE" | put "$T/etc/locale.conf"
printf 'KEYMAP=%s\n' "$KEYMAP" | put "$T/etc/vconsole.conf"
printf '%s\n' "$HOST_NAME" | put "$T/etc/hostname"
printf '127.0.0.1 localhost\n::1 localhost\n127.0.1.1 %s\n' "$HOST_NAME" | put "$T/etc/hosts"
run arch-chroot "$T" locale-gen

step 0.875 "Removing the live-session user"
if [ "$DRY" = 1 ]; then
  echo "+ arch-chroot $T userdel -f -r $LIVE_USER"
else
  live_uid=$(arch-chroot "$T" id -u "$LIVE_USER" 2>/dev/null || true)
  if [ -n "$live_uid" ] && [ "$live_uid" -ge 1000 ]; then
    arch-chroot "$T" userdel -f -r "$LIVE_USER" 2>&1 || arch-chroot "$T" userdel -f "$LIVE_USER" 2>&1 || true
    arch-chroot "$T" groupdel "$LIVE_USER" 2>/dev/null || true
  fi
fi
run rm -f "$T"/etc/sudoers.d/*"$LIVE_USER"*
for f in "$T/etc/sddm.conf" "$T"/etc/sddm.conf.d/*.conf "$T/etc/lightdm/lightdm.conf" "$T"/etc/lightdm/lightdm.conf.d/*.conf "$T/etc/gdm/custom.conf"; do
  if [ -f "$f" ]; then
    run sed -i -e "/^User=$LIVE_USER\$/d" -e "/^autologin-user=$LIVE_USER\$/d" -e '/^AutomaticLoginEnable=/d' -e '/^AutomaticLogin=/d' "$f"
  fi
done

step 0.89 "Creating your account and home folder"
run arch-chroot "$T" groupadd -f wheel
run arch-chroot "$T" useradd -m -G wheel -s /bin/bash -c "$FULLNAME" "$USERNAME"
if [ "$DRY" = 1 ]; then
  echo "+ set password for $USERNAME"
else
  printf '%s:%s\n' "$USERNAME" "$PASSWORD" | arch-chroot "$T" chpasswd
fi
run mkdir -p "$T/etc/sudoers.d"
echo '%wheel ALL=(ALL:ALL) ALL' | put "$T/etc/sudoers.d/10-wheel"
run chmod 440 "$T/etc/sudoers.d/10-wheel"
run arch-chroot "$T" passwd -l root
run arch-chroot "$T" systemctl enable NetworkManager

# First-boot welcome: starts once at the new user's first login (it removes itself by writing a done flag).
if [ "$DRY" = 1 ] || [ -x "$T/usr/bin/aether-welcome" ]; then
  run mkdir -p "$T/home/$USERNAME/.config/autostart"
  printf '[Desktop Entry]\nType=Application\nName=Welcome to Aether\nExec=aether-welcome --autostart\nX-GNOME-Autostart-enabled=true\n' \
    | put "$T/home/$USERNAME/.config/autostart/aether-welcome.desktop"
  run arch-chroot "$T" chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/.config"
fi

step 0.93 "Setting up the boot splash"
run arch-chroot "$T" sed -i '/^HOOKS=/{/plymouth/!s/\budev\b/udev plymouth/}' /etc/mkinitcpio.conf
if [ "$DRY" != 1 ] && [ -d "$T/usr/share/plymouth/themes/aether" ]; then THEME=aether; else THEME=spinner; fi
run arch-chroot "$T" plymouth-set-default-theme "${THEME:-spinner}"
run arch-chroot "$T" mkinitcpio -P

step 0.96 "Installing the bootloader"
run arch-chroot "$T" sed -i 's/^GRUB_DISTRIBUTOR=.*/GRUB_DISTRIBUTOR="Aether"/' /etc/default/grub
run arch-chroot "$T" sed -i 's|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet splash"|' /etc/default/grub
run arch-chroot "$T" sed -i '/^#\?GRUB_DISABLE_OS_PROBER/d' /etc/default/grub
echo 'GRUB_DISABLE_OS_PROBER=false' | put -a "$T/etc/default/grub"
run arch-chroot "$T" grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Aether --recheck
# The removable fallback path would overwrite another system's fallback loader, so only use it on a fresh drive.
if [ "$MODE" = erase ]; then
  run arch-chroot "$T" grub-install --target=x86_64-efi --efi-directory=/boot/efi --removable
fi
run arch-chroot "$T" grub-mkconfig -o /boot/grub/grub.cfg

step 0.985 "Removing the installer"
if [ "$DRY" = 1 ]; then
  echo "+ pacman -Rns aether-installer (and delete any leftover installer files)"
else
  # keep what the new system needs even if it first arrived as a dependency of the installer
  arch-chroot "$T" pacman -D --asexplicit "${PKGS[@]}" >/dev/null 2>&1 || true
  if [ -x "$T/usr/bin/aether-welcome" ]; then
    arch-chroot "$T" pacman -D --asexplicit qt6-base qt6-declarative >/dev/null 2>&1 || true
  fi
  if arch-chroot "$T" pacman -Q aether-installer >/dev/null 2>&1; then
    arch-chroot "$T" pacman -Rns --noconfirm aether-installer 2>&1 || true
  fi
  rm -f "$T/usr/bin/aether-installer" "$T/usr/local/bin/aether-installer" \
        "$T/usr/share/applications/aether-installer.desktop" "$T/usr/share/pixmaps/aether-installer.png" \
        "$T"/etc/xdg/autostart/aether-installer*.desktop "$T"/etc/skel/.config/autostart/aether-installer*.desktop
fi

step 0.99 "Finishing up"
run sync
run umount -R "$T"
step 1 "Installation complete"
)SH";
};

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName(QStringLiteral("Aether Installer"));
    QGuiApplication::setWindowIcon(QIcon(QStringLiteral(":/qt/qml/AetherInstaller/assets/aether-logo.png")));
    QQuickStyle::setStyle(QStringLiteral("Material"));

    QQmlApplicationEngine engine;
    DiskScanner diskScanner;
    SystemInstaller systemInstaller(&diskScanner);
    engine.rootContext()->setContextProperty(QStringLiteral("DiskScanner"), &diskScanner);
    engine.rootContext()->setContextProperty(QStringLiteral("SystemInstaller"), &systemInstaller);

    const QUrl url(QStringLiteral("qrc:/qt/qml/AetherInstaller/qml/Main.qml"));
    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreated,
        &app, [url](QObject *obj, const QUrl &objUrl) {
            if (!obj && url == objUrl)
                QCoreApplication::exit(-1);
        },
        Qt::QueuedConnection);

    engine.load(url);
    return app.exec();
}

#include "main.moc"
