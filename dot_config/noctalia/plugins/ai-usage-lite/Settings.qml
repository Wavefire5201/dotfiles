import QtQuick 6.11
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root
  property var pluginApi: null
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings ?? ({})
  property var cfg: pluginApi?.pluginSettings ?? defaults
  property bool initialized: false

  spacing: Style.marginL

  function saveSettings() {
    if (!initialized || !pluginApi)
      return;
    pluginApi.pluginSettings.refreshIntervalSec = refreshInterval.value;
    pluginApi.pluginSettings.order = orderInput.text.trim().length > 0 ? orderInput.text : defaults.order;
    pluginApi.pluginSettings.separator = separatorInput.text.length > 0 ? separatorInput.text : defaults.separator;
    pluginApi.pluginSettings.showOnlyWorst = onlyWorst.checked;
    pluginApi.pluginSettings.claudeEnabled = claudeToggle.checked;
    pluginApi.pluginSettings.codexEnabled = codexToggle.checked;
    pluginApi.pluginSettings.codex2Enabled = codex2Toggle.checked;
    pluginApi.pluginSettings.antigravityEnabled = antigravityToggle.checked;
    pluginApi.pluginSettings.opencodeEnabled = opencodeToggle.checked;
    pluginApi.pluginSettings.claudeFormat = claudeFormat.text.trim().length > 0 ? claudeFormat.text : defaults.claudeFormat;
    pluginApi.pluginSettings.codexFormat = codexFormat.text.trim().length > 0 ? codexFormat.text : defaults.codexFormat;
    pluginApi.pluginSettings.codex2Format = codex2Format.text.trim().length > 0 ? codex2Format.text : defaults.codex2Format;
    pluginApi.pluginSettings.codex2Profile = codex2Profile.text.trim().length > 0 ? codex2Profile.text : defaults.codex2Profile;
    pluginApi.pluginSettings.codexLabel = codexLabel.text;
    pluginApi.pluginSettings.codex2Label = codex2Label.text;
    pluginApi.pluginSettings.antigravityFormat = antigravityFormat.text.trim().length > 0 ? antigravityFormat.text : defaults.antigravityFormat;
    pluginApi.pluginSettings.opencodeFormat = opencodeFormat.text.trim().length > 0 ? opencodeFormat.text : defaults.opencodeFormat;
    pluginApi.saveSettings();
  }

  Component.onCompleted: Qt.callLater(function() { root.initialized = true; })

  NText {
    text: "AI Usage Lite"
    pointSize: Style.fontSizeXL
    font.weight: Style.fontWeightBold
    color: Color.mOnSurface
  }

  NSpinBox {
    id: refreshInterval
    from: 30
    to: 900
    stepSize: 30
    value: cfg.refreshIntervalSec ?? defaults.refreshIntervalSec ?? 120
    onValueChanged: root.saveSettings()
  }

  NTextInput {
    id: orderInput
    Layout.fillWidth: true
    label: "Provider order"
    description: "Comma-separated: claude,codex,codex2,antigravity,opencode"
    text: cfg.order ?? defaults.order ?? "claude,codex,codex2,antigravity,opencode"
    onTextChanged: root.saveSettings()
  }

  NTextInput {
    id: separatorInput
    Layout.fillWidth: true
    label: "Separator"
    text: cfg.separator ?? defaults.separator ?? "  "
    onTextChanged: root.saveSettings()
  }

  NToggle {
    id: onlyWorst
    checked: cfg.showOnlyWorst ?? false
    onToggled: root.saveSettings()
  }
  NText { text: "Show only the highest usage provider"; color: Color.mOnSurfaceVariant }

  RowLayout {
    NToggle { id: claudeToggle; checked: cfg.claudeEnabled ?? true; onToggled: root.saveSettings() }
    NText { text: "Claude"; color: Color.mOnSurface }
  }
  NTextInput {
    id: claudeFormat
    Layout.fillWidth: true
    label: "Claude format"
    text: cfg.claudeFormat ?? defaults.claudeFormat ?? "Cl {session_pct}%"
    onTextChanged: root.saveSettings()
  }

  RowLayout {
    NToggle { id: codexToggle; checked: cfg.codexEnabled ?? true; onToggled: root.saveSettings() }
    NText { text: "Codex"; color: Color.mOnSurface }
  }
  NTextInput {
    id: codexFormat
    Layout.fillWidth: true
    label: "Codex format"
    text: cfg.codexFormat ?? defaults.codexFormat ?? "Cx {session_pct}%"
    onTextChanged: root.saveSettings()
  }

  NTextInput {
    id: codexLabel
    Layout.fillWidth: true
    label: "Codex workspace name"
    description: "Shown in the tooltip header"
    text: cfg.codexLabel ?? ""
    onTextChanged: root.saveSettings()
  }

  RowLayout {
    NToggle { id: codex2Toggle; checked: cfg.codex2Enabled ?? false; onToggled: root.saveSettings() }
    NText { text: "Codex (2nd workspace)"; color: Color.mOnSurface }
  }
  NTextInput {
    id: codex2Format
    Layout.fillWidth: true
    label: "Codex 2 format"
    description: "Put the workspace name in the literal text, e.g. Cx\u00b7work {session_pct}%"
    text: cfg.codex2Format ?? defaults.codex2Format ?? "Cx2 {session_pct}%"
    onTextChanged: root.saveSettings()
  }
  NTextInput {
    id: codex2Profile
    Layout.fillWidth: true
    label: "Codex 2 profile"
    description: "Folder under ~/.local/share/codex-profiles/ holding that login"
    text: cfg.codex2Profile ?? defaults.codex2Profile ?? "alt"
    onTextChanged: root.saveSettings()
  }

  NTextInput {
    id: codex2Label
    Layout.fillWidth: true
    label: "Codex 2 workspace name"
    description: "Shown in the tooltip header"
    text: cfg.codex2Label ?? ""
    onTextChanged: root.saveSettings()
  }

  RowLayout {
    NToggle { id: antigravityToggle; checked: cfg.antigravityEnabled ?? true; onToggled: root.saveSettings() }
    NText { text: "Antigravity"; color: Color.mOnSurface }
  }
  NTextInput {
    id: antigravityFormat
    Layout.fillWidth: true
    label: "Antigravity format"
    description: "Available: {worst_pct}"
    text: cfg.antigravityFormat ?? defaults.antigravityFormat ?? "AG {worst_pct}%"
    onTextChanged: root.saveSettings()
  }

  RowLayout {
    NToggle { id: opencodeToggle; checked: cfg.opencodeEnabled ?? true; onToggled: root.saveSettings() }
    NText { text: "OpenCode Go"; color: Color.mOnSurface }
  }
  NTextInput {
    id: opencodeFormat
    Layout.fillWidth: true
    label: "OpenCode format"
    description: "Available: {max_pct}, {rolling_pct}, {rolling_reset}"
    text: cfg.opencodeFormat ?? defaults.opencodeFormat ?? "Go {max_pct}%"
    onTextChanged: root.saveSettings()
  }
}
