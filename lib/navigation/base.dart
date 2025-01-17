import 'package:flutter/widgets.dart';

/// [NavigationPageDescriptor]
/// a navigation page descriptor
/// [name] the named name of the page，multiple pages in stack can have the same name but different keys
/// [builder] the builder of the page，return a widget which will be pushed to the stack
///           in stack router，the widget will be wrapped with [MaterialPage] | [CupertinoPage]
///           or custom page widget(inherit from [Page]). descides by [StackRouterDelegateConfiguration.pageType]
/// [controllerBuilder] the builder of the page controller
/// [title] the title of the page，[name] will be used if title is null

class NavigationPageDescriptor {
  NavigationPageDescriptor({
    required this.name,
    required this.builder,
    this.controller,
    this.title,
  });
  final String name;
  final String? title;
  final Widget Function(Key key) builder;
  final NavigationPageController? Function()? controller;
}

/// [NavigationPageController]
/// a page controller used to manage data of the page and receive events like [onInit] and [onFocused] etc...
///
class NavigationPageController<T> {
  bool mounted = false;

  /// [params]
  /// The params of the page. passed from previous page.
  T? params;

  /// [title]
  /// The title of the page.
  String title = '';

  /// [routeId]
  /// The id of the route which this controller belongs to.
  String routeId = '';

  /// [onBeforeInitialized]
  /// This method will be called when navigating to this page.
  /// Typically used to preload data.
  /// Inside delegate,the controller will be instantiated and call this method immediately.
  /// ! Attension: dont'do any expensive operation in this method to avoid frame drops.
  Future<void> onBeforeInit() async {}

  /// [onInitialize]
  /// This method will be called when this page is initialized. called at [State.initState]
  Future<void> onInit() async {
    mounted = true;
  }

  /// [onWillDispose]
  /// This method will be called when this page is going to be disposed.
  /// * StackRouter
  ///   When [StackRouterDelegate.back] is called, and the page is popped out, this method will be called.
  ///
  /// * TabRouter
  ///   This method will never ever be called
  Future<void> onWillDispose() async {}

  /// [onDispose]
  /// This method will be called when this page is disposed.
  /// * StackRouter
  ///   called at [State.dispose]
  /// * TabRouter
  ///   This method will never ever be called
  Future<void> onDispose() async {
    mounted = false;
  }

  /// [onFocused]
  /// This method will be called when this page is focused or not.
  Future<void> onFocused(bool focused) async {}
}
