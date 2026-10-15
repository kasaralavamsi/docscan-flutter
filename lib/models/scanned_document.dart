import 'scan_page.dart';

class ScannedDocument {
  final String id;
  String name;
  final DateTime createdAt;
  final List<ScanPage> pages;
  String? pdfPath;

  ScannedDocument({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.pages,
    this.pdfPath,
  });
}
