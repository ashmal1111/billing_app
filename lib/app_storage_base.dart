abstract class AppStorage {
  Future<String?> readText(String fileName);

  Future<void> writeText(String fileName, String contents);

  Future<ExportResult> exportText(
    String fileName,
    String contents, {
    required String mimeType,
  });
}

class ExportResult {
  const ExportResult({
    required this.fileName,
    required this.location,
    this.sharePath,
  });

  final String fileName;
  final String location;
  final String? sharePath;

  bool get canShareFile => sharePath != null;
}
