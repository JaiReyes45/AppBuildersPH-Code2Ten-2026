class OcrInput {
  OcrInput(this.path);
  final String path;
  double get scaleX => 1;
  double get scaleY => 1;
  bool get resized => false;
  Future<void> close() async {}
  static Future<OcrInput> prepare(
    String path, {
    int maxLongEdge = 1600,
  }) async => OcrInput(path);
}
