import 'package:flutter/material.dart';
import 'package:lbp_ssh/core/theme/app_theme.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerLoading extends StatelessWidget {
  final Widget child;
  final bool isLoading;

  const ShimmerLoading({
    super.key,
    required this.child,
    this.isLoading = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!isLoading) return child;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? LinearColors.surfaceElevated : Colors.grey.shade300,
      highlightColor: isDark ? LinearColors.panel : Colors.grey.shade100,
      child: child,
    );
  }
}
