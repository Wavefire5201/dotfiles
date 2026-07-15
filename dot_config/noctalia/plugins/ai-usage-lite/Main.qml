import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root
  visible: false

  property var pluginApi: null
  property var cfg: pluginApi?.pluginSettings ?? pluginApi?.manifest?.metadata?.defaultSettings ?? ({})

  property string summary: "AI --"
  property string tooltip: "AI Usage Lite"
  property string className: "low"
  property var providers: []
  property string errorText: ""

  readonly property int refreshIntervalSec: cfg.refreshIntervalSec ?? 120
  readonly property string pluginDir: pluginApi?.pluginDir ?? (Quickshell.env("HOME") + "/.config/noctalia/plugins/ai-usage-lite")

  Timer {
    interval: Math.max(15, root.refreshIntervalSec) * 1000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Process {
    id: collector
    running: false
    command: root.collectorCommand()
    stdout: StdioCollector {
      onStreamFinished: root.parseOutput(text)
    }
    stderr: StdioCollector {
      onStreamFinished: {
        if (text.trim().length > 0)
          root.errorText = text.trim();
      }
    }
  }

  function boolArg(enabled) {
    return enabled ? "1" : "0";
  }

  function collectorCommand() {
    return [
      "uv", "run", "--script", root.pluginDir + "/collector.py",
      "--order", cfg.order ?? "claude,codex,opencode",
      "--separator", cfg.separator ?? "  ",
      "--claude-format", cfg.claudeFormat ?? "Cl {session_pct}%",
      "--codex-format", cfg.codexFormat ?? "Cx {session_pct}%",
      "--opencode-format", cfg.opencodeFormat ?? "Go {max_pct}%",
    ].concat(cfg.showOnlyWorst ? ["--only-worst"] : [])
     .concat((cfg.claudeEnabled ?? true) ? ["--claude-enabled"] : [])
     .concat((cfg.codexEnabled ?? true) ? ["--codex-enabled"] : [])
     .concat((cfg.opencodeEnabled ?? true) ? ["--opencode-enabled"] : []);
  }

  function refresh() {
    if (!collector.running)
      collector.running = true;
  }

  function parseOutput(raw) {
    try {
      const data = JSON.parse(raw.trim());
      root.summary = data.summary ?? "AI --";
      root.tooltip = data.tooltip ?? "AI Usage Lite";
      root.className = data.className ?? "low";
      root.providers = data.providers ?? [];
      root.errorText = "";
    } catch (e) {
      root.summary = "AI ⚠";
      root.tooltip = root.errorText || String(e);
      root.className = "critical";
      root.providers = [];
    }
  }
}
