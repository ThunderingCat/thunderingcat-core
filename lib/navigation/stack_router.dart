import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../injex/injex.dart';
import './base.dart';
import './events.dart';

/// [StackRouteInformationParser]
/// handle route information
class StackRouteInformationParser extends RouteInformationParser<Uri> {
  @override
  Future<Uri> parseRouteInformation(RouteInformation routeInformation) {
    return SynchronousFuture(routeInformation.uri);
  }

  @override
  RouteInformation? restoreRouteInformation(Uri configuration) {
    return RouteInformation(uri: configuration);
  }
}

/// [StackRouteInformationProvider]
class StackRouteInformationProvider extends PlatformRouteInformationProvider {
  StackRouteInformationProvider({String initialRoute = '/', Object? state})
      : super(
          initialRouteInformation: RouteInformation(
            uri: Uri(path: initialRoute),
            state: state,
          ),
        );
}

/// [StackRouterDelegate]
/// router delegate
class StackRouterDelegate extends RouterDelegate<Uri> with PopNavigatorRouterDelegateMixin, ChangeNotifier {
  final GlobalKey<NavigatorState> _navigator;

  @override
  GlobalKey<NavigatorState>? get navigatorKey => _navigator;

  /// get current delegate through context
  static StackRouterDelegate of(BuildContext context) {
    return Router.of(context).routerDelegate as StackRouterDelegate;
  }

  StackRouterDelegate({
    required List<StackPageDescriptor> pages,
    StackRouterDelegateConfiguration? configs,
  }) : _navigator = GlobalKey<NavigatorState>() {
    assert(pages.isNotEmpty, 'At least one PageDescriptor should be provided, but got ${pages.length}');
    _configs = configs ?? StackRouterDelegateConfiguration();
    _descriptors = pages;

    Injex.put<StackRouterDelegate>(this);
  }

  _log(String text) async {
    debugPrint('【Navigation】$text');
  }

  late final StackRouterDelegateConfiguration _configs;
  late final List<StackPageDescriptor> _descriptors;

  final List<StackRoute> _routes = [];

  List<StackRoute> get routes => List.unmodifiable(_routes);

  double _count = 0;

  /// start from 0
  int get _index => routes.length - 1;

  OverlayState? get _overlay => _navigator.currentState?.overlay;

  @override
  Widget build(BuildContext context) {
    final pages = _routes.map((e) => e.page).toList();
    return Navigator(
      key: navigatorKey,
      pages: pages,
      onDidRemovePage: _onDidRemovePage,
      onUnknownRoute: _onUnknownRoute,
    );
  }

  void _onDidRemovePage(Page<Object?> page) {}

  Route<dynamic> _onUnknownRoute(RouteSettings settings) {
    return _configs.onUnknownRoute?.call(settings) ?? MaterialPageRoute(builder: (_) => _DefaultUnknownPage());
  }

  /// handle routes pushed by operating system, typically processing initial route
  @override
  Future<Uri> setNewRoutePath(Uri configuration) {
    /// default to '/' ; configure this through [StackRouteInformationProvider.initialRoute]
    final index = _descriptors.indexWhere((e) => e.name == configuration.path);

    _log('Set New Route By Path :${configuration.path}');

    /// [TODO: support NOT-FOUND on platform web]
    if (index == -1) {
      if (_routes.isEmpty) {
        /// application start up , first route pushed. no route name matched
        _routes.add(_buildRoute(_descriptors.first));
        _log('Set Initial Route, No Page Descriptor Matched :${configuration.path}, Use First Route');
      } else {
        _log('No Page Descriptor Matched :${configuration.path}, Navigation Action Ignored');
      }
    } else {
      _routes.add(_buildRoute(_descriptors[index]));
    }
    return SynchronousFuture(configuration);
  }

