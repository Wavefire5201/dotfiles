import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Widgets
import "jisho.js" as Jisho

// Qualified on purpose: from Qt 6.12, an unqualified `Color` resolves to QtQuick's own Color
// object instead of noctalia's singleton, which leaves every theme color undefined.
import qs.Commons as Theme

Item {
  id: root

  property var currentItem: null
  readonly property var entry: currentItem && currentItem.entry ? currentItem.entry : null

  NScrollView {
    id: scroll
    anchors.fill: parent
    anchors.margins: Theme.Style.marginL
    visible: root.entry !== null
    horizontalPolicy: ScrollBar.AlwaysOff
    gradientColor: Theme.Color.mSurfaceVariant

    ColumnLayout {
      width: scroll.availableWidth
      spacing: Theme.Style.marginXS

      NText {
        Layout.fillWidth: true
        text: root.entry ? root.entry.title : ""
        pointSize: Theme.Style.fontSizeXXXL
        font.weight: Theme.Style.fontWeightBold
        color: Theme.Color.mPrimary
        wrapMode: Text.Wrap
      }

      NText {
        Layout.fillWidth: true
        visible: !!(root.entry && root.entry.word && root.entry.reading)
        text: root.entry ? root.entry.reading : ""
        pointSize: Theme.Style.fontSizeL
        color: Theme.Color.mOnSurfaceVariant
        wrapMode: Text.Wrap
      }

      Flow {
        Layout.fillWidth: true
        Layout.topMargin: Theme.Style.marginXS
        visible: chipRepeater.count > 0
        spacing: Theme.Style.marginXS

        Repeater {
          id: chipRepeater
          model: root.entry ? Jisho.chips(root.entry) : []

          Rectangle {
            readonly property bool filled: modelData === "Common"
            implicitWidth: chipText.implicitWidth + Theme.Style.margin2S
            implicitHeight: chipText.implicitHeight + Theme.Style.margin2XXS
            radius: Theme.Style.radiusXS
            color: filled ? Theme.Color.mPrimary : "transparent"
            border.width: filled ? 0 : 1
            border.color: Theme.Color.mOutline

            NText {
              id: chipText
              anchors.centerIn: parent
              text: modelData
              pointSize: Theme.Style.fontSizeXS
              color: parent.filled ? Theme.Color.mOnPrimary : Theme.Color.mOnSurfaceVariant
            }
          }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.topMargin: Theme.Style.marginS
        Layout.bottomMargin: Theme.Style.marginXS
        implicitHeight: 1
        color: Theme.Color.mOutline
      }

      Repeater {
        model: root.entry ? root.entry.senses : []

        ColumnLayout {
          id: sense
          required property var modelData
          required property int index
          readonly property string heading: Jisho.posHeading(root.entry.senses, index)
          readonly property string notes: Jisho.senseNotes(modelData)

          Layout.fillWidth: true
          Layout.topMargin: heading !== "" && index > 0 ? Theme.Style.marginS : 0
          spacing: Theme.Style.marginXXS

          NText {
            Layout.fillWidth: true
            visible: sense.heading !== ""
            text: sense.heading
            pointSize: Theme.Style.fontSizeXS
            color: Theme.Color.mSecondary
            wrapMode: Text.Wrap
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: Theme.Style.marginS

            NText {
              id: number
              Layout.alignment: Qt.AlignTop
              text: (sense.index + 1) + "."
              color: Theme.Color.mOnSurfaceVariant
            }

            NText {
              Layout.fillWidth: true
              text: sense.modelData.definitions.join("; ")
              color: Theme.Color.mOnSurface
              wrapMode: Text.Wrap
            }
          }

          NText {
            Layout.fillWidth: true
            Layout.leftMargin: number.implicitWidth + Theme.Style.marginS
            visible: sense.notes !== ""
            text: sense.notes
            pointSize: Theme.Style.fontSizeXS
            color: Theme.Color.mOnSurfaceVariant
            wrapMode: Text.Wrap
          }
        }
      }

      NText {
        Layout.fillWidth: true
        Layout.topMargin: Theme.Style.marginS
        visible: !!(root.entry && root.entry.otherForms.length > 0)
        text: root.entry ? "Other forms: " + root.entry.otherForms.join("、") : ""
        pointSize: Theme.Style.fontSizeS
        color: Theme.Color.mOnSurfaceVariant
        wrapMode: Text.Wrap
      }
    }
  }

  // Loading, error, no-match and hint rows carry no entry: echo the row itself
  ColumnLayout {
    anchors.centerIn: parent
    width: parent.width - Theme.Style.margin2L
    visible: root.entry === null && root.currentItem !== null
    spacing: Theme.Style.marginXS

    NText {
      Layout.fillWidth: true
      text: root.currentItem ? root.currentItem.name : ""
      pointSize: Theme.Style.fontSizeL
      font.weight: Theme.Style.fontWeightBold
      color: Theme.Color.mOnSurface
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.Wrap
    }

    NText {
      Layout.fillWidth: true
      text: root.currentItem ? root.currentItem.description : ""
      pointSize: Theme.Style.fontSizeS
      color: Theme.Color.mOnSurfaceVariant
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.Wrap
    }
  }
}
