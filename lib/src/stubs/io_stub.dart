class Platform {
  static bool get isAndroid => false;
  static bool get isIOS => false;
  static bool get isLinux => false;
  static bool get isWindows => false;
  static bool get isMacOS => false;
  static String get operatingSystem => '';
  static Map<String, String> get environment => {};
}

class Directory {
  Directory(this.path);
  final String path;
  bool existsSync() => false;
  void createSync({final bool recursive = false}) {}
  static Directory get current => Directory('');
}

class File {
  File(this.path);
  final String path;
  bool existsSync() => false;
  void writeAsBytesSync(final List<int> bytes) {}
  List<int> readAsBytesSync() => [];
}
