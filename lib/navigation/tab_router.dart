import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import './base.dart';
import './events.dart';
import '../injex/injex.dart';
import '../broadcast/broadcast.dart';

/// [TabRouter]
/// manage tab pages
///
class TabRouter extends StatefulWidget {
  TabRouter({
    super.key,
    this.initialIndex = 0,
    this.pages = const [],
    this.lazy = false,
    this.tabBuilder,
    this.tabHeight,
  }) {
    assert(pages.isNotEmpty, 'TabRouter requires at least one tab page but got ${pages.length}');
    assert(initialIndex >= 0 && initialIndex < pages.length, 'TabRouter requires initialTab to be between 0 and ${pages.length - 1} but got $initialIndex');
  }

  final int initialIndex;
  final List<TabPageDescriptor> pages;
  final bool lazy;
  final Widget Function(BuildContext context, List<String> tabs, int index)? tabBuilder;
  final double Function(BuildContext context)? tabHeight;

  @override
  State<TabRouter> createState() => TabRouterState();
}

class TabRouterState extends State<TabRouter> {
  int curRouteIndex = 0;

  /// route descriptors
  late final List<TabPageDescriptor> _descriptors;

  /// routes
  List<TabPageRoute> _routes = [];

  void _log(String message) {
    debugPrint('【TabRouter】$message');
  }

  /// Called when switching to new tab
  /// Consider using a [SynchronousFuture] if the result can be computed
  /// synchronously.
  Future<int?> setNewIndex(int index) async {
    if (index < 0 || index >= _descriptors.length || curRouteIndex == index) {
      return SynchronousFuture(null);
    }
    int preIndex = curRouteIndex;
    setState(() {
      curRouteIndex = index;
      _routes = _buildTabRoutes(_descriptors);
    });
    _routes[index].controller?.onFocused(true);
    _routes[preIndex].controller?.onFocused(false);
    return index;
  }

  /// Called when switching to new tab
  /// Consider using a [SynchronousFuture] if the result can be computed
  /// synchronously.
  Future<int?> setNewRoute(String routeName, {String? routeId}) async {
    int i = -1;
    if (routeId != null) {
      i = _routes.indexWhere((e) => e.id == routeId);
    } else {
      i = _routes.indexWhere((e) => e.name == routeName);
    }
    if (i == -1) {
      _log('No tab matched routeName[$routeName] ${routeId != null ? 'or routeId[$routeId]' : ''} , setNewRoute ignored');
      return SynchronousFuture(null);
    }
    await setNewIndex(i);
    return SynchronousFuture(i);
  }

  /// Build tab routes with given pages
  /// If page with the same name already exists, reuse instead of creating new
  _buildTabRoutes(List<TabPageDescriptor> pages) {
    final List<TabPageRoute> newRoutes = [];
    final hasDuplicates = pages.map((e) => e.name).toSet().length != pages.length;
    assert(hasDuplicates == false, 'TabRouter requires each page in the list to be unique [name]');

    for (var index = 0; index < pages.length; index++) {
      final TabPageDescriptor page = pages[index];
      int i = _routes.indexWhere((e) => e.name == page.name);
      if (i != -1) {
        newRoutes.add(_routes[i]);
      } else {
        final String key = page.name;
        final String routeId = 'tab:route@$key';
        final String routeChildId = 'tab:child@$key';
        final controller = page.controller?.call();

        assert(controller is TabPageController, 'TabRouter requires controller to be an instance of TabPageController, but got ${controller.runtimeType}');

        /// set route id
        controller?.routeId = routeId;

        /// call controller's [onBeforeInit]
        controller?.onBeforeInit.call();

        /// set index
        (controller as TabPageController?)?.index = index;

        final TabPageRoute route = TabPageRoute(
          id: routeId,
          name: page.name,
          controller: controller as TabPageController,
          builder: () => page.builder.call(ValueKey(routeChildId)),
        );
        newRoutes.add(route);
        Injex.put(controller, tag: route.name);
      }
    }
    return newRoutes;
  }

  BroadcastSubscription? _onStackRouteBackToInitialSubscription;
  @override
  void initState() {
    super.initState();
    curRouteIndex = widget.initialIndex;
    _descriptors = widget.pages;
    _routes = _buildTabRoutes(_descriptors);
    _onStackRouteBackToInitialSubscription = Broadcast.addEventListener<GBOnStackRouteIsInitial>((e) {
      if (curRouteIndex < _routes.length) {
        _routes[curRouteIndex].controller?.onFocused(e.data!);
      }
    });
  }

  @override
  void dispose() {
    _onStackRouteBackToInitialSubscription?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<LazyBuildableTabRoute> children = [];
    for (var i = 0; i < _routes.length; i++) {
      final route = _routes[i];
      children.add(LazyBuildableTabRoute(
        key: ValueKey(route.id),
        isActive: widget.lazy ? curRouteIndex == i : true,
        controller: route.controller,
        builder: () => route.builder(),
      ));
    }
    final tabHeight = widget.tabHeight?.call(context) ?? 0.0;
    final tabWidget = widget.tabBuilder?.call(context, _routes.map((e) => e.name).toList(), curRouteIndex) ?? const SizedBox.shrink();
    return Stack(
      fit: StackFit.expand,
      children: [
        SizedBox.expand(
          child: Padding(
            padding: EdgeInsets.only(bottom: tabHeight),
            child: IndexedStack(
              index: curRouteIndex,
              children: children,
            ),
          ),
        ),
        Positioned(bottom: 0, left: 0, right: 0, child: tabWidget),
      ],
    );
  }
}

class LazyBuildableTabRoute extends StatefulWidget {
  const LazyBuildableTabRoute({super.key, required this.builder, required this.isActive, this.controller});
  final Widget Function() builder;
  final bool isActive;
  final TabPageController? controller;

  @override
  State<LazyBuildableTabRoute> createState() => _LazyBuildableTabRouteState();
}

class _LazyBuildableTabRouteState extends State<LazyBuildableTabRoute> {
  Widget child = const SizedBox.shrink();

  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      child = widget.builder();
      debugPrint('lazy builder : ${widget.key.toString()} is active, build child and invoke controllers onInit');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.controller?.onInit.call();
      });
    }
  }

  @override
  void didUpdateWidget(covariant LazyBuildableTabRoute oldWidget) {
    if (widget.isActive && child is SizedBox) {
      setState(() {
        child = widget.builder();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.controller?.onInit.call();
      });
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

/// [TabPageRoute]
/// Referrence to the page which had been built and exsists in route stack
class TabPageRoute {
  final String id;
  final String name;
  final TabPageController? controller;
  final Widget Function() builder;

  TabPageRoute({
    required this.id,
    required this.name,
    required this.builder,
    this.controller,
  });
}

class TabPageDescriptor extends NavigationPageDescriptor {
  TabPageDescriptor({
    required super.name,
    required super.builder,
    super.controller,
    super.title,
  });
}

class TabPageController extends NavigationPageController {
  int index = -1;
}
