import 'package:flutter/material.dart';
import 'package:fawatir/app/theme.dart';

/// أدوات مساعدة لعرض رسائل التنبيه والنجاح والخطأ بشكل موحّد وأنيق.
class AppSnackBar {
  AppSnackBar._();

  /// عرض رسالة نجاح خضراء مع أيقونة تحقق
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    _show(
      context,
      message: message,
      backgroundColor: const Color(0xFF059669),
      icon: Icons.check_circle_rounded,
      duration: duration,
    );
  }

  /// عرض رسالة خطأ حمراء مع أيقونة تحذير
  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    _show(
      context,
      message: message,
      backgroundColor: const Color(0xFFDC2626),
      icon: Icons.error_rounded,
      duration: duration,
    );
  }

  /// عرض رسالة تنبيه برتقالية مع أيقونة انتباه
  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    _show(
      context,
      message: message,
      backgroundColor: const Color(0xFFD97706),
      icon: Icons.warning_amber_rounded,
      duration: duration,
    );
  }

  /// عرض رسالة معلومات باللون الأساسي للتطبيق
  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    _show(
      context,
      message: message,
      backgroundColor: AppColors.accent,
      icon: Icons.info_rounded,
      duration: duration,
    );
  }

  static void _show(
    BuildContext context, {
    required String message,
    required Color backgroundColor,
    required IconData icon,
    required Duration duration,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: backgroundColor,
        duration: duration,
        content: Directionality(
          textDirection: TextDirection.rtl,
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
