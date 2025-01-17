import 'dart:math';

import '../injex/injex.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// [ResponsiveRatioSizeProvider]
///
/// === Major iPhone Screen Sizes
/// Name              Logical Size    	Physical Size
/// iPhone 8          375 × 667         750 × 1334
/// iPhone 12/13/14   390 × 844         1170 × 2532
/// iPhone 16	        393 × 852         1170 × 2556
/// iPhone 16 Plus    430 × 932         1290 × 2796
/// iPhone 16 Pro   	402 × 874       	1206 × 2622
/// iPhone 16 Pro Max	440 × 956	        1320 × 2868
///
/// update: 2025-01-17
///
/// use [390 x 844] as default design size
///

class ResponsiveRatioSizeProvider extends StatefulWidget {
  static const Size defaultDesignSize = Size(390, 844);

  const ResponsiveRatioSizeProvider({
    super.key,
    this.design = defaultDesignSize,
    this.usePortraitInitialLayout = false,
    this.disabled = false,
    required this.child,
  });

  /// design size of app [default: 390 x 844]
  final Size design;

  /// traited device's orientation as Portrait when initialize
  final bool usePortraitInitialLayout;

  /// don't provide responsive size
  final bool disabled;

  final Widget child;

  @override
  State<ResponsiveRatioSizeProvider> createState() => _ResponsiveRatioSizeProviderState();
}

class _ResponsiveRatioSizeProviderState extends State<ResponsiveRatioSizeProvider> {
  late ResponsiveRatioSize responsiveRatioSize;

  @override
  void initState() {
    super.initState();
    responsiveRatioSize = ResponsiveRatioSize(Size.zero, widget.design);
    Injex.put<ResponsiveRatioSize>(responsiveRatioSize);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      debugPrint('【ResponsiveRatioSizeProvider】screen size is: ${constraints.maxWidth} x ${constraints.maxHeight}');

      /// setup actual size of device
      responsiveRatioSize.actual = constraints.biggest;

      /// disable? responsive size
      responsiveRatioSize.disabled = widget.disabled;

      if (widget.usePortraitInitialLayout) {
        responsiveRatioSize.actual = Size(
          min(responsiveRatioSize.actual.width, responsiveRatioSize.actual.height),
          max(responsiveRatioSize.actual.width, responsiveRatioSize.actual.height),
        );
      }

      return widget.child;
    });
  }
}

class ResponsiveRatioSize {
  Size actual;
  Size design;

  bool disabled = false;

  static ResponsiveRatioSize get shared => Injex.get<ResponsiveRatioSize>(factory: () => ResponsiveRatioSize.zero())!;

  ResponsiveRatioSize(this.actual, this.design);

  ResponsiveRatioSize.zero() : this(Size.zero, Size.zero);

  w(num n) {
    if (disabled) return n;
    return n * (actual.width / design.width);
  }

  h(num n) {
    if (disabled) return n;
    return n * (actual.height / design.height);
  }

  sw(num n) {
    return clampDouble(n.toDouble(), 0, 1) * actual.width;
  }

  sh(num n) {
    return clampDouble(n.toDouble(), 0, 1) * actual.height;
  }
}

extension ResponsiveRatioSizeExtension on num {
  double get w => ResponsiveRatioSize.shared.w(this);
  double get h => ResponsiveRatioSize.shared.h(this);
  double get sw => ResponsiveRatioSize.shared.sw(this);
  double get sh => ResponsiveRatioSize.shared.sh(this);
}
