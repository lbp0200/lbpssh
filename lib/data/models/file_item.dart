class FileItem {
  final String name;
  final String path;
  final bool isDirectory;
  final int size;
  final DateTime? modified;
  final String permissions;

  FileItem({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.size = 0,
    this.modified,
    this.permissions = '',
  });
}
