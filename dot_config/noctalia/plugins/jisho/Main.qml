import QtQuick
import Quickshell.Io
import qs.Services.UI
import "jisho.js" as Jisho

Item {
  id: root

  property var pluginApi: null

  function openWith(query) {
    pluginApi.withCurrentScreen(screen => PanelService.openLauncherWithSearch(screen, Jisho.PREFIX + " " + query));
  }

  // stdout is empty when wl-paste fails (no selection), which opens the history view
  Process {
    id: selection
    command: ["wl-paste", "--primary", "--no-newline", "--type", "text"]
    stdout: StdioCollector {
      onStreamFinished: root.openWith(Jisho.cleanSelection(text))
    }
  }

  IpcHandler {
    target: "plugin:jisho"

    function toggle() {
      root.pluginApi.withCurrentScreen(screen => root.pluginApi.toggleLauncher(screen));
    }

    function lookup(text: string) {
      root.openWith(Jisho.cleanSelection(text));
    }

    function lookupSelection() {
      if (!selection.running)
        selection.running = true;
    }
  }
}
