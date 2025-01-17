import 'package:flutter/foundation.dart';

class _Factory {
  _Factory({required this.tag, this.factory});

  final String tag;
  final dynamic factory;
}

class _DependencyItem {
  final dynamic obj;
  final bool keepAlive;
  _DependencyItem({required this.obj, this.keepAlive = false});
}

/// [Injex]
/// 依赖注入管理类
///
class Injex {
  static Injex? _instance;
  static Injex get _shared => _instance ??= Injex._();

  ///
  /// [PUBLIC APIS]
  ///
  static void put<D>(D object, {String? tag, bool keepAlive = false}) {
    Injex._shared._put<D>(object, tag: tag, keepAlive: keepAlive);
  }

  static void putLater<D>(D Function() factory, {String? tag}) {
    Injex._shared._putLater<D>(factory, tag: tag);
  }

  static D? get<D>({String? tag, D Function()? factory}) {
    return Injex._shared._get<D>(tag: tag ?? D.toString(), factory: factory);
  }

  static void remove<D>({String? tag, D? target, bool keepFactory = false}) {
    Injex._shared._remove(tag ?? D.toString(), target: target, keepFactory: keepFactory);
  }

  static void delete<D>({String? tag, bool keepFactory = false}) {
    Injex._shared._delete(tag ?? D.toString(), keepFactory: keepFactory);
  }

  static void debug([bool enable = true]) {
    Injex._shared._debug(enable);
  }

  Injex._();

  ///
  /// [PRIVATE]
  ///
  ///  v => _DependencyItem | List<_DependencyItem>
  final Map<String, dynamic> _map = {};
  final Map<String, _Factory> _factories = {};

  bool _debugEnabled = false;

  _debug(bool enable) {
    _debugEnabled = enable;
  }

  _log(String msg) {
    if (_debugEnabled) {
      debugPrint('【Injex】 $msg');
    }
  }

  void _put<D>(D object, {String? tag, required bool keepAlive}) {
    final k = tag ?? D.toString();
    final current = _map[k];
    if (current == null) {
      _map[k] = _DependencyItem(obj: object, keepAlive: keepAlive);
      return;
    } else {
      if (current is List<_DependencyItem>) {
        final last = current.lastOrNull;
        if (last != null && last.keepAlive) {
          /// push to keepAlive
          _map[k].add(_DependencyItem(obj: object, keepAlive: keepAlive));
          return;
        } else {
          /// replace last object
          _map[k].removeLast();
          _map[k].add(_DependencyItem(obj: object, keepAlive: keepAlive));
          return;
        }
      } else {
        final curItem = (current as _DependencyItem);
        if (curItem.keepAlive) {
          /// push to keepAlive
          _map[k] = [curItem, _DependencyItem(obj: object, keepAlive: keepAlive)];
          return;
        } else {
          /// replace last object
          _map[k] = _DependencyItem(obj: object, keepAlive: keepAlive);
          return;
        }
      }
    }
  }

  void _putLater<D>(D Function() factory, {String? tag}) {
    final k = tag ?? D.toString();
    if (_factories.containsKey(k)) {
      _log('dependency @$k already exists, check if meant to');
    }
    _factories[k] = _Factory(tag: k, factory: factory);
  }

  D? _get<D>({required String tag, D Function()? factory}) {
    final k = tag;
    final obj = _map[k];
    if (obj != null) {
      if (obj is List<_DependencyItem> && obj.isNotEmpty && obj.last.obj is D) {
        return obj.last.obj;
      } else if (obj is _DependencyItem && obj.obj is D) {
        return obj.obj;
      } else {
        _log("dependency @$k is not type of $D , check the put method");
        final item = factory?.call();
        if (item != null) {
          _map[k] = _DependencyItem(obj: obj, keepAlive: false);
          return item;
        }
        return null;
      }
    }

    // get obj from factory
    if (factory != null) {
      final obj = factory();
      _map[k] = _DependencyItem(obj: obj, keepAlive: false);
      return obj;
    }

    // get obj from factory
    final fac = _factories[k];
    if (fac != null) {
      final obj = fac.factory.call();
      _map[k] = _DependencyItem(obj: obj, keepAlive: false);
      return obj;
    }
    return null;
  }

  void _remove<D>(String tag, {D? target, bool keepFactory = false}) {
    final obj = _map[tag];
    if (obj is List<_DependencyItem>) {
      if (target != null) {
        obj.removeWhere((e) => e.obj == target);
      } else {
        obj.removeLast();
      }
      if (obj.isEmpty) {
        _map.remove(tag);
        if (keepFactory == false) {
          _factories.remove(tag);
        }
        _log("remove dependency @$tag");
      } else {
        _log("remove dependency @$tag remain ${obj.length}");
      }
    } else {
      _map.remove(tag);
      if (keepFactory == false) {
        _factories.remove(tag);
      }
      _log("remove dependency @$tag");
    }
  }

  void _delete(String tag, {bool keepFactory = false}) {
    _map.remove(tag);
    if (keepFactory == false) {
      _factories.remove(tag);
    }
    _log("delete dependency @$tag");
  }
}
