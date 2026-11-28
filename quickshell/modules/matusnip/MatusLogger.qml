pragma Singleton

import QtQuick

QtObject {
    function log(tag, msg) {
    }

    function warn(tag, msg) {
        console.warn("[" + tag + "]", msg)
    }

    function error(tag, msg) {
        console.error("[" + tag + "]", msg)
    }
}