  StackRoute _buildRoute(
    StackPageDescriptor descriptor, {
    dynamic params,
    bool forResult = false,
  }) {
    ++_count;
    final pageName = '${descriptor.name}.${_count.toStringAsFixed(0)}';
    final pageKey = ValueKey('page@$pageName');
    Page page;
    if (descriptor.type == StackPageType.material) {
      final child = descriptor.builder(ValueKey('route@$pageName'));
      assert(child is! MaterialPage, 'MaterialPage returned by [StackPageDescriptor@builder] but StackPageType.material is set,Use StackPageType.none if you want to use custom page');
      page = MaterialPage(child: child, name: pageName, key: pageKey);
    } else if (descriptor.type == StackPageType.cupertino) {
      final child = descriptor.builder(ValueKey('route@$pageName'));
      assert(child is! CupertinoPage, 'CupertinoPage returned by [StackPageDescriptor@builder] but StackPageType.cupertino is set,Use StackPageType.none if you want to use custom page');
      page = CupertinoPage(child: child, name: pageName, key: pageKey);
    } else {
      //none
      final child = descriptor.builder(pageKey);

      /// if child is type of Page, use it directly. otherwise , throw assertion
      assert(child is Page, 'Widget returned by [StackPageDescriptor@builder] is not typeOf Page,Use StackPageType.material or StackPageType.cupertino if you dont need custom page');
      page = child as Page;
    }
    final controller = descriptor.controller?.call();
    final route = StackRoute(
      id: pageKey.value,
      name: descriptor.name,
      page: page,
      controller: controller,
      params: params,
    );

    /// setup controller's [routeId]
    controller?.routeId = route.id;

    /// setup controller's title
    controller?.title = descriptor.title ?? descriptor.name;

    /// setup params
    controller?.params = params;

    /// invoke controller's [onBeforeInitialized]
    controller?.onBeforeInit.call();

    return route;
  }

  Future<bool> handlePopRoute() {
    // true则有delegate内部处理路由栈
    // false则由系统来Handle、默认行为: 退出应用
    if (routes.length > 1) {
      back();
      return SynchronousFuture(true);
    }
    return SynchronousFuture(false);
  }

  /// route manage apis

  /// [go]
  /// * T : result type
  Future<StackRouteNavigationResult?> go<T>(String name, {dynamic params, bool forResult = false}) async {
    final index = _descriptors.indexWhere((e) => e.name == name);
    if (index == -1) {
      _log('No Page Descriptor Matched :$name, Navigation Action Ignored');
      return null;
    }
    final curRoute = _routes.last;

    if (forResult) {
      curRoute.completer = Completer<dynamic>();
    }

    /// notify current route that its gonna lose focus
    curRoute.controller?.onFocused.call(false);

    final tarRoute = _buildRoute(
      _descriptors[index],
      params: params,
      forResult: forResult,
    );

    /// emit global navigation event [GBOnStackRouteWillChange]
    GBOnStackRouteWillChange(
      data: GBOnStackRouteWillChangeData(
        routeId: curRoute.id,
        routeName: curRoute.name,
        targetRouteId: tarRoute.id,
        targetRouteName: tarRoute.name,
        type: StackRouteChangeType.push,
        isInitialRoute: false,
      ),
    ).emit();

    if (_index == 0) {
      /// emit global navigation event [GBOnStackRouteIsInitial]
      GBOnStackRouteIsInitial(data: false).emit();
    }

    _routes.add(tarRoute);

    /// request rebuild navigator
    notifyListeners();

    /// after [notifyListeners], the navigator will be rebuild
    /// if navigation result required、wait for result
    ///
    if (forResult) {
      final result = await curRoute.completer!.future;
      if (result is StackRoutePoppedUnexpectedlyException) {
        return StackRouteNavigationResult(isCanceled: true);
      }
      if (result is T) {
        return StackRouteNavigationResult<T>(result: result);
      } else {
        return StackRouteNavigationResult(result: result);
      }
    }
    return null;
  }

  backToInitial({dynamic result}) async {
    await back(toInitial: true, result: result);
  }

  back({String? name, dynamic result, int step = 1, bool toInitial = false}) async {
    /// no route to pop
    if (_routes.isEmpty || _routes.length == 1) {
      _log('No Route To Pop, Navigation Back Action Ignored');
      return;
    }
    int popCount = 0;
    int maxPopCount = _routes.length - 1;

    /// if name is provided, pop to the page with the given name
    if (name != null) {
      int index = _routes.indexWhere((e) => e.name == name);
      if (index == -1) {
        return _log('No Page Matched :$name, Navigation Back Action Ignored');
      }

      /// eg: A -> B -> C
      /// pop to A
      /// _index = 2、 index = 0 and the popCount is 2
      popCount = _index - index;
    } else {
      /// pop count of step
      popCount = min(step, maxPopCount);
    }
    if (toInitial) {
      popCount = maxPopCount;
    }
    if (popCount == 0) {
      return;
    }

    final curRouteId = _routes.last.id;
    final curRouteName = _routes.last.name;

    /// pop routes
    for (int i = popCount; i > 0; i--) {
      final route = _routes.removeLast();
      route.controller?.onWillDispose();

      /// popped multiple routes, only the last route will receive the result
      /// eg: A -> B -> C
      /// pop to A
      /// B and C will not receive the result、 future.catchError will get the [StackRoutePoppedUnexpectedlyException]
      if (i == 1 && _routes.last.completer != null && _routes.last.completer!.isCompleted == false) {
        /// B : i = 1
        debugPrint('_routes.last[${_routes.last.id}] complete with result: $result');
        _routes.last.completer?.complete(result);
      } else if (i != 1) {
        if (route.completer != null && route.completer!.isCompleted == false) {
          debugPrint('removed route[${route.id}] complete with cancel');
          route.completer?.complete(StackRoutePoppedUnexpectedlyException());
        }
      }
    }

    /// emit global navigation event [GBOnStackRouteWillChange] if route did popped
    if (curRouteId != _routes.last.id) {
      GBOnStackRouteWillChange(
        data: GBOnStackRouteWillChangeData(
          routeId: curRouteId,
          routeName: curRouteName,
          targetRouteId: _routes.last.id,
          targetRouteName: _routes.last.name,
          type: toInitial ? StackRouteChangeType.popTop : StackRouteChangeType.pop,
          isInitialRoute: _index == 0,
        ),
      ).emit();

      if (_index == 0) {
        /// emit global navigation event [GBOnStackRouteIsInitial]
        GBOnStackRouteIsInitial(data: true).emit();
      }
    }

    /// request rebuild navigator
    notifyListeners();

    /// notify last route that it's focused
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _routes.last.controller?.onFocused.call(true);
    });
  }

  /// [Overlay Part]
  ///
  /// use [_navigator.currentState?.overlay] as overlay container
  insert(
    OverlayEntry entry, {
    OverlayEntry? above,
    OverlayEntry? below,
  }) {
    _overlay?.insert(entry, above: above, below: below);
  }
}

