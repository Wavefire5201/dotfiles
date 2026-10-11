pragma Singleton
import QtQuick

// Stub of noctalia's Logger for the logic harness.
QtObject {
  function d(...args) { console.log("[stub d]", args.join(" ")); }
  function i(...args) { console.log("[stub i]", args.join(" ")); }
  function w(...args) { console.log("[stub w]", args.join(" ")); }
  function e(...args) { console.log("[stub e]", args.join(" ")); }
}
