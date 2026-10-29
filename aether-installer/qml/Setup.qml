pragma Singleton
import QtQuick

// Shared installer state. Nothing touches the system until the Install page starts SystemInstaller.
QtObject {
    id: root

    readonly property var pageNames: ["Welcome", "Location", "Keyboard", "Disk", "User", "Summary", "Install"]
    readonly property int lastStep: 6
    readonly property int installPage: 6
    readonly property int donePage: 7

    property int currentPage: 0
    property int maxVisited: 0

    readonly property string nextLabel: currentPage === 0 ? "Get started"
        : (currentPage === 5 ? "Install Aether" : "Continue")

    // ---- Choices ----
    readonly property var regionOptions: ["Singapore", "United Kingdom", "United States", "Japan", "Australia"]
    readonly property var timeZoneOptions: ["Asia/Singapore", "Europe/London", "America/New_York", "Asia/Tokyo", "Australia/Sydney", "UTC"]
    readonly property var keyboardOptions: ["English (US)", "English (UK)", "German", "French", "Japanese"]
    readonly property var regionZones: ({
        "Singapore": "Asia/Singapore", "United Kingdom": "Europe/London",
        "United States": "America/New_York", "Japan": "Asia/Tokyo", "Australia": "Australia/Sydney"
    })
    readonly property var regionLocales: ({
        "Singapore": "en_SG.UTF-8", "United Kingdom": "en_GB.UTF-8", "United States": "en_US.UTF-8",
        "Japan": "ja_JP.UTF-8", "Australia": "en_AU.UTF-8"
    })
    readonly property var keymaps: ({
        "English (US)": "us", "English (UK)": "uk", "German": "de-latin1", "French": "fr", "Japanese": "jp106"
    })
    readonly property var zoneOffsets: ({
        "Asia/Singapore": "UTC+8", "Europe/London": "UTC+0 (UTC+1 in summer)",
        "America/New_York": "UTC-5 (UTC-4 in summer)", "Asia/Tokyo": "UTC+9",
        "Australia/Sydney": "UTC+10 (UTC+11 in summer)", "UTC": "UTC+0"
    })

    property string selectedRegion: "Singapore"
    property string selectedTimeZone: "Asia/Singapore"
    property string selectedKeyboard: "English (US)"
    property string keyboardTestText: ""
    property string installMode: "erase"      // "erase" | "alongside" | "manual"
    property string selectedDisk: ""
    property string selectedDiskLabel: ""
    property string selectedRoot: ""
    property string selectedEsp: ""
    property bool formatEsp: false
    property bool rootEnough: true

    property string fullName: ""
    property string username: ""
    property bool usernameEdited: false
    property string hostname: "aether"
    property string password: ""
    property string passwordConfirm: ""
    property bool requireStrongPassword: true
    property bool showErrors: false
    property bool confirmErase: false
    property bool showDiskError: false
    property bool showConfirmError: false

    signal validationFailed()

    function pickRegion(name) {
        selectedRegion = name
        if (regionZones[name])
            selectedTimeZone = regionZones[name]
    }

    function setFullName(value) {
        fullName = value
        if (!usernameEdited) {
            var first = value.trim().split(/\s+/)[0].toLowerCase().replace(/[^a-z0-9_-]/g, "").replace(/^[0-9-]+/, "")
            username = first
        }
    }

    function setUsername(value) {
        usernameEdited = value.length > 0
        username = value
    }

    function setInstallMode(mode) {
        if (mode === installMode)
            return
        installMode = mode
        selectedDisk = ""; selectedDiskLabel = ""
        selectedRoot = ""; selectedEsp = ""; formatEsp = false; rootEnough = true
        confirmErase = false
        showDiskError = false
    }

    function selectRoot(path, enough) {
        if (path !== selectedRoot) confirmErase = false
        selectedRoot = path
        rootEnough = enough !== false
        if (path.length > 0 && selectedEsp.length > 0) showDiskError = false
    }

    function selectEsp(path) {
        if (path !== selectedEsp) confirmErase = false
        selectedEsp = path
        if (path.length > 0 && selectedRoot.length > 0) showDiskError = false
    }

    function selectDisk(path, label) {
        if (path !== selectedDisk)
            confirmErase = false
        if (path.length > 0)
            showDiskError = false
        selectedDisk = path
        selectedDiskLabel = label
    }

    // ---- Validation ----
    readonly property string errFullName: fullName.trim().length === 0 ? "Enter your full name." : ""
    readonly property string errUsername: /^[a-z_][a-z0-9_-]{0,31}$/.test(username)
        ? "" : "Lowercase letters, numbers, - and _. Must start with a letter."
    readonly property string errHostname: /^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$/.test(hostname)
        ? "" : "Letters, numbers and hyphens only."
    readonly property string errPassword: requireStrongPassword
        ? (password.length < 8 ? "Use at least 8 characters."
            : (passwordScore < 3 ? "Too weak. Combine two of: 12+ characters, upper and lower case, a number and a symbol." : ""))
        : (password.length < 1 ? "Enter a password." : "")
    readonly property string errConfirm: password !== passwordConfirm ? "Passwords don't match." : ""
    readonly property bool userValid: errFullName === "" && errUsername === "" && errHostname === ""
        && errPassword === "" && errConfirm === ""

    // -1 empty, 0 too short, 1..4 weak..strong
    readonly property bool diskReady: installMode === "manual"
        ? (selectedRoot !== "" && selectedEsp !== "" && selectedRoot !== selectedEsp && rootEnough)
        : selectedDisk !== ""
    readonly property bool canInstall: userValid && diskReady && confirmErase

    readonly property string modeLabel: installMode === "erase" ? "Erase drive (Btrfs)"
        : (installMode === "alongside" ? "Alongside other systems" : "Manual partitioning")
    readonly property string driveSummary: !diskReady ? "Not selected"
        : (installMode === "manual" ? selectedRoot + "  +  " + selectedEsp + " (EFI)"
        : selectedDiskLabel)
    readonly property string confirmText: !diskReady ? "Go back and choose a drive first."
        : (installMode === "erase"
            ? "Erase everything on " + selectedDiskLabel + " and install Aether. This cannot be undone."
            : (installMode === "alongside"
                ? "Add Aether in the free space on " + selectedDiskLabel + ". Existing partitions and systems are kept."
                : "Format " + selectedRoot + " as Btrfs and install Aether. " + selectedEsp + " is kept for the bootloader."))

    readonly property int passwordScore: {
        var p = password
        if (p.length === 0) return -1
        if (p.length < 8) return 0
        var s = 1
        if (p.length >= 12) s++
        if (/[a-z]/.test(p) && /[A-Z]/.test(p)) s++
        if (/\d/.test(p) && /[^A-Za-z0-9]/.test(p)) s++
        return s
    }
    readonly property var scoreLabels: ["Too short", "Weak", "Okay", "Good", "Strong"]
    readonly property var scoreColors: ["#FF8A80", "#FF8A80", "#FFD180", "#6BD7E5", "#7CE8B0"]

    // ---- Navigation ----
    function installConfig() {
        return {
            mode: installMode, disk: selectedDisk,
            rootPart: selectedRoot, espPart: selectedEsp, formatEsp: formatEsp,
            timezone: selectedTimeZone,
            locale: regionLocales[selectedRegion] || "en_US.UTF-8",
            keymap: keymaps[selectedKeyboard] || "us",
            hostname: hostname, username: username, fullName: fullName, password: password,
            strongPassword: requireStrongPassword
        }
    }

    function complete() {
        maxVisited = donePage
        currentPage = donePage
    }

    function next() {
        if (currentPage >= installPage)
            return
        if (currentPage === 3 && !diskReady) {
            showDiskError = true
            return
        }
        if (currentPage === 4 && !userValid) {
            showErrors = true
            validationFailed()
            return
        }
        if (currentPage === 5 && !canInstall) {
            showConfirmError = true
            if (!diskReady) go(3)
            else if (!userValid) { showErrors = true; go(4) }
            return
        }
        currentPage++
        if (currentPage > maxVisited)
            maxVisited = currentPage
    }

    function back() {
        if (currentPage > 0 && currentPage < installPage)
            currentPage--
    }

    function go(page) {
        if (currentPage >= installPage)
            return
        if (page >= 0 && page <= maxVisited && page !== currentPage)
            currentPage = page
    }

    function reset() {
        selectedRegion = "Singapore"; selectedTimeZone = "Asia/Singapore"; selectedKeyboard = "English (US)"
        keyboardTestText = ""; selectedDisk = ""; selectedDiskLabel = ""
        installMode = "erase"; selectedRoot = ""; selectedEsp = ""; formatEsp = false
        fullName = ""; username = ""; usernameEdited = false; hostname = "aether"
        password = ""; passwordConfirm = ""; requireStrongPassword = true; showErrors = false
        confirmErase = false; showDiskError = false; showConfirmError = false
        maxVisited = 0; currentPage = 0
    }
}
