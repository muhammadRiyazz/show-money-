import 'dart:js_interop';

@JS('window.triggerPwaInstall')
external void _triggerPwaInstall();

@JS('window.downloadFileBlob')
external void _downloadFileBlob(JSString filename, JSString content, JSString mimeType);

@JS('window.printHtmlReport')
external void _printHtmlReport(JSString htmlContent, JSString title);

bool isWebPlatform() => true;

void triggerPwaInstall() {
  try {
    _triggerPwaInstall();
  } catch (e) {
    // Fallback if not available
  }
}

Future<String?> downloadFile(String filename, String content, String mimeType) async {
  try {
    _downloadFileBlob(filename.toJS, content.toJS, mimeType.toJS);
    return filename;
  } catch (e) {
    return null;
  }
}

void printHtml(String htmlContent, String title) {
  try {
    _printHtmlReport(htmlContent.toJS, title.toJS);
  } catch (e) {
    // Fallback if not available
  }
}
