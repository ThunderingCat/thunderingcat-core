import 'package:flutter/Widgets.dart';
import 'stack_router.dart';

typedef BackHandlerInvoker = Future<bool> Function();
typedef BackHandlerAddEventListener = BackHandlerEventSubscription Function(BackHandlerInvoker invoker);

class BackHandlerEventSubscription {
  BackHandlerEventSubscription(this.id);
  List<BackHandlerInvoker> get invokers => StackRouterBackHandler.shared._invokers;

  final int id;

  dispose() {
    if (invokers.isNotEmpty && invokers.last.hashCode == id) {
      invokers.removeLast();
    }
  }
}

class StackRouterBackHandler {
  static StackRouterBackHandler? _instance;

  static StackRouterBackHandler get shared => _instance ??= StackRouterBackHandler();

  final List<BackHandlerInvoker> _invokers = <BackHandlerInvoker>[];

  BackHandlerEventSubscription addEventListener(BackHandlerInvoker invoker) {
    _invokers.add(invoker);
    return BackHandlerEventSubscription(invoker.hashCode);
  }

  void clear() {
    if (_invokers.isNotEmpty) _invokers.clear();
  }

  BackHandlerInvoker? get invoker => _invokers.lastOrNull;
}

class StackRouterBackButtonDispatcher extends RootBackButtonDispatcher {
  StackRouterBackButtonDispatcher(this.delegate);

  final StackRouterDelegate delegate;

  @override
  Future<bool> didPopRoute() async {
    if (StackRouterBackHandler.shared.invoker != null) {
      bool handled = await StackRouterBackHandler.shared.invoker!();
      if (handled) {
        return true;
      }
    }
    return delegate.handlePopRoute();
  }
}
