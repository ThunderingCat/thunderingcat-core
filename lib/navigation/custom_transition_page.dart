import 'package:flutter/widgets.dart';

class CustomTransitionPage<T> extends Page<T> {
  const CustomTransitionPage({
    required this.child,
    required this.transitionBuilder,
    this.maintainState = true,
    this.fullscreenDialog = false,
    this.opaque = true,
    this.barrierDismissible = false,
    this.barrierColor,
    this.barrierLabel,
    this.transitionDuration = const Duration(milliseconds: 260),
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
  });

  final Widget child;

  final bool maintainState;
  final bool fullscreenDialog;
  final bool opaque;
  final bool barrierDismissible;
  final Duration transitionDuration;
  final Color? barrierColor;
  final String? barrierLabel;
  final Widget Function(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) transitionBuilder;

  @override
  Route<T> createRoute(BuildContext context) {
    return CustomTransitionPageRoute(this);
  }
}

class CustomTransitionPageRoute<T> extends PageRoute<T> {
  CustomTransitionPageRoute(CustomTransitionPage<T> page) : super(settings: page);

  CustomTransitionPage<T> get _page => settings as CustomTransitionPage<T>;

  @override
  Color? get barrierColor => _page.barrierColor;

  @override
  String? get barrierLabel => _page.barrierLabel;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return _page.transitionBuilder(context, animation, secondaryAnimation, _page.child);
  }

  @override
  bool get maintainState => _page.maintainState;

  @override
  Duration get transitionDuration => _page.transitionDuration;
}
