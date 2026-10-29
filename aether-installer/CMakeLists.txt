cmake_minimum_required(VERSION 3.21)
project(AetherInstaller VERSION 0.2 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Gui Quick QuickControls2 Qml)

qt_standard_project_setup(REQUIRES 6.5)

qt_add_executable(aether-installer
    main.cpp
)

set_source_files_properties(
    qml/Theme.qml
    qml/Setup.qml
    PROPERTIES QT_QML_SINGLETON_TYPE TRUE
)

file(GLOB AETHER_ASSETS CONFIGURE_DEPENDS RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} assets/*)

qt_add_qml_module(aether-installer
    URI AetherInstaller
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/Theme.qml
        qml/Setup.qml
        qml/Entrance.qml
        qml/GlowOrb.qml
        qml/Backdrop.qml
        qml/AnimatedLogo.qml
        qml/AetherButton.qml
        qml/AetherField.qml
        qml/AetherCombo.qml
        qml/InfoBanner.qml
        qml/Card.qml
        qml/PageBase.qml
        qml/Sidebar.qml
        qml/OrbitGlobe.qml
        qml/KeyboardPreview.qml
        qml/DiskCard.qml
        qml/WelcomePage.qml
        qml/LocationPage.qml
        qml/KeyboardPage.qml
        qml/DiskPage.qml
        qml/UserPage.qml
        qml/SummaryPage.qml
        qml/InstallPage.qml
        qml/CookieShape.qml
        qml/DonePage.qml
    RESOURCES
        ${AETHER_ASSETS}
)

target_link_libraries(aether-installer PRIVATE
    Qt6::Gui
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Qml
)

install(TARGETS aether-installer
    RUNTIME DESTINATION bin
)
install(FILES aether-installer.desktop DESTINATION share/applications)
install(FILES assets/aether-logo.png DESTINATION share/pixmaps RENAME aether-installer.png)
