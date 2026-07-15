import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

Item {
  id: root
  property var pluginApi: null
  property var mainInstance: pluginApi?.mainInstance

  readonly property var geometryPlaceholder: panelContainer
  readonly property bool allowAttach: true
  property real contentPreferredWidth: 380 * Style.uiScaleRatio
  property real contentPreferredHeight: 420 * Style.uiScaleRatio

  anchors.fill: parent

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginL

      RowLayout {
        Layout.fillWidth: true
        NIcon { icon: "ai"; color: Color.mPrimary; pointSize: Style.fontSizeXXL }
        NText {
          text: "AI Usage"
          pointSize: Style.fontSizeXL
          font.weight: Style.fontWeightBold
          color: Color.mOnSurface
        }
        Item { Layout.fillWidth: true }
      }

      Repeater {
        model: mainInstance?.providers ?? []
        Rectangle {
          required property var modelData
          Layout.fillWidth: true
          color: Color.mSurfaceVariant
          radius: Style.radiusS
          implicitHeight: cardLayout.implicitHeight + Style.marginL

          ColumnLayout {
            id: cardLayout
            anchors {
              left: parent.left
              right: parent.right
              top: parent.top
              margins: Style.marginM
            }
            spacing: Style.marginS

            RowLayout {
              Layout.fillWidth: true
              NText {
                text: modelData.text ?? ""
                pointSize: Style.fontSizeL
                font.weight: Style.fontWeightSemiBold
                color: Color.mOnSurface
              }
              Item { Layout.fillWidth: true }
              NText {
                text: modelData.className ?? ""
                pointSize: Style.fontSizeXS
                color: Color.mOnSurfaceVariant
              }
            }

            NText {
              Layout.fillWidth: true
              text: modelData.tooltip ?? ""
              pointSize: Style.fontSizeS
              color: Color.mOnSurfaceVariant
              wrapMode: Text.Wrap
            }
          }
        }
      }

      NText {
        visible: (mainInstance?.providers ?? []).length === 0
        Layout.fillWidth: true
        text: mainInstance?.tooltip ?? "No usage data yet."
        pointSize: Style.fontSizeM
        color: Color.mOnSurfaceVariant
        horizontalAlignment: Text.AlignHCenter
      }

      Item { Layout.fillHeight: true }
    }
  }
}
