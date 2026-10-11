pragma Singleton
import QtQuick

// Stub of noctalia's PanelService: records launcher opens for the harness to assert on.
QtObject {
  property var opens: []
  function openLauncherWithSearch(screen, searchText) {
    opens = opens.concat([{ "screen": screen, "text": searchText }]);
  }
}
