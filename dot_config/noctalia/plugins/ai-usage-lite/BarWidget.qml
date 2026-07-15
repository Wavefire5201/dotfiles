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

  readonly property string displayText: mainInstance?.summary ?? "AI --"
  readonly property string tooltipText: mainInstance?.tooltip ?? "AI Usage Lite"

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
    color: Style.capsuleColor
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    RowLayout {
      id: content
      anchors.centerIn: parent
      spacing: Style.marginS

      NIcon {
        icon: "ai"
        pointSize: root.barFontSize
        applyUiScale: false
        color: Color.mPrimary
      }

      NText {
        text: root.displayText
        textFormat: Text.PlainText
        elide: Text.ElideNone
        pointSize: root.barFontSize
        applyUiScale: false
        font.weight: Style.fontWeightSemiBold
        color: Color.mOnSurface
      }
    }
  }

  NPopupContextMenu {
    id: contextMenu
    screen: root.screen
    model: [
      { "label": "Refresh", "action": "refresh", "icon": "refresh" },
      { "label": "Settings", "action": "settings", "icon": "settings" }
    ]
    onTriggered: function(action) {
      contextMenu.close();
      PanelService.closeContextMenu(root.screen);
      if (action === "refresh")
        mainInstance?.refresh();
      if (action === "settings")
        BarService.openPluginSettings(root.screen, pluginApi.manifest);
    }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    onClicked: function(mouse) {
      if (mouse.button === Qt.LeftButton)
        pluginApi?.openPanel(root.screen, root);
      else if (mouse.button === Qt.RightButton)
        PanelService.showContextMenu(contextMenu, root, root.screen);
    }
    onEntered: TooltipService.show(root, root.tooltipText, BarService.getTooltipDirection(root.screenName))
    onExited: TooltipService.hide()
  }
}