class StackRoutePoppedUnexpectedlyException {
  final String message = 'Route Popped Unexpectedly';
}

class StackRouteNavigationResult<T> {
  final T? result;
  final bool isCanceled;
  StackRouteNavigationResult({this.result, this.isCanceled = false});
}

/// [StackRoute]
/// Referrence to the page which had been built and exsists in route stack
class StackRoute {
  final String id;
  final String name;
  final Page page;
  final NavigationPageController? controller;
  Completer<dynamic>? completer;
  dynamic params;

  bool get forResult => completer != null;

  StackRoute({
    required this.id,
    required this.page,
    required this.name,
    this.completer,
    this.params,
    this.controller,
  });
}

/// [StackRouterDelegateConfiguration]
/// delegate configuration
/// used to config initial route , custom toast & loading and so on
class StackRouterDelegateConfiguration {
  /// unknown route handler
  final Route? Function(RouteSettings)? onUnknownRoute;

  final String initialRoute;

  StackRouterDelegateConfiguration({
    this.initialRoute = '/',
    this.onUnknownRoute,
  });
}

enum StackPageType {
  /// wrapper widget return by [StackPageDescriptor@builder] with MaterialPage
  material,

  /// wrapper widget return by [StackPageDescriptor@builder] with CupertinoPage
  cupertino,

  /// return [Page] type directly in method [StackPageDescriptor@builder]
  /// only use this if custom page used
  none,
}

/// [StackRouterPage]
class StackPageDescriptor extends NavigationPageDescriptor {
  final StackPageType type;

  StackPageDescriptor({
    required super.name,
    required super.builder,
    super.title,
    super.controller,
    this.type = StackPageType.material,
  });
}

/// [StackPageController]
class StackPageController<P> extends NavigationPageController<P> {}

/// Default Unknwon Page
class _DefaultUnknownPage extends StatelessWidget {
  const _DefaultUnknownPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF3F3F6),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: 20),
            child: Text(
              '404',
              style: TextStyle(
                decoration: TextDecoration.none,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey[800],
              ),
            ),
          ),
          Text(
            'Oops! Something went wrong!',
            style: TextStyle(
              decoration: TextDecoration.none,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey[400],
            ),
          ),
        ],
      ),
    );
  }
}

/// [StackPageState]
/// Once page pushed and navigator rebuilt、 the state will be initialized.
/// Get the built page through [StackPageState.page] and call its [StackPageController.onInitialize]
abstract class StackPageState<W extends StatefulWidget, C extends StackPageController> extends State<W> {
  StackRouterDelegate get delegator {
    final delegator = Injex.take<StackRouterDelegate>();
    assert(delegator != null, 'StackRouterDelegate Not Found,Please Ensure (Navigation) Is Configured Correctly');
    return delegator!;
  }

  C? controller;

  @override
  void initState() {
    super.initState();

    /// get controller and invoke its [onInit] callback
    final route = delegator.routes.last;
    if (route.controller is C && route.controller != null) {
      controller = route.controller as C;
      Injex.put<C>(controller!, keepAlive: true);
      controller!.onInit();
    }
  }

  @override
  void dispose() {
    /// dispose controller
    controller?.onDispose();
    Injex.remove<C>();
    super.dispose();
  }
}
