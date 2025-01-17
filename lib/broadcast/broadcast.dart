// ignore_for_file: unintended_html_in_doc_comment

import 'package:thunderingcat_core/base/unique.dart';
import 'package:flutter/foundation.dart';

/// [Broadcast] 广播类及相关类型定义

class BroadcastListener {
  final String id;
  dynamic callback;
  BroadcastListener(this.id, this.callback);
}

class BroadcastSubscription {
  final String _id;
  final String _event;
  BroadcastSubscription(String event, String id)
      : _id = id,
        _event = event;

  void remove() {
    Broadcast._shared._removeListener(_event, _id);
  }
}

class Broadcast {
  static Broadcast? _instance;

  static Broadcast get _shared => _instance ??= Broadcast._();

  static BroadcastSubscription addListener<T>(dynamic event, void Function(T data) listener, {bool single = false}) {
    if (event is String) {
      return _shared._addListener(event, listener as dynamic, single);
    } else if (event is BroadcastEventInterface) {
      return _shared._addListener(event.name, listener as dynamic, single);
    } else {
      throw Exception('[Broadcast] event must be String or BroadcastEventInterface');
    }
  }

  /// used to listen events inherited from [GlobalBroadcastEventInterface]
  static BroadcastSubscription addEventListener<E>(void Function(E event) listener, {String? name}) {
    return _shared._addListener(name ?? E.toString(), listener as dynamic, false);
  }

  static void emit<E>({String? name, dynamic data}) {
    _shared._emit(name ?? E.toString(), data);
  }

  static void removeAllListeners<E>([String? event]) {
    _shared._removeAllListeners(event ?? E.toString());
  }

  static int count<E>([String? event]) {
    return _shared._listeners[event ?? E.toString()]?.length ?? 0;
  }

  Broadcast._();

  final Map<String, List<BroadcastListener>> _listeners = {};

  bool _hasListener(String event) {
    return (_listeners[event] ?? []).isNotEmpty;
  }

  /// [notify] 通知事件
  void _emit(String event, dynamic data) {
    if (!_hasListener(event)) {
      return;
    }
    for (var listener in _listeners[event]!) {
      listener.callback.call(data);
    }
  }

  /// return [UnSubscribeCallback]
  BroadcastSubscription _addListener(String event, dynamic callback, bool single) {
    final id = Unique.id();
    final listener = BroadcastListener(id, callback);
    final listeners = (_listeners[event] ?? []);
    if (single) {
      listeners.clear();
    }
    listeners.add(listener);
    _listeners[event] = listeners;
    return BroadcastSubscription(event, id);
  }

  void _removeListener(String event, String id) {
    if (_listeners.containsKey(event) && _listeners[event] is List<BroadcastListener>) {
      _listeners[event]!.removeWhere((e) => e.id == id);
    }
  }

  void _removeAllListeners(String event) {
    _listeners.remove(event);
  }
}

/// [BroadcastEventInterface]
/// 广播事件接口
abstract class BroadcastEventInterface<T> {
  static String _defaultName() {
    return '${DateTime.now().millisecondsSinceEpoch}_${Unique.id()}';
  }

  late final String name;

  BroadcastEventInterface({String? name}) {
    this.name = name ?? BroadcastEventInterface._defaultName();
  }

  /// [监听者数量]
  int get count => Broadcast.count(name);

  void emit(T? data) {
    Broadcast.emit(name: name, data: data);
  }

  BroadcastSubscription? addListener(void Function(T? data) callback);
}

/// [BroadcastEvent]
/// 实例化广播事件、用于非全局范围内，可销毁场景中使用
/// 例如: 仅在当前页面内有效。
///
/// [使用示例]
///
/// 创建事件[name: deafult => 随机生成唯一ID]、[single: deafult => false]均为可选参数
/// final countChangeEvent = BroadcastEvent<int>(name: 'countChangeEvent', single: true);
///
/// 创建监听
/// countChangeEvent.addListener((count) {
///   debugPrint('count:$count');
/// });
///
/// 发送事件
/// countChangeEvent.emit(1);
///
class BroadcastEvent<T> extends BroadcastEventInterface<T> {
  /// 单点广播
  /// [default:false] 默认为多点广播、事件可拥有多个监听者
  /// 开启后、该事件将永远只同时存在一个监听者，后者会替代前者
  final bool single;

  bool _disposed = false;

  BroadcastEvent({String? name, this.single = false}) : super(name: name != null ? '${name}_${Unique.id()}' : null);

  _log(String msg) {
    debugPrint('【BroadcastEventInterface:$name】 $msg');
  }

  /// [发送事件]
  @override
  void emit(T? data) {
    if (_disposed) {
      _log('has been disposed,should not send event again');
      return;
    }
    super.emit(data);
  }

  /// [监听事件]
  @override
  BroadcastSubscription? addListener(void Function(T? data) callback) {
    if (_disposed) {
      _log('has been disposed,should not add listener again');
      return null;
    }
    return Broadcast.addListener(name, callback as dynamic, single: single);
  }

  /// [移除事件]
  void dispose() {
    if (_disposed) {
      _log('has been disposed,should not dispose again');
      return;
    }
    _disposed = true;
    Broadcast.removeAllListeners(name);
  }
}

/// [GlobalBroadcastEventInterface]
/// 全局广播事件接口
/// 全局广播、应用生命周期内有效
///
/// [使用示例]
///
/// 创建事件、默认使用类名作为事件名，因此应避免出现重名类
/// 也可以 [override name] 自定义事件名
///
/// class GBOnRouteChanged extends GlobalBroadcastEventInterface<String> {
///   GBOnTabNavigationPageChanged({super.data});
/// }
///
/// 创建监听
///  Broadcast.addEventListener<GBOnRouteChanged>((e) {
///    final route = e.data;
///  });
///
/// 发送事件
/// GBOnRouteChanged(data: 'index').emit();

abstract class GlobalBroadcastEventInterface<T> {
  String get name => runtimeType.toString();

  T? data;

  GlobalBroadcastEventInterface({this.data});

  void emit() {
    Broadcast.emit(name: name, data: this);
  }
}
