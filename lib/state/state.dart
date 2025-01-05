import 'package:flutter/widgets.dart';

typedef Observable<T> = _StateNotifier<T>;

typedef Computed<T> = _ComputeStateNotifier<T>;

typedef Observer = _StateListenableBuilder;

abstract class ObservableVariable<T> extends ChangeNotifier {
  T get v;

  void notify() {
    notifyListeners();
  }
}

class _StateNotifier<T> extends ObservableVariable<T> {
  _StateNotifier(this._v);

  T _v;

  @override
  T get v => _v;

  set v(T newValue) {
    if (_v == newValue) {
      return;
    }
    _v = newValue;
    notifyListeners();
  }

  /// 仅设置值、不通知更新。如果 [notifyIfNeccessary] 为 [true] 则更新逻辑同 set v、判断 T operator == 是否相等
  void set(T newValue, [bool notifyIfNeccessary = false]) {
    if (notifyIfNeccessary == false) {
      _v = newValue;
    } else {
      v = newValue;
    }
  }

  /// 默认[notify=true]无论对象值是否变化都进行强制通知、可修改[notify]参数控制是否通知、为[false]则采取 set value方式
  void update(T newValue, [bool notify = true]) {
    if (notify) {
      v = newValue;
      notifyListeners();
    } else {
      v = newValue;
    }
  }
}

class _ComputeStateNotifier<T> extends ObservableVariable<T> {
  final T Function() _compute;

  @override
  T get v => _compute();

  void _onDepChanged() {
    notifyListeners();
  }

  _ComputeStateNotifier(this._compute, [List<ChangeNotifier> deps = const []]) {
    if (deps.isNotEmpty) {
      for (var item in deps) {
        item.addListener(_onDepChanged);
      }
    }
  }
}

///
/// [_StateListenableBuilder]
/// 监听 [Listenable] 或 [List<Listenable>] 变化并重新build子组件
class _StateListenableBuilder extends StatefulWidget {
  const _StateListenableBuilder({
    required this.listenable,
    required this.builder,
  });
  final dynamic listenable;
  final Widget Function(BuildContext) builder;

  @override
  State<_StateListenableBuilder> createState() => __StateListenableBuilderState();
}

class __StateListenableBuilderState extends State<_StateListenableBuilder> {
  void _handleChange() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    if (widget.listenable is Listenable) {
      (widget.listenable as Listenable).addListener(_handleChange);
    } else if (widget.listenable is List<Listenable>) {
      for (var item in widget.listenable) {
        item.addListener(_handleChange);
      }
    } else {
      debugPrint('【State】注意！！ ${widget.listenable.runtimeType} 不是 Listenable | List<Listenable> 类型、请检查Observer的listenable值类型');
    }
  }

  @override
  void dispose() {
    super.dispose();
    if (widget.listenable is Listenable) {
      (widget.listenable as Listenable).removeListener(_handleChange);
    } else if (widget.listenable is List<Listenable>) {
      for (var item in widget.listenable as List<Listenable>) {
        item.removeListener(_handleChange);
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

abstract class ObserverState<T extends StatefulWidget> extends State<T> {
  ObservableVariable? get listenable => null;

  List<ObservableVariable> get listenables => [];

  Widget buildChild(BuildContext context);

  @override
  Widget build(BuildContext context) {
    return Observer(
        listenable: listenable != null ? [listenable!] : listenables,
        builder: (_) {
          return buildChild(context);
        });
  }
}
