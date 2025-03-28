import 'package:flutter/material.dart';
import './stack_router_back_handler.dart';
import './tab_router.dart';
import './stack_router.dart';

class Navigation {
  static GlobalKey<TabRouterState>? _tabRouter;
  static StackRouterDelegate? _stackRouter;

  /// [Navigation Constructors]
  ///

  static RouterConfig<Uri> newRouterConfig({
    required List<StackPageDescriptor> pages,
    StackRouterDelegateConfiguration? config,
  }) {
    config = config ?? StackRouterDelegateConfiguration();
    _stackRouter = StackRouterDelegate(pages: pages, configs: config);
    return RouterConfig(
      routeInformationProvider: StackRouteInformationProvider(initialRoute: config.initialRoute),
      routeInformationParser: StackRouteInformationParser(),
      routerDelegate: _stackRouter!,
      backButtonDispatcher: StackRouterBackButtonDispatcher(_stackRouter!),
    );
  }

  static RouterConfig<Uri> newRouterConfigWithTabNavigator({
    required List<StackPageDescriptor> pages,
    required List<TabPageDescriptor> tabPages,
    required double Function(BuildContext) tabHeight,
    required Widget Function(BuildContext, List<String>, int) tabBuilder,
    bool lazy = false,
    int initialTab = 0,
    String initialRoute = '/',
  }) {
    _tabRouter = GlobalKey<TabRouterState>();
    final tabNavigator = TabRouter(
      key: _tabRouter,
      initialIndex: initialTab,
      pages: tabPages,
      tabBuilder: tabBuilder,
      tabHeight: tabHeight,
      lazy: lazy,
    );

    final routerConfig = Navigation.newRouterConfig(
      pages: [
        StackPageDescriptor(name: '/', builder: (_) => tabNavigator),
        ...pages,
      ],
      config: StackRouterDelegateConfiguration(initialRoute: initialRoute),
    );

    return routerConfig;
  }

  /// [Stack Navigation Actions]
  ///
  static Future<StackRouteNavigationResult?> go<T>(
    String name, {
    dynamic params,
    bool forResult = false,
  }) async {
    return _stackRouter?.go(name, params: params, forResult: forResult);
  }

  static Future<StackRouteNavigationResult?> goForResult<T>(String name, {dynamic params}) async {
    return _stackRouter?.go(name, params: params, forResult: true);
  }

  static Future<void> back({
    String? name,
    dynamic result,
    int step = 1,
  }) async {
    _stackRouter?.back(name: name, result: result, step: step);
  }

  static Future<void> backToInitial({dynamic result, int? tabIndex, String? tabName}) async {
    // pop to initial route in stack
    await _stackRouter?.backToInitial(result: result);

    // optional: pop to specific route in tab
    if (tabName != null || tabIndex != null) {
      int? newTabIndex;
      if (tabName != null) {
        newTabIndex = await _tabRouter?.currentState?.setNewRoute(tabName);
      }
      if (tabIndex != null && newTabIndex == null) {
        newTabIndex = await _tabRouter?.currentState?.setNewIndex(tabIndex);
      }
    }
  }

  /// [Overlay Actions]
  ///
  static void insert(
    OverlayEntry entry, {
    OverlayEntry? above,
    OverlayEntry? below,
  }) {
    _stackRouter?.insert(entry, above: above, below: below);
  }

  /// [Tab Navigation Actions]
  ///
  static Future<int?> setNewTabIndex(int index) async {
    return await _tabRouter?.currentState?.setNewIndex(index);
  }

  static Future<int?> setNewTabRoute(String tab, {String? routeId}) async {
    return await _tabRouter?.currentState?.setNewRoute(tab, routeId: routeId);
  }
}
