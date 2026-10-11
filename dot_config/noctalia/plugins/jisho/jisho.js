.pragma library

// Pure helpers for the Jisho launcher provider; tested in tests/jisho.test.mjs.

var PREFIX = ">jisho";
var API_URL = "https://jisho.org/api/v1/search/words";
var SITE_URL = "https://jisho.org";
var HISTORY_LIMIT = 50;
var SELECTION_LIMIT = 64;

function handles(searchText) {
  return searchText === PREFIX || searchText.startsWith(PREFIX + " ");
}

function parseQuery(searchText) {
  return handles(searchText) ? searchText.slice(PREFIX.length).trim() : "";
}

function searchUrl(query, base) {
  return (base || API_URL) + "?keyword=" + encodeURIComponent(query);
}

function wordUrl(slug) {
  return SITE_URL + "/word/" + encodeURIComponent(slug);
}

function searchPageUrl(query) {
  return SITE_URL + "/search/" + encodeURIComponent(query);
}

function formLabel(form) {
  if (form.word && form.reading)
    return form.word + " (" + form.reading + ")";
  return form.word || form.reading || "";
}

function parseEntry(raw) {
  var forms = raw.japanese || [];
  var first = forms[0] || {};
  var word = first.word || "";
  var reading = first.reading || "";
  return {
    slug: raw.slug || "",
    word: word,
    reading: reading,
    title: word || reading,
    isCommon: raw.is_common === true,
    jlpt: (raw.jlpt && raw.jlpt.length) ? raw.jlpt[0].replace("jlpt-", "").toUpperCase() : "",
    senses: (raw.senses || []).map(function (s) {
      return {
        definitions: s.english_definitions || [],
        partsOfSpeech: s.parts_of_speech || [],
        tags: s.tags || [],
        info: s.info || [],
        seeAlso: s.see_also || []
      };
    }),
    otherForms: forms.slice(1).map(formLabel).filter(function (l) { return l !== ""; })
  };
}

// Throws on malformed JSON or a non-200 status so callers can show the error.
function parseResponse(text) {
  var json = JSON.parse(text);
  var status = json.meta && json.meta.status;
  if (status !== 200)
    throw new Error("Jisho returned status " + status);
  return (json.data || []).map(parseEntry);
}

function summary(entry) {
  var defs = entry.senses.length ? entry.senses[0].definitions.join("; ") : "";
  if (entry.word && entry.reading)
    return entry.reading + " · " + defs;
  return defs;
}

function chips(entry) {
  var out = [];
  if (entry.isCommon)
    out.push("Common");
  if (entry.jlpt)
    out.push("JLPT " + entry.jlpt);
  return out;
}

// Like jisho.org: a sense repeats no heading when its parts of speech match the previous one
function posHeading(senses, index) {
  var pos = senses[index].partsOfSpeech.join(", ");
  if (index > 0 && senses[index - 1].partsOfSpeech.join(", ") === pos)
    return "";
  return pos;
}

function senseNotes(sense) {
  var seeAlso = sense.seeAlso.map(function (s) { return "See also " + s; });
  return sense.tags.concat(sense.info, seeAlso).join(" · ");
}

function addToHistory(history, entry, limit) {
  var rest = history.filter(function (e) { return e.slug !== entry.slug; });
  return [entry].concat(rest).slice(0, limit || HISTORY_LIMIT);
}

function removeFromHistory(history, slug) {
  return history.filter(function (e) { return e.slug !== slug; });
}

function cleanSelection(text) {
  var lines = String(text || "").split("\n");
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].replace(/\s+/g, " ").trim();
    if (line !== "")
      return Array.from(line).slice(0, SELECTION_LIMIT).join("");
  }
  return "";
}
