import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property var pluginApi: null
  property ShellScreen screen
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  readonly property var mainInstance: pluginApi?.mainInstance
  readonly property string screenName: screen ? screen.name : ""
  readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
  readonly property bool isVertical: barPosition === "left" || barPosition === "right"
  readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)
  readonly property real barFontSize: Style.getBarFontSizeForScreen(screenName)

  readonly property string imLabel: mainInstance ? mainInstance.currentImLabel : ""
  readonly property bool isActive: mainInstance ? mainInstance.isActive : false

  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})
  property bool showIcon: cfg.showIcon ?? defaults.showIcon ?? true

  readonly property bool isVisible: imLabel !== ""

  implicitWidth: isVertical ? capsuleHeight : content.implicitWidth + Style.marginM * 2
  implicitHeight: isVertical ? content.implicitHeight + Style.marginM * 2 : capsuleHeight
  Layout.minimumWidth: implicitWidth
  Layout.preferredWidth: implicitWidth
  Layout.minimumHeight: implicitHeight
  Layout.preferredHeight: implicitHeight

  Rectangle {
    anchors.centerIn: parent
    width: root.implicitWidth
    height: root.implicitHeight
    radius: Style.radiusM
    color: root.isActive ? Qt.alpha(Color.mPrimary, 0.15) : Style.capsuleColor
    border.color: root.isActive ? Color.mPrimary : Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    RowLayout {
      id: content
      anchors.centerIn: parent
      spacing: Style.marginS

      NIcon {
        visible: root.showIcon
        icon: "keyboard"
        pointSize: root.barFontSize
        applyUiScale: false
        color: root.isActive ? Color.mPrimary : Color.mOnSurface
      }

      NText {
        text: root.imLabel
        textFormat: Text.PlainText
        elide: Text.ElideNone
        pointSize: root.barFontSize
        applyUiScale: false
        font.weight: Style.fontWeightSemiBold
        color: root.isActive ? Color.mPrimary : Color.mOnSurface
      }
    }
  }

  NPopupContextMenu {
    id: contextMenu
    screen: root.screen
    model: [
      {
        "label": pluginApi?.tr("menu.settings") || "Settings",
        "action": "settings",
        "icon": "settings"
      },
    ]
    onTriggered: function (action) {
      contextMenu.close();
      PanelService.closeContextMenu(root.screen);
      if (action === "settings") {
        BarService.openPluginSettings(root.screen, pluginApi.manifest);
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor

    onClicked: function (mouse) {
      if (mouse.button === Qt.RightButton) {
        PanelService.showContextMenu(contextMenu, root, root.screen);
      } else if (mouse.button === Qt.LeftButton) {
        Quickshell.execDetached(["fcitx5-remote", "-s", "next"]);
      }
    }

    onEntered: {
      var tooltip = root.isActive ? "Fcitx5 active (" + root.imLabel + ")" : root.imLabel;
      TooltipService.show(root, tooltip, BarService.getTooltipDirection(root.screenName));
    }
    onExited: TooltipService.hide()
  }
}
