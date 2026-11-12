import 'dart:io';

bool isWebPlatform() => false;

void triggerPwaInstall() {
  // Not a web platform, app is already running natively
}

Future<String?> downloadFile(String filename, String content, String mimeType) async {
  try {
    String? dirPath;
    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null) {
        final dl = Directory('$userProfile\\Downloads');
        dirPath = dl.existsSync() ? dl.path : userProfile;
      }
    } else if (Platform.isMacOS || Platform.isLinux) {
      final home = Platform.environment['HOME'];
      if (home != null) {
        final dl = Directory('$home/Downloads');
        dirPath = dl.existsSync() ? dl.path : home;
      }
    }
    dirPath ??= Directory.current.path;
    final file = File('$dirPath${Platform.pathSeparator}$filename');
    await file.writeAsString(content);
    return file.path;
  } catch (e) {
    return null;
  }
}

void printHtml(String htmlContent, String title) {
  try {
    final tempDir = Directory.systemTemp;
    final safeTitle = title.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final file = File('${tempDir.path}${Platform.pathSeparator}$safeTitle.html');
    file.writeAsStringSync(htmlContent);
    if (Platform.isWindows) {
      Process.run('cmd', ['/c', 'start', '', file.path]);
    } else if (Platform.isMacOS) {
      Process.run('open', [file.path]);
    } else if (Platform.isLinux) {
      Process.run('xdg-open', [file.path]);
    }
  } catch (_) {}
}
