pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    // Phase: "idle" | "sidebar" | "desktop" | "handoff"
    property string phase: "idle"
    readonly property bool active: phase !== "idle"
    readonly property bool presentationActive: phase === "desktop" || phase === "handoff"
    readonly property bool waitingHandoff: phase === "handoff"

    property string tileId: ""
    property string screenName: ""
    property Item sourceItem: null
    property real grabLocalX: 0
    property real grabLocalY: 0
    property real presentationPointerX: 0
    property real presentationPointerY: 0
    property real presentationGrabOffsetX: 0
    property real presentationGrabOffsetY: 0
    property real ghostWidth: 0
    property real ghostHeight: 0
    property real hostWidth: 0
    property real hostHeight: 0

    readonly property real ghostX: presentationPointerX - presentationGrabOffsetX
    readonly property real ghostY: presentationPointerY - presentationGrabOffsetY
    readonly property var presentationGhostRect: ({
        x: ghostX,
        y: ghostY,
        width: ghostWidth,
        height: ghostHeight,
        valid: ghostWidth > 0 && ghostHeight > 0
    })

    // Host lookup map: screenName -> desktop viewport Item
    property var desktopHosts: ({})

    signal canceled()
    signal handoffCheckRequested(string cardId)

    function registerHost(screenName, item) {
        const name = String(screenName || "");
        if (!name || !item) return;
        const next = Object.assign({}, desktopHosts);
        next[name] = item;
        desktopHosts = next;
    }

    function unregisterHost(screenName, item) {
        const name = String(screenName || "");
        if (!name || desktopHosts[name] !== item) return;
        const next = Object.assign({}, desktopHosts);
        delete next[name];
        desktopHosts = next;
    }

    function hostFor(screenName) {
        return desktopHosts[String(screenName || "")] || null;
    }

    function mapItemPoint(screenName, item, localX, localY) {
        const host = hostFor(screenName);
        if (!host || !item) return null;
        const globalPt = item.mapToGlobal(Number(localX), Number(localY));
        const localPt = host.mapFromGlobal(globalPt);
        return { x: Number(localPt.x), y: Number(localPt.y) };
    }

    function mapItemRect(screenName, item) {
        const host = hostFor(screenName);
        if (!host || !item) return null;
        const tl = host.mapFromGlobal(item.mapToGlobal(0, 0));
        const br = host.mapFromGlobal(item.mapToGlobal(Number(item.width), Number(item.height)));
        return {
            x: Number(tl.x),
            y: Number(tl.y),
            width: Math.abs(Number(br.x) - Number(tl.x)),
            height: Math.abs(Number(br.y) - Number(tl.y))
        };
    }

    function resolveDesktopDrop(screenName, tileId, x, y, width, height) {
        const host = hostFor(screenName);
        if (!host || typeof host.resolveDesktopDrop !== "function") return null;
        return host.resolveDesktopDrop(String(tileId), Number(x), Number(y), Number(width), Number(height));
    }

    function begin(cardId, item, grabX, grabY) {
        if (root.active) return false;
        root.tileId = String(cardId || "");
        root.sourceItem = item;
        root.grabLocalX = Number(grabX) || 0;
        root.grabLocalY = Number(grabY) || 0;
        root.phase = "sidebar";
        return true;
    }

    function promoteToDesktop(screenName, pointerX, pointerY, grabOffX, grabOffY, w, h, hostW, hostH) {
        if (root.phase !== "sidebar") return false;
        root.screenName = String(screenName || "");
        root.presentationPointerX = Number(pointerX) || 0;
        root.presentationPointerY = Number(pointerY) || 0;
        root.presentationGrabOffsetX = Number(grabOffX) || 0;
        root.presentationGrabOffsetY = Number(grabOffY) || 0;
        root.ghostWidth = Math.max(0, Number(w) || 0);
        root.ghostHeight = Math.max(0, Number(h) || 0);
        root.hostWidth = Math.max(1, Number(hostW) || 1);
        root.hostHeight = Math.max(1, Number(hostH) || 1);
        root.phase = "desktop";
        return root.presentationGhostRect.valid;
    }

    function update(pointerX, pointerY) {
        if (root.phase !== "desktop") return;
        root.presentationPointerX = Number(pointerX) || 0;
        root.presentationPointerY = Number(pointerY) || 0;
    }

    function commitDrop(topLeftX, topLeftY) {
        if (root.phase !== "desktop") return false;
        if (isFinite(Number(topLeftX)) && isFinite(Number(topLeftY))) {
            root.presentationPointerX = Number(topLeftX) + root.presentationGrabOffsetX;
            root.presentationPointerY = Number(topLeftY) + root.presentationGrabOffsetY;
        }
        root.phase = "handoff";
        return true;
    }

    function requestHandoffCheck(cardId) {
        if (root.phase === "handoff" && String(cardId) === root.tileId) {
            root.handoffCheckRequested(String(cardId));
        }
    }

    function completeHandoff(cardId) {
        if (root.phase !== "handoff" || String(cardId) !== root.tileId) return false;
        clear();
        return true;
    }

    function cancel() {
        if (!root.active) return;
        if (root.phase === "handoff") return;
        clear();
        root.canceled();
    }

    function clear() {
        root.phase = "idle";
        root.tileId = "";
        root.screenName = "";
        root.sourceItem = null;
        root.grabLocalX = 0;
        root.grabLocalY = 0;
        root.presentationPointerX = 0;
        root.presentationPointerY = 0;
        root.presentationGrabOffsetX = 0;
        root.presentationGrabOffsetY = 0;
        root.ghostWidth = 0;
        root.ghostHeight = 0;
        root.hostWidth = 0;
        root.hostHeight = 0;
    }
}
