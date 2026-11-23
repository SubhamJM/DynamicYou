pragma Singleton
import QtQuick
import Quickshell
import "I18nCore.js" as Core
import "Translations.js" as Translations

Singleton {
    id: root

    readonly property string localeCode: Core.envLocale(Quickshell.env("LC_ALL"), Quickshell.env("LC_MESSAGES"), Quickshell.env("LANG"))
    readonly property string language: Core.resolve("auto", root.localeCode, Object.keys(Translations.catalogues))

    function tr(text, ...args) {
        return Core.tr(Translations.catalogues[root.language], text, args);
    }
}
