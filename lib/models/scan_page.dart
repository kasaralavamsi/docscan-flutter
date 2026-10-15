class ScanPage {
  final String id;
  final String path;
  final String filter;

  const ScanPage({
    required this.id,
    required this.path,
    this.filter = 'Original',
  });

  ScanPage copyWith({String? path, String? filter}) => ScanPage(
        id: id,
        path: path ?? this.path,
        filter: filter ?? this.filter,
      );
}
