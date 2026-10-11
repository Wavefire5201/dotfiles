import { test } from "node:test";
import assert from "node:assert/strict";
import { loadJisho, fixture } from "./load-jisho.mjs";

const J = loadJisho();
// vm-realm objects carry foreign prototypes; compare them as plain data
const plain = (x) => JSON.parse(JSON.stringify(x));
const entries = (name) => J.parseResponse(fixture(name));
const bySlug = (list, slug) => list.find((e) => e.slug === slug);

test("handles only the >jisho command", () => {
  assert.equal(J.handles(">jisho"), true);
  assert.equal(J.handles(">jisho "), true);
  assert.equal(J.handles(">jisho 食べる"), true);
  assert.equal(J.handles(">jishox"), false);
  assert.equal(J.handles("jisho neko"), false);
  assert.equal(J.handles(">kaomoji cat"), false);
});

test("parseQuery strips the prefix and surrounding space", () => {
  assert.equal(J.parseQuery(">jisho"), "");
  assert.equal(J.parseQuery(">jisho    "), "");
  assert.equal(J.parseQuery(">jisho  食べる  "), "食べる");
  assert.equal(J.parseQuery(">jisho to eat"), "to eat");
});

test("searchUrl encodes the keyword against the API or a given base", () => {
  assert.equal(J.searchUrl("食べる"), "https://jisho.org/api/v1/search/words?keyword=%E9%A3%9F%E3%81%B9%E3%82%8B");
  assert.equal(J.searchUrl("to eat", "http://127.0.0.1:9/api"), "http://127.0.0.1:9/api?keyword=to%20eat");
  assert.equal(J.searchUrl("a&b#c"), "https://jisho.org/api/v1/search/words?keyword=a%26b%23c");
});

test("wordUrl and searchPageUrl point at jisho.org pages", () => {
  assert.equal(J.wordUrl("食べる"), "https://jisho.org/word/%E9%A3%9F%E3%81%B9%E3%82%8B");
  assert.equal(J.wordUrl("518693b5d5dda7b2c602e64d"), "https://jisho.org/word/518693b5d5dda7b2c602e64d");
  assert.equal(J.searchPageUrl("zzq xj"), "https://jisho.org/search/zzq%20xj");
});

test("parseResponse maps a kanji word with reading, tags and senses", () => {
  const list = entries("taberu");
  assert.equal(list.length, 2);
  assert.deepEqual(plain(list[0]), {
    slug: "食べる",
    word: "食べる",
    reading: "たべる",
    title: "食べる",
    isCommon: true,
    jlpt: "N5",
    senses: [
      { definitions: ["to eat"], partsOfSpeech: ["Ichidan verb", "Transitive verb"], tags: [], info: [], seeAlso: [] },
      {
        definitions: ["to live on (e.g. a salary)", "to live off", "to subsist on"],
        partsOfSpeech: ["Ichidan verb", "Transitive verb"],
        tags: [],
        info: [],
        seeAlso: [],
      },
    ],
    otherForms: [],
  });
});

test("parseResponse falls back to the reading for kana-only words", () => {
  const e = bySlug(entries("arigatou"), "ありがとさん");
  assert.equal(e.word, "");
  assert.equal(e.title, "ありがとさん");
  assert.deepEqual(plain(e.otherForms), ["ありがとうさん"]);
});

test("parseResponse keeps hex-slug wikipedia entries without a reading", () => {
  const e = bySlug(entries("arigatou"), "518693b5d5dda7b2c602e64d");
  assert.equal(e.title, "ありがとう (漫画)");
  assert.equal(e.reading, "");
  assert.equal(e.isCommon, false);
  assert.equal(e.jlpt, "");
  assert.deepEqual(plain(e.senses[0].partsOfSpeech), ["Wikipedia definition"]);
});

test("parseResponse titles by the first form, not the slug", () => {
  const e = bySlug(entries("neko"), "根刮ぎ");
  assert.equal(e.title, "根こそぎ");
  assert.deepEqual(plain(e.otherForms), ["根刮ぎ (ねこそぎ)"]);
});

