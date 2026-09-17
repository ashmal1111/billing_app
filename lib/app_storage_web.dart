// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;

import 'app_storage_base.dart';

AppStorage createPlatformStorage() => _BrowserStorage();

class _BrowserStorage implements AppStorage {
  static const _keyPrefix = 'billing_app.';

  String _key(String fileName) => '$_keyPrefix$fileName';

  @override
  Future<String?> readText(String fileName) async {
    return html.window.localStorage[_key(fileName)];
  }

  @override
  Future<void> writeText(String fileName, String contents) async {
    html.window.localStorage[_key(fileName)] = contents;
  }

  @override
  Future<ExportResult> exportText(
    String fileName,
    String contents, {
    required String mimeType,
  }) async {
    final blob = html.Blob([utf8.encode(contents)], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..download = fileName
      ..style.display = 'none';

    html.document.body?.children.add(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);

    return ExportResult(fileName: fileName, location: 'Downloads');
  }
}
