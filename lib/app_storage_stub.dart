import 'app_storage_base.dart';

AppStorage createPlatformStorage() => _UnsupportedStorage();

class _UnsupportedStorage implements AppStorage {
  @override
  Future<String?> readText(String fileName) {
    throw UnsupportedError('Storage is not available on this platform.');
  }

  @override
  Future<void> writeText(String fileName, String contents) {
    throw UnsupportedError('Storage is not available on this platform.');
  }

  @override
  Future<ExportResult> exportText(
    String fileName,
    String contents, {
    required String mimeType,
  }) {
    throw UnsupportedError('Export is not available on this platform.');
  }
}
