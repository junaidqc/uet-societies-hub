import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

enum AppButtonType { elevated, outlined, text }

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final AppButtonType type;
  final IconData? icon;
  final Color? color;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.type = AppButtonType.elevated,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (type == AppButtonType.outlined) {
      return OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: color != null
            ? OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color!),
              )
            : null,
        child: _buildChild(context, isOutlined: true),
      );
    }

    if (type == AppButtonType.text) {
      return TextButton(
        onPressed: isLoading ? null : onPressed,
        child: _buildChild(context, isOutlined: true),
      );
    }

    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: color != null
          ? ElevatedButton.styleFrom(backgroundColor: color)
          : null,
      child: _buildChild(context),
    );
  }

  Widget _buildChild(BuildContext context, {bool isOutlined = false}) {
    if (isLoading) {
      return SizedBox(
        height: 22,
        width: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(
            isOutlined
                ? (color ?? AppColors.primary)
                : Colors.white,
          ),
        ),
      );
    }

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(text),
        ],
      );
    }

    return Text(text);
  }
}
