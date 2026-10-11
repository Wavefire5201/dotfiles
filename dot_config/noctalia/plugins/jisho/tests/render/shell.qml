import QtQuick
import QtQuick.Window
import Quickshell
import qs.Commons as Theme
import qs.Widgets

// Render harness: real noctalia Commons/Widgets, offscreen. Rows come from the real provider
// (fixture server) and reach Preview.qml through getPreviewData, as in the launcher.
ShellRoot {
  id: r

  readonly property string pluginDir: Quickshell.env("JISHO_PLUGIN_DIR")
  readonly property string server: Quickshell.env("JISHO_SERVER")
  readonly property string outDir: Quickshell.env("JISHO_RENDER_OUT")
  property var provider: null
  property int passes: 0
  property int failures: 0
  property int stepIndex: -1
  property real stepStarted: 0
  property bool grabbing: false
  property int settleTicks: 0

  QtObject {
    id: launcher
    property string searchText: ""
    property var results: []
    function setSearchText(text) {
      searchText = text;
      updateResults();
    }
    function updateResults() {
      results = r.provider.getResults(searchText);
    }
    function close() {}
  }

  Window {
    id: win
    width: Math.round(400 * Theme.Style.uiScaleRatio)
    height: width
    visible: true
    color: Theme.Color.mSurface

    NBox {
      anchors.fill: parent
      forceOpaque: true
      color: Theme.Color.mSurfaceVariant

      Loader {
        id: loader
        anchors.fill: parent
        source: r.provider ? r.provider.previewComponentPath : ""
      }
    }
  }

  function check(ok, label) {
    if (ok)
      passes++;
    else
      failures++;
    console.log(ok ? "PASS" : "FAIL", label);
  }

  // Flickable content shows up both as a child and as contentItem; visit each item once
  function textItems(item, out, seen) {
    out = out || [];
    seen = seen || new Set();
    if (!item || seen.has(item) || !item.visible || item.opacity === 0)
      return out;
    seen.add(item);
    if (typeof item.text === "string" && item.text !== "" && item.font !== undefined)
      out.push(item);
    var kids = item.children || [];
    for (var i = 0; i < kids.length; i++)
      textItems(kids[i], out, seen);
    textItems(item.contentItem, out, seen);
    return out;
  }
  function texts() {
    return textItems(loader.item).map(t => t.text);
  }
  function count(list, value) {
    return list.filter(t => t === value).length;
  }
  function hasAll(values) {
    var got = texts();
    var missing = values.filter(v => got.indexOf(v) === -1);
    return missing.length === 0 ? "" : JSON.stringify(missing) + " not in " + JSON.stringify(got);
  }
  function overflow() {
    return textItems(loader.item).filter(t => t.mapToItem(win.contentItem, t.width, 0).x > win.width + 0.5).map(t => t.text);
  }
  function scrollable(item) {
    if (!item || !item.visible)
      return false;
    if (item.verticalScrollable === true)
      return true;
    var kids = item.children || [];
    for (var i = 0; i < kids.length; i++)
      if (scrollable(kids[i]))
        return true;
    return false;
  }
  function show(query, pick) {
    launcher.setSearchText(">jisho " + query);
    r.pick = pick;
  }
  property var pick: null
  function picked() {
    return launcher.results.find(r.pick);
  }

  // Each step searches, waits for the row, hands it to the preview, checks, then grabs a PNG.
  property var steps: [
    {
      "name": "taberu",
      "run": () => show("食べる", row => row.entry && row.entry.slug === "食べる"),
      "check": function () {
        var missing = hasAll(["食べる", "たべる", "Common", "JLPT N5", "Ichidan verb, Transitive verb", "1.", "to eat", "2.", "to live on (e.g. a salary); to live off; to subsist on"]);
        check(missing === "", "食べる shows word, reading, chips and both senses " + missing);
        check(count(texts(), "Ichidan verb, Transitive verb") === 1, "repeated parts of speech are not repeated");
      }
    },
    {
      "name": "neko",
      "run": () => show("neko", row => row.entry && row.entry.slug === "猫"),
      "check": function () {
        var missing = hasAll(["猫", "ねこ", "Noun", "7.", "Wikipedia definition", "Abbreviation · See also 猫車", "Usually written using kana alone · Slang"]);
        check(missing === "", "猫 shows headings, notes and all seven senses " + missing);
        check(count(texts(), "Noun") === 1, "Noun heading appears once");
        check(scrollable(loader.item), "a long entry scrolls inside the preview");
      }
    },
    {
      "name": "other forms",
      "run": () => show("neko", row => row.entry && row.entry.slug === "根刮ぎ"),
      "check": function () {
        var missing = hasAll(["根こそぎ", "ねこそぎ", "Other forms: 根刮ぎ (ねこそぎ)", "as 〜にする"]);
        check(missing === "", "根こそぎ lists its other form " + missing);
      }
    },
    {
      "name": "kana only",
      "run": () => show("ありがとう", row => row.entry && row.entry.slug === "ありがとさん"),
      "check": function () {
        check(count(texts(), "ありがとさん") === 1, "kana-only word is not repeated as its reading");
        check(hasAll(["Other forms: ありがとうさん"]) === "", "kana-only word lists its other form");
      }
    },
    {
      "name": "info row",
      "run": () => show("zzqxjvkw", row => row.name === "No matches for zzqxjvkw"),
      "check": function () {
        check(hasAll(["No matches for zzqxjvkw", "Enter to search jisho.org"]) === "", "rows without an entry show their name and description");
      }
    }
  ]

  Timer {
    id: poll
    interval: 20
    repeat: true
    onTriggered: r.tick()
  }

  function tick() {
    if (grabbing)
      return;
    if (stepIndex < 0) {
      if (!Theme.Settings.isLoaded || !loader.item)
        return;
      return next();
    }
    var s = steps[stepIndex];
    var row = picked();
    var waited = Date.now() - stepStarted;
    if (!row && waited < 3000)
      return;
    if (!row) {
      check(false, s.name + " never produced the row; rows: " + JSON.stringify(launcher.results.map(x => x.name)));
      return next();
    }
    // Hand the row over, then give bindings and layout a few ticks to settle
    if (settleTicks === 0)
      loader.item.currentItem = r.provider.getPreviewData(row);
    if (settleTicks++ < 5)
      return;
    s.check();
    var spilled = overflow();
    check(spilled.length === 0, s.name + ": no text overflows the panel " + JSON.stringify(spilled));
    grabbing = true;
    win.contentItem.grabToImage(function (result) {
      result.saveToFile(outDir + "/preview-" + (stepIndex + 1) + "-" + s.name.replace(/ /g, "-") + ".png");
      grabbing = false;
      next();
    });
  }

  function next() {
    stepIndex++;
    if (stepIndex >= steps.length) {
      poll.stop();
      console.log("RENDER RESULT passes=" + passes + " failures=" + failures);
      Qt.callLater(Qt.quit);
      return;
    }
    stepStarted = Date.now();
    settleTicks = 0;
    steps[stepIndex].run();
  }

  Component.onCompleted: {
    var component = Qt.createComponent("file://" + pluginDir + "/LauncherProvider.qml");
    if (component.status !== Component.Ready) {
      console.log("FAIL load:", component.errorString());
      console.log("RENDER RESULT passes=0 failures=1");
      Qt.callLater(Qt.quit);
      return;
    }
    provider = component.createObject(r, {
                                        "apiUrl": server + "/api/v1/search/words",
                                        "pluginApi": {
                                          "pluginDir": pluginDir,
                                          "pluginSettings": {
                                            "history": []
                                          }
                                        }
                                      });
    provider.launcher = launcher;
    poll.start();
  }
}
