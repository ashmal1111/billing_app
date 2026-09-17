import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'app_storage_base.dart';
import 'security_service.dart';

AppStorage createPlatformStorage() => _FileStorage();

class _FileStorage implements AppStorage {
  Future<File> _file(String fileName) async {
    Directory directory;
    try {
      directory = await getApplicationDocumentsDirectory()
          .timeout(const Duration(milliseconds: 100));
    } catch (_) {
      directory = Directory.systemTemp;
    }
    final safeName = SecurityValidator.sanitizeFileName(fileName);
    final file = File('${directory.path}/$safeName');

    // Sandboxing check: ensure file path cannot escape directory
    final dirPath = directory.path;
    if (!file.path.startsWith(dirPath)) {
      throw Exception('Security error: file path escapes sandbox');
    }

    return file;
  }

  @override
  Future<String?> readText(String fileName) async {
    final file = await _file(fileName);
    if (!await file.exists()) {
      return null;
    }

    return file.readAsString();
  }

  @override
  Future<void> writeText(String fileName, String contents) async {
    final file = await _file(fileName);
    await file.writeAsString(contents);
  }

  @override
  Future<ExportResult> exportText(
    String fileName,
    String contents, {
    required String mimeType,
  }) async {
    final file = await _file(fileName);
    await file.writeAsString(contents);

    return ExportResult(
      fileName: fileName,
      location: file.parent.path,
      sharePath: file.path,
    );
  }
}