test("parseResponse carries sense tags and see-also", () => {
  const e = entries("neko").find((x) => x.senses.some((s) => s.seeAlso.length));
  const s = e.senses.find((x) => x.seeAlso.length);
  assert.deepEqual(plain(s.seeAlso), ["猫車"]);
  assert.deepEqual(plain(s.tags), ["Abbreviation"]);
});

test("parseResponse returns an empty list for no matches", () => {
  assert.deepEqual(plain(entries("none")), []);
});

test("parseResponse throws on a non-200 meta status or bad JSON", () => {
  assert.throws(() => J.parseResponse('{"meta":{"status":404},"data":[]}'), /404/);
  assert.throws(() => J.parseResponse("<html>"));
});

test("summary leads with the reading only when it adds information", () => {
  const list = entries("taberu");
  assert.equal(J.summary(list[0]), "たべる · to eat");
  const shoku = bySlug(entries("eat"), "食う");
  assert.equal(J.summary(shoku), "くう · " + shoku.senses[0].definitions.join("; "));
  const kana = bySlug(entries("arigatou"), "ありがとさん");
  assert.equal(J.summary(kana), kana.senses[0].definitions.join("; "));
});

test("addToHistory puts the entry first, dedupes by slug and caps the length", () => {
  const [a, b] = entries("taberu");
  let h = J.addToHistory([], a);
  h = J.addToHistory(h, b);
  h = J.addToHistory(h, a);
  assert.deepEqual(plain(h.map((e) => e.slug)), [a.slug, b.slug]);

  const many = entries("eat");
  let capped = [];
  for (const e of many) capped = J.addToHistory(capped, e, 5);
  assert.equal(capped.length, 5);
  assert.equal(capped[0].slug, many[many.length - 1].slug);
});

test("addToHistory does not mutate its input", () => {
  const [a, b] = entries("taberu");
  const h = [a];
  J.addToHistory(h, b);
  assert.equal(h.length, 1);
});

test("removeFromHistory drops the matching slug only", () => {
  const [a, b] = entries("taberu");
  const h = J.removeFromHistory([a, b], a.slug);
  assert.deepEqual(plain(h.map((e) => e.slug)), [b.slug]);
});

test("cleanSelection keeps the first non-empty line, collapsed and capped", () => {
  assert.equal(J.cleanSelection("\n\n  食べる  \nsecond"), "食べる");
  assert.equal(J.cleanSelection("to   eat\tfood"), "to eat food");
  assert.equal(J.cleanSelection("   \n \n"), "");
  assert.equal(J.cleanSelection(""), "");
  assert.equal(J.cleanSelection(undefined), "");
  assert.equal(J.cleanSelection("あ".repeat(100)), "あ".repeat(64));
});

test("chips flags common words and the JLPT level", () => {
  const neko = entries("neko");
  assert.deepEqual(plain(J.chips(bySlug(neko, "猫"))), ["Common", "JLPT N5"]);
  assert.deepEqual(plain(J.chips(bySlug(neko, "猫背"))), ["Common"]);
  assert.deepEqual(plain(J.chips(bySlug(entries("arigatou"), "518693b5d5dda7b2c602e64d"))), []);
});

test("posHeading shows parts of speech only when they change", () => {
  const senses = bySlug(entries("neko"), "猫").senses;
  assert.equal(J.posHeading(senses, 0), "Noun");
  assert.equal(J.posHeading(senses, 1), "");
  assert.equal(J.posHeading(senses, 5), "");
  assert.equal(J.posHeading(senses, 6), "Wikipedia definition");
  assert.equal(J.posHeading(entries("taberu")[0].senses, 0), "Ichidan verb, Transitive verb");
});

test("senseNotes joins tags, info and see-also", () => {
  const senses = bySlug(entries("neko"), "猫").senses;
  assert.equal(J.senseNotes(senses[0]), "");
  assert.equal(J.senseNotes(senses[3]), "Abbreviation · See also 猫車");
  assert.equal(J.senseNotes(senses[5]), "Usually written using kana alone · Slang");
  const past = bySlug(entries("arigatou"), "有難うございました").senses[0];
  assert.equal(J.senseNotes(past), "Polite (teineigo) language · Usually written using kana alone · used for past actions");
});
