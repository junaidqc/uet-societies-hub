import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class PullToRefreshWrapper extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final Widget child;

  const PullToRefreshWrapper({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.primary,
      backgroundColor: Theme.of(context).cardColor,
      strokeWidth: 2.5,
      child: child,
    );
  }
}
