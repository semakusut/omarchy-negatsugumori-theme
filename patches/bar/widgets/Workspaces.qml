import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "omarchy.workspaces"

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }

    return null
  }

  function workspaceIds() {
    var ids = [1, 2, 3, 4, 5]
    var values = Hyprland.workspaces.values

    for (var i = 0; i < values.length; i++) {
      var id = values[i].id
      if (id > 0 && id <= 10 && ids.indexOf(id) === -1) ids.push(id)
    }

    ids.sort(function(left, right) { return left - right })
    return ids
  }

  function focusWorkspace(id) {
    if (!root.bar) return
    root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + id + "\" })"))
  }

  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)

  implicitWidth: grid.implicitWidth + trailingGap
  implicitHeight: grid.implicitHeight

  GridLayout {
    id: grid
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: root.vertical ? 1 : root.workspaceIds().length
    columnSpacing: root.vertical ? 0 : Style.space(4)
    rowSpacing: root.vertical ? Style.space(2) : 0

    Repeater {
      model: root.workspaceIds()

      // Tsugumori workspace button: red pill when active, diamond marker,
      // hover tint, muted numbers otherwise. Replaces WidgetButton so the
      // shared button stays untouched.
      Item {
        required property int modelData

        readonly property var workspace: root.workspaceById(modelData)
        readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
        readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === modelData
        readonly property bool hovered: mouseArea.containsMouse

        opacity: occupied || focused ? 1 : 0.5
        width: root.vertical ? root.barSize : Style.space(30)
        height: root.barSize

        Behavior on opacity {
          NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
        }

        Rectangle {
          anchors.fill: parent
          color: focused ? "#cc1515" : (hovered ? Qt.rgba(204 / 255, 21 / 255, 21 / 255, 0.13) : "transparent")

          Behavior on color {
            enabled: !root.bar || root.bar.foregroundAnimationEnabled
            ColorAnimation { duration: 150 }
          }
        }

        // Diamond + number in a centered row, so nothing shifts when state
        // changes and the red pill never bleeds into the neighbor cell.
        RowLayout {
          anchors.centerIn: parent
          spacing: Style.space(4)

          Rectangle {
            id: diamond
            width: Style.space(6)
            height: Style.space(6)
            rotation: 45
            color: "#0a0a0a"
            visible: focused && !root.vertical
          }

          Text {
            id: label
            text: modelData === 10 ? "0" : String(modelData)
            textFormat: Text.PlainText
            color: focused ? "#0a0a0a" : (hovered ? "#e8e8e8" : "#a29b96")
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.body
            renderType: Text.NativeRendering
            rotation: root.vertical ? 90 : 0
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter

            Behavior on color {
              enabled: !root.bar || root.bar.foregroundAnimationEnabled
              ColorAnimation { duration: 150 }
            }
          }
        }

        MouseArea {
          id: mouseArea
          anchors.fill: parent
          acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
          cursorShape: Qt.PointingHandCursor
          onClicked: root.focusWorkspace(modelData)
        }
      }
    }
  }
}
