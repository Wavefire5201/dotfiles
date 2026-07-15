import QtQuick
import Quickshell.Io
import qs.Services.UI

Item {
  id: root
  property var pluginApi: null

  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})
  property bool enableToast: cfg.enableToast ?? defaults.enableToast ?? true
  property int pollInterval: cfg.pollInterval ?? defaults.pollInterval ?? 500
  property string mappingsStr: cfg.mappings ?? defaults.mappings ?? "keyboard-us=US,mozc=JP,pinyin=ZH"

  property string currentIm: ""
  property string currentImLabel: ""
  property int currentState: 0

  property var mappings: {
    var result = {};
    var pairs = mappingsStr.split(",");
    for (var i = 0; i < pairs.length; i++) {
      var parts = pairs[i].split("=");
      if (parts.length === 2) {
        result[parts[0].trim()] = parts[1].trim();
      }
    }
    return result;
  }

  function getLabel(imName) {
    return mappings[imName] || imName;
  }

  Process {
    id: getImProcess
    running: false
    command: ["fcitx5-remote", "-n"]
    stdout: StdioCollector {
      onStreamFinished: {
        var im = this.text.trim();
        if (im && im !== root.currentIm) {
          var oldLabel = root.currentImLabel;
          root.currentIm = im;
          root.currentImLabel = root.getLabel(im);

          if (root.enableToast && oldLabel !== "" && oldLabel !== root.currentImLabel) {
            ToastService.showNotice(
              root.currentImLabel,
              "",
              "keyboard",
              1500
            );
          }
        }
      }
    }
  }

  Process {
    id: getStateProcess
    running: false
    command: ["fcitx5-remote"]
    stdout: StdioCollector {
      onStreamFinished: {
        var state = parseInt(this.text.trim());
        if (!isNaN(state)) {
          root.currentState = state;
        }
      }
    }
  }

  Timer {
    interval: root.pollInterval
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: {
      getImProcess.running = true;
      getStateProcess.running = true;
    }
  }

  property bool isActive: currentState === 2
}
