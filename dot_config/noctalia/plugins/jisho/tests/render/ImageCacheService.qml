pragma Singleton
import QtQuick

// Render-harness stub: the real service builds a layer-shell PanelWindow, which the
// offscreen platform cannot provide, and every Commons singleton depends on it transitively.
QtObject {
  property bool imageMagickAvailable: false
  property bool initialized: true
  signal cacheHit(string cacheKey, string cachedPath)
  signal cacheMiss(string cacheKey)
  signal processingComplete(string cacheKey, string cachedPath)
  signal processingFailed(string cacheKey, string error)
  function init() {}
  function needsConversion(filePath) { return false; }
  function getThumbnail(sourcePath, callback) {}
  function getLarge(sourcePath, width, height, callback) {}
  function getNotificationIcon(imageUri, appName, summary, callback) {}
  function getCircularAvatar(url, username, callback) {}
}
