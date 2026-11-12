import 'platform_helper_io.dart'
    if (dart.library.js_interop) 'platform_helper_web.dart' as helper;

class PlatformHelper {
  static bool get isWeb => helper.isWebPlatform();

  static void installPwaApp() {
    helper.triggerPwaInstall();
  }

  /// Universal file download / save (triggers browser blob download on Web or saves to Downloads on Windows/Mac)
  static Future<String?> downloadFile(String filename, String content, {String mimeType = 'text/plain;charset=utf-8'}) =>
      helper.downloadFile(filename, content, mimeType);

  /// Universal HTML report print / Save as PDF
  static void printHtml(String htmlContent, String title) =>
      helper.printHtml(htmlContent, title);
}
