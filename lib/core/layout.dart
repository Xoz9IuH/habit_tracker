import 'package:flutter/material.dart';

class Layout {
  Layout._();

  static const double compactMax = 599;
  static const double mediumMax = 1199;
  static const double wideMax = 1599;
  static const double maxContentWidth = 1440;
  static const double formMaxWidth = 460;
  static const double dialogMaxWidth = 560;

  static double of(BuildContext context) => MediaQuery.widthOf(context);

  static String breakpointOf(BuildContext context) {
    final width = of(context);
    if (width <= compactMax) return 'compact';
    if (width <= mediumMax) return 'medium';
    if (width <= wideMax) return 'wide';
    return 'large';
  }

  static bool isCompact(BuildContext context) {
    final width = of(context);
    return width <= compactMax;
  }

  static bool isMedium(BuildContext context) {
    final width = of(context);
    return width > compactMax && width <= mediumMax;
  }

  static bool isWide(BuildContext context) {
    final width = of(context);
    return width > mediumMax;
  }

  static int columns(
    BuildContext context, {
    int compact = 1,
    int medium = 2,
    int wide = 3,
  }) {
    if (isCompact(context)) return compact;
    if (isMedium(context)) return medium;
    return wide;
  }

  static EdgeInsets page(BuildContext context) {
    if (isCompact(context)) return const EdgeInsets.all(12);
    return const EdgeInsets.all(24);
  }
}
