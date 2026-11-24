import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: store

    readonly property string script: Quickshell.shellPath("scripts/notes_store.py")
    readonly property bool saving: saveProcess.running || saveTimer.running
    property bool loaded: false
    property string scratchpad: ""
    property int completedCount: 0
    property int revision: 0
    property int savedRevision: 0
    property int writingRevision: 0
    property string error: ""

    property ListModel tasks: ListModel { dynamicRoles: true }

    function ensureLoaded() {
        if (!loaded && !loadProcess.running) loadProcess.running = true;
    }

    function edit(text) {
        if (!loaded || scratchpad === text) return;
        scratchpad = text;
        scheduleSave();
    }

    function addTask(text) {
        const title = text.trim();
        if (!loaded || title === "") return false;
        tasks.append({ id: Date.now(), text: title, done: false });
        scheduleSave();
        return true;
    }

    function toggleTask(index) {
        const done = !tasks.get(index).done;
        tasks.setProperty(index, "done", done);
        completedCount += done ? 1 : -1;
        scheduleSave();
    }

    function removeTask(index) {
        if (tasks.get(index).done) completedCount--;
        tasks.remove(index);
        scheduleSave();
    }

    function clearCompleted() {
        for (let i = tasks.count - 1; i >= 0; i--) {
            if (tasks.get(i).done) tasks.remove(i);
        }
        completedCount = 0;
        scheduleSave();
    }

    function textForTasks(heading = false) {
        const lines = heading ? ["# Tasks & Checklist", ""] : [];
        for (let i = 0; i < tasks.count; i++) {
            const task = tasks.get(i);
            lines.push("- [" + (task.done ? "x" : " ") + "] " + task.text);
        }
        return lines.join("\n");
    }

    function scheduleSave() {
        revision++;
        saveTimer.restart();
    }

    function flush() {
        if (!saveProcess.running && savedRevision !== revision) {
            saveTimer.stop();
            saveProcess.running = true;
        }
    }

    property Timer saveTimer: Timer {
        interval: 280
        onTriggered: store.flush()
    }

    property Process loadProcess: Process {
        command: ["python3", store.script, "load"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    store.scratchpad = data.scratchpad;
                    store.tasks.clear();
                    store.completedCount = 0;
                    for (const task of data.todos) {
                        if (!task || typeof task.text !== "string") continue;
                        store.tasks.append({ id: task.id ?? (Date.now() + store.tasks.count), text: task.text, done: !!task.done });
                        if (task.done) store.completedCount++;
                    }
                    store.error = "";
                    store.loaded = true;
                } catch (_) {
                    store.error = "Couldn’t load notes.";
                }
            }
        }
        onExited: code => {
            if (code !== 0) store.error = "Couldn’t load notes.";
        }
    }

    property Process saveProcess: Process {
        command: ["python3", store.script, "save-stdin"]
        stdinEnabled: true
        onStarted: {
            store.writingRevision = store.revision;
            const todos = [];
            for (let i = 0; i < store.tasks.count; i++) {
                const task = store.tasks.get(i);
                todos.push({ id: task.id, text: task.text, done: task.done });
            }
            write(JSON.stringify({ scratchpad: store.scratchpad, todos }) + "\n");
        }
        onExited: code => {
            if (code === 0) store.savedRevision = store.writingRevision;
            store.error = code === 0 ? "" : "Couldn’t save notes.";
            if (store.writingRevision !== store.revision) saveTimer.restart();
        }
    }
}
