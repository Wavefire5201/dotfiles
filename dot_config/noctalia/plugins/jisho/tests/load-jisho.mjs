// Loads ../jisho.js (a QML `.pragma library` script) into a vm context so node can test it.
import { readFileSync } from "node:fs";
import vm from "node:vm";

export const here = new URL(".", import.meta.url);

export function loadJisho() {
  const src = readFileSync(new URL("../jisho.js", here), "utf8").replace(/^\.pragma library\s*$/m, "");
  const ctx = vm.createContext({});
  vm.runInContext(src, ctx, { filename: "jisho.js" });
  return ctx;
}

export function fixture(name) {
  return readFileSync(new URL(`fixtures/${name}.json`, here), "utf8");
}
