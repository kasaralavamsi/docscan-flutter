import 'scan_page.dart';

class ScannedDocument {
  final String id;
  final String name;
  final DateTime createdAt;
  final List<ScanPage> pages;
  const ScannedDocument({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.pages,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'pages': pages.map((p) => p.toJson()).toList(),
  };
  factory ScannedDocument.fromJson(Map<String, dynamic> json) =>
      ScannedDocument(
        id: json['id'] as String,
        name: json['name'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        pages: [
          for (final p in json['pages'] as List)
            ScanPage.fromJson(p as Map<String, dynamic>),
        ],
      );
}
