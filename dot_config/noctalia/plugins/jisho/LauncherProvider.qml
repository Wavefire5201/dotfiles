import QtQuick
import Quickshell
import qs.Commons
import "jisho.js" as Jisho

Item {
  id: root

  property var pluginApi: null
  property var launcher: null

  property string name: "Jisho"
  property bool handleSearch: false
  property string supportedLayouts: "list"
  property bool hasPreview: true
  property string previewComponentPath: pluginApi ? "file://" + pluginApi.pluginDir + "/Preview.qml" : ""

  property string apiUrl: Jisho.API_URL
  property int debounceMs: 300

  // query -> { status: "loading" | "done" | "error", entries, error }
  property var cache: ({})
  property string pendingQuery: ""
  property var request: null
  property string requestQuery: ""

  Timer {
    id: debounce
    interval: root.debounceMs
    onTriggered: root.fetch(root.pendingQuery)
  }

  function handleCommand(searchText) {
    return Jisho.handles(searchText);
  }

  function commands() {
    return [
          {
            "name": Jisho.PREFIX,
            "description": "Look up Japanese words on jisho.org",
            "icon": "language-hiragana",
            "isTablerIcon": true,
            "isImage": false,
            "onActivate": function () {
              launcher.setSearchText(Jisho.PREFIX + " ");
            }
          }
        ];
  }

  function getResults(searchText) {
    if (!handleCommand(searchText))
      return [];

    var query = Jisho.parseQuery(searchText);
    if (query === "") {
      debounce.stop();
      return historyRows();
    }

    var hit = cache[query];
    if (!hit) {
      pendingQuery = query;
      debounce.restart();
      return [loadingRow(query)];
    }
    if (hit.status === "loading")
      return [loadingRow(query)];
    if (hit.status === "error")
      return [errorRow(query, hit.error)];
    if (hit.entries.length === 0)
      return [noMatchRow(query)];
    return hit.entries.map(e => entryRow(e, false));
  }

  function onClosed() {
    debounce.stop();
    cancel();
    cache = {};
  }

  function fetch(query) {
    cancel();
    var xhr = new XMLHttpRequest();
    request = xhr;
    requestQuery = query;
    cache[query] = {
      "status": "loading"
    };
    xhr.onreadystatechange = function () {
      if (xhr.readyState !== XMLHttpRequest.DONE || request !== xhr)
        return;
      request = null;
      cache[query] = parse(xhr);
      if (cache[query].status === "error")
        Logger.w("Jisho", "lookup failed:", query, cache[query].error);
      else
        Logger.i("Jisho", "lookup:", query, "->", cache[query].entries.length, "results");
      if (launcher && Jisho.parseQuery(launcher.searchText) === query)
        launcher.updateResults();
    };
    xhr.open("GET", Jisho.searchUrl(query, apiUrl));
    xhr.send();
  }

  function parse(xhr) {
    if (xhr.status !== 200)
      return {
        "status": "error",
        "error": xhr.status ? "HTTP " + xhr.status : "network error"
      };
    try {
      return {
        "status": "done",
        "entries": Jisho.parseResponse(xhr.responseText)
      };
    } catch (e) {
      return {
        "status": "error",
        "error": e.message
      };
    }
  }

  // Drop the in-flight request; its query is forgotten so it refetches next time
  function cancel() {
    if (!request)
      return;
    var old = request;
    request = null;
    delete cache[requestQuery];
    old.abort();
  }

  function retry(query) {
    delete cache[query];
    fetch(query);
    launcher.updateResults();
  }

  function history() {
    return (pluginApi && pluginApi.pluginSettings.history) || [];
  }

  function saveHistory(list) {
    pluginApi.pluginSettings.history = list;
    pluginApi.saveSettings();
  }

  function remember(entry) {
    saveHistory(Jisho.addToHistory(history(), entry));
  }

  function open(url, entry) {
    Quickshell.execDetached(["xdg-open", url]);
    if (entry)
      remember(entry);
    launcher.close();
  }

  function copy(text, entry) {
    Quickshell.execDetached(["wl-copy", "--", text]);
    remember(entry);
    launcher.close();
  }

  function entryRow(entry, fromHistory) {
    return {
      "name": entry.title,
      "description": Jisho.summary(entry),
      "icon": fromHistory ? "history" : "language-hiragana",
      "isTablerIcon": true,
      "isImage": false,
      "entry": entry,
      "fromHistory": fromHistory,
      "onActivate": function () {
        root.open(Jisho.wordUrl(entry.slug), entry);
      }
    };
  }

  function historyRows() {
    var list = history();
    if (list.length === 0)
      return [infoRow("Search Jisho", "Type a word in kanji, kana, romaji or English", "search")];
    return list.map(e => entryRow(e, true));
  }

  function infoRow(name, description, icon, onActivate) {
    return {
      "name": name,
      "description": description,
      "icon": icon,
      "isTablerIcon": true,
      "isImage": false,
      "onActivate": onActivate || function () {}
    };
  }

  function loadingRow(query) {
    return infoRow("Searching…", query, "loader-2");
  }

  function errorRow(query, error) {
    return infoRow("Lookup failed", query + ": " + error + ". Enter to retry.", "alert-circle", function () {
      root.retry(query);
    });
  }

  function noMatchRow(query) {
    return infoRow("No matches for " + query, "Enter to search jisho.org", "world", function () {
      root.open(Jisho.searchPageUrl(query), null);
    });
  }

  function getItemActions(item) {
    if (!item || !item.entry)
      return [];
    var entry = item.entry;
    var actions = [
          {
            "icon": "copy",
            "tooltip": "Copy " + entry.title,
            "action": function () {
              root.copy(entry.title, entry);
            }
          }
        ];
    if (entry.word && entry.reading)
      actions.push({
                     "icon": "abc",
                     "tooltip": "Copy reading " + entry.reading,
                     "action": function () {
                       root.copy(entry.reading, entry);
                     }
                   });
    if (item.fromHistory)
      actions.push({
                     "icon": "trash",
                     "tooltip": "Remove from history",
                     "action": function () {
                       root.deleteItem(item);
                     }
                   });
    return actions;
  }

  function canDeleteItem(item) {
    return !!(item && item.fromHistory);
  }

  function deleteItem(item) {
    saveHistory(Jisho.removeFromHistory(history(), item.entry.slug));
    if (launcher)
      launcher.updateResults();
  }

  function getPreviewData(item) {
    return item;
  }
}
