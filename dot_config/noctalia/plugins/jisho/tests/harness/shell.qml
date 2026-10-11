import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

// Logic harness: drives the real LauncherProvider.qml against a mock launcher and the fixture
// server, then serves IPC so run.sh can exercise Main.qml through `qs ipc call plugin:jisho ...`.
ShellRoot {
  id: h

  readonly property string pluginDir: Quickshell.env("JISHO_PLUGIN_DIR")
  readonly property string server: Quickshell.env("JISHO_SERVER")
  readonly property var expectedLog: ["食べる", "neko", "食べる", "neko", "ありがとう", "zzqxjvkw", "boom", "garbage", "flaky", "flaky", "slow", "eat", "slow"]

  property var api: null
  property var provider: null
  property var main: null
  property string phase: "provider"
  property int passes: 0
  property int failures: 0
  property var toggles: []
  property var serverLog: null
  property var mark: ({})

  QtObject {
    id: launcher
    property string searchText: ""
    property var results: []
    property int updates: 0
    property int closes: 0
    function setSearchText(text) {
      searchText = text;
      updateResults();
    }
    function updateResults() {
      updates++;
      results = h.provider.getResults(searchText);
    }
    // Mirrors LauncherCore: closing clears the search and notifies providers
    function close() {
      closes++;
      searchText = "";
      if (h.provider.onClosed)
        h.provider.onClosed();
    }
  }

  FileView {
    id: callsFile
    path: Quickshell.env("JISHO_CALLS_LOG")
    blockLoading: true
    printErrors: false
  }

  function calls() {
    callsFile.reload();
    return (callsFile.text() || "").split("\n").filter(l => l !== "");
  }
  function rows() {
    return launcher.results;
  }
  function names() {
    return launcher.results.map(r => r.name);
  }
  function history() {
    return (api.pluginSettings.history || []).map(e => e.slug);
  }
  function check(ok, label) {
    if (ok)
      passes++;
    else
      failures++;
    console.log(ok ? "PASS" : "FAIL", label);
  }
  function same(a, b) {
    return JSON.stringify(a) === JSON.stringify(b);
  }
  function fetchLog() {
    serverLog = null;
    var xhr = new XMLHttpRequest();
    xhr.onreadystatechange = function () {
      if (xhr.readyState === XMLHttpRequest.DONE)
        h.serverLog = JSON.parse(xhr.responseText);
    };
    xhr.open("GET", server + "/__log");
    xhr.send();
  }
  function rowBySlug(slug) {
    return rows().find(r => r.entry && r.entry.slug === slug);
  }

  // Each step: run once, then poll `until` (and `wait` ms) before running `check`.
  property var steps: [
    {
      "name": "command routing",
      "run": function () {
        check(provider.handleCommand(">jisho") && provider.handleCommand(">jisho 猫"), "handleCommand accepts >jisho");
        check(!provider.handleCommand(">jishox") && !provider.handleCommand("jisho"), "handleCommand rejects lookalikes");
        var cmds = provider.commands();
        check(cmds.length === 1 && cmds[0].name === ">jisho", "commands() lists >jisho");
        cmds[0].onActivate();
      },
      "check": function () {
        check(launcher.searchText === ">jisho ", "command row fills the >jisho prefix");
        check(rows().length === 1 && names()[0] === "Search Jisho", "empty history shows the hint row");
        check(provider.getItemActions(rows()[0]).length === 0 && !provider.canDeleteItem(rows()[0]), "hint row has no actions");
      }
    },
    {
      "name": "search 食べる",
      "run": function () {
        launcher.setSearchText(">jisho 食べる");
        check(names()[0] === "Searching…", "loading row while the debounce runs");
      },
      "until": () => names()[0] === "食べる",
      "check": function () {
        check(rows().length === 2, "two results for 食べる");
        check(rows()[0].description === "たべる · to eat", "row description is reading · first sense");
        check(rows()[0].entry.jlpt === "N5" && rows()[0].entry.isCommon, "row carries the parsed entry");
      }
    },
    {
      "name": "debounce: n",
      "run": () => launcher.setSearchText(">jisho n"),
      "wait": 60
    },
    {
      "name": "debounce: ne",
      "run": () => launcher.setSearchText(">jisho ne"),
      "wait": 60
    },
    {
      "name": "debounce: nek",
      "run": () => launcher.setSearchText(">jisho nek"),
      "wait": 60
    },
    {
      "name": "debounce: neko",
      "run": () => launcher.setSearchText(">jisho neko"),
      "until": () => names()[0] === "猫",
      "check": () => check(rows().length === 10, "ten results for neko")
    },
    {
      "name": "debounce log",
      "run": fetchLog,
      "until": () => serverLog !== null,
      "check": () => check(same(serverLog, ["食べる", "neko"]), "typing n→neko sent one request: " + JSON.stringify(serverLog))
    },
    {
      "name": "cache hit",
      "run": function () {
        launcher.setSearchText(">jisho 食べる");
        check(names()[0] === "食べる", "repeated query renders from cache");
        fetchLog();
      },
      "until": () => serverLog !== null,
      "check": () => check(serverLog.length === 2, "cache hit sent no request")
    },
    {
      "name": "copy word",
      "run": function () {
        var actions = provider.getItemActions(rows()[0]);
        check(actions.length === 2, "kanji entry has copy word + copy reading");
        actions[0].action();
      },
      "until": () => calls().indexOf("wl-copy -- 食べる") !== -1,
      "check": function () {
        check(launcher.closes === 1, "copy closes the launcher");
        check(same(history(), ["食べる"]) && api.saved === 1, "copy records history and saves");
      }
    },
    {
      "name": "copy reading",
      "run": () => launcher.setSearchText(">jisho 食べる"),
      "until": () => names()[0] === "食べる",
      "check": () => provider.getItemActions(rows()[0])[1].action()
    },
    {
      "name": "copy reading call",
      "until": () => calls().indexOf("wl-copy -- たべる") !== -1,
      "check": () => check(same(history(), ["食べる"]), "history dedupes the same word")
    },
    {
      "name": "enter opens jisho.org",
      "run": () => launcher.setSearchText(">jisho neko"),
      "until": () => names()[0] === "猫",
      "check": () => rows()[0].onActivate()
    },
    {
      "name": "enter xdg-open call",
      "until": () => calls().indexOf("xdg-open https://jisho.org/word/%E7%8C%AB") !== -1,
      "check": function () {
        check(launcher.closes === 3, "enter closes the launcher");
        check(same(history(), ["猫", "食べる"]), "enter puts the word first in history");
      }
    },
    {
      "name": "kana-only and wikipedia rows",
      "run": () => launcher.setSearchText(">jisho ありがとう"),
      "until": () => rows().length === 7,
      "check": function () {
        var kana = rowBySlug("ありがとさん");
        var wiki = rowBySlug("518693b5d5dda7b2c602e64d");
        check(kana && provider.getItemActions(kana).length === 1, "kana-only word has a single copy action");
        check(wiki && wiki.name === "ありがとう (漫画)" && provider.getItemActions(wiki).length === 1, "reading-less wikipedia entry has a single copy action");
        check(provider.hasPreview && provider.previewComponentPath === "file://" + pluginDir + "/Preview.qml", "provider points at Preview.qml");
        check(provider.getPreviewData(kana).entry.slug === "ありがとさん", "preview data carries the entry");
      }
    },
    {
      "name": "no match",
      "run": () => launcher.setSearchText(">jisho zzqxjvkw"),
      "until": () => names()[0] === "No matches for zzqxjvkw",
      "check": function () {
        check(rows().length === 1, "no-match shows one row");
        rows()[0].onActivate();
      }
    },
    {
      "name": "no match opens the search page",
      "until": () => calls().indexOf("xdg-open https://jisho.org/search/zzqxjvkw") !== -1,
      "check": () => check(same(history(), ["猫", "食べる"]), "no-match leaves history alone")
    },
    {
      "name": "http error",
      "run": () => launcher.setSearchText(">jisho boom"),
      "until": () => names()[0] === "Lookup failed",
      "check": () => check(rows()[0].description.indexOf("HTTP 500") !== -1, "error row names the HTTP status: " + rows()[0].description)
    },
    {
      "name": "bad body",
      "run": () => launcher.setSearchText(">jisho garbage"),
      "until": () => names()[0] === "Lookup failed",
      "check": () => check(rows().length === 1, "unparseable body shows the error row")
    },
    {
      "name": "retry after error",
      "run": () => launcher.setSearchText(">jisho flaky"),
      "until": () => names()[0] === "Lookup failed",
      "check": function () {
        rows()[0].onActivate();
        check(names()[0] === "Searching…", "retry shows the loading row at once");
      }
    },
    {
      "name": "retry result",
      "until": () => names()[0] === "食べる",
      "check": () => check(rows().length === 2, "retry recovers the results")
    },
    {
      "name": "slow request in flight",
      "run": () => launcher.setSearchText(">jisho slow"),
      "wait": 450
    },
    {
      "name": "newer query wins",
      "run": () => launcher.setSearchText(">jisho eat"),
      "until": () => rows().length === 20,
      "check": function () {
        mark.updates = launcher.updates;
      }
    },
    {
      "name": "aborted slow response is ignored",
      "wait": 1600,
      "check": function () {
        check(launcher.updates === mark.updates && rows().length === 20, "no refresh from the superseded request");
      }
    },
    {
      "name": "aborted query is not stuck loading",
      "run": () => launcher.setSearchText(">jisho slow"),
      "until": () => names()[0] === "猫",
      "timeout": 4000
    },
    {
      "name": "history browse",
      "run": () => launcher.setSearchText(">jisho "),
      "check": function () {
        check(same(names(), ["猫", "食べる"]), "empty query lists history newest first");
        check(provider.canDeleteItem(rows()[1]), "history rows are deletable");
        var actions = provider.getItemActions(rows()[1]);
        check(actions.length === 3 && actions[2].icon === "trash", "history row adds a remove action");
        provider.deleteItem(rows()[1]);
        check(same(names(), ["猫"]) && same(history(), ["猫"]) && api.saved === 4, "delete removes, refreshes and saves");
      }
    },
    {
      "name": "history persists across instances",
      "run": function () {
        var again = providerComponent.createObject(h, {
                                                     "pluginApi": makeApi(api.pluginSettings.history)
                                                   });
        check(same(again.getResults(">jisho ").map(r => r.name), ["猫"]), "a fresh provider reads saved history");
        again.destroy();
      }
    },
    {
      "name": "request log",
      "run": fetchLog,
      "until": () => serverLog !== null,
      "check": () => check(same(serverLog, expectedLog), "exact request sequence: " + JSON.stringify(serverLog))
    }
  ]

  property int stepIndex: -1
  property real stepStarted: 0

  Timer {
    id: poll
    interval: 20
    repeat: true
    onTriggered: h.tick()
  }

  function startStep() {
    stepIndex++;
    if (stepIndex >= steps.length) {
      poll.stop();
      phase = "ipc";
      console.log("HARNESS READY");
      return;
    }
    stepStarted = Date.now();
    var s = steps[stepIndex];
    try {
      if (s.run)
        s.run();
    } catch (e) {
      check(false, s.name + " threw: " + e);
    }
  }

  function tick() {
    var s = steps[stepIndex];
    var waited = Date.now() - stepStarted;
    var ready = waited >= (s.wait || 0) && (!s.until || s.until());
    if (!ready && waited < (s.timeout || 3000))
      return;
    if (!ready)
      check(false, s.name + " timed out; rows: " + JSON.stringify(names()));
    else if (s.check) {
      try {
        s.check();
      } catch (e) {
        check(false, s.name + " threw: " + e);
      }
    }
    startStep();
  }

  // Shaped like PluginService.createPluginAPI: a QtObject, and saveSettings swaps in a shallow copy
  function makeApi(history) {
    var mock = Qt.createQmlObject(`
      import QtQuick
      QtObject {
        property string pluginId: "jisho"
        property string pluginDir
        property var pluginSettings: ({})
        property int saved: 0
        property var saveSettings: null
        property var withCurrentScreen: null
        property var toggleLauncher: null
      }`, h, "MockPluginApi");
    mock.pluginDir = pluginDir;
    mock.pluginSettings = {
      "history": history || []
    };
    mock.saveSettings = function () {
      mock.saved++;
      mock.pluginSettings = Object.assign({}, mock.pluginSettings);
    };
    mock.withCurrentScreen = cb => cb("screen-0");
    mock.toggleLauncher = screen => h.toggles = h.toggles.concat([screen]);
    return mock;
  }

  property var providerComponent: null

  Component.onCompleted: {
    api = makeApi([]);
    providerComponent = Qt.createComponent("file://" + pluginDir + "/LauncherProvider.qml");
    var mainComponent = Qt.createComponent("file://" + pluginDir + "/Main.qml");
    if (providerComponent.status !== Component.Ready || mainComponent.status !== Component.Ready) {
      console.log("FAIL load:", providerComponent.errorString(), mainComponent.errorString());
      console.log("HARNESS RESULT passes=0 failures=1");
      Qt.callLater(Qt.quit);
      return;
    }
    provider = providerComponent.createObject(h, {
                                                "pluginApi": api,
                                                "apiUrl": server + "/api/v1/search/words"
                                              });
    provider.launcher = launcher;
    if (provider.init)
      provider.init();
    main = mainComponent.createObject(h, {
                                        "pluginApi": api
                                      });
    startStep();
    poll.start();
  }

  IpcHandler {
    target: "harness"
    function phase(): string {
      return h.phase;
    }
    function openCount(): int {
      return PanelService.opens.length;
    }
    function finish(): string {
      var texts = PanelService.opens.map(o => o.text);
      h.check(h.same(texts, [">jisho 猫舌", ">jisho 食べる", ">jisho "]), "IPC opened the launcher with: " + JSON.stringify(texts));
      h.check(PanelService.opens.every(o => o.screen === "screen-0"), "IPC opens target the current screen");
      h.check(h.same(h.toggles, ["screen-0"]), "toggle IPC toggles the launcher");
      var summary = "HARNESS RESULT passes=" + h.passes + " failures=" + h.failures;
      console.log(summary);
      Qt.callLater(Qt.quit);
      return summary;
    }
  }
}
