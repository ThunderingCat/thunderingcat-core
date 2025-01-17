import '../broadcast/broadcast.dart';

/// [Global Navigation Events]
///
///
/// [GBOnStackRouteChanged] - stack route changed
///
enum StackRouteChangeType {
  push,
  pop,
  popTop,
}

class GBOnStackRouteWillChangeData {
  final String routeId;
  final String routeName;
  final StackRouteChangeType type;
  final String targetRouteId;
  final String targetRouteName;
  final bool isInitialRoute;

  GBOnStackRouteWillChangeData({
    required this.routeId,
    required this.routeName,
    required this.targetRouteId,
    required this.targetRouteName,
    required this.type,
    this.isInitialRoute = false,
  });
}

/// [GBOnStackRouteWillChange]
/// Routes' gonna change
class GBOnStackRouteWillChange extends GlobalBroadcastEventInterface<GBOnStackRouteWillChangeData> {
  GBOnStackRouteWillChange({super.data});
}

/// [GBOnStackRouteIsInitial]
/// Routes popped until initial route
class GBOnStackRouteIsInitial extends GlobalBroadcastEventInterface<bool> {
  GBOnStackRouteIsInitial({super.data});
}
