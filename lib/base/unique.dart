class Unique {
  static Unique? _instance;
  Unique._internal();
  factory Unique() {
    _instance ??= Unique._internal();
    return _instance!;
  }

  double _v = 0.0;

  String get _id {
    _v += 1.0;
    return _v.toStringAsFixed(0);
  }

  static String id() {
    return Unique()._id;
  }
}
