import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fawatir/app/theme.dart';
import 'package:fawatir/features/backup/data/backup_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _showLoading(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
  }

  Future<void> _handleExport(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    _showLoading(context);
    try {
      await ref.read(backupServiceProvider).exportBackup();
      if (context.mounted) Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('تم تصدير النسخة الاحتياطية بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء التصدير: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleImport(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('استيراد نسخة احتياطية'),
        content: const Text(
          'تنبيه: سيؤدي استيراد النسخة الاحتياطية إلى استبدال كافة البيانات الحالية بالكامل. هل أنت متأكد من الاستمرار؟'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('استيراد واستبدال الكل'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!context.mounted) return;

    _showLoading(context);
    try {
      final imported = await ref.read(backupServiceProvider).importBackup();
      if (context.mounted) Navigator.pop(context);

      if (imported && context.mounted) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('تمت الاستعادة بنجاح'),
            content: const Text('تمت الاستعادة بنجاح. الرجاء إغلاق التطبيق وإعادة فتحه.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  exit(0);
                },
                child: const Text('موافق (إغلاق التطبيق)'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء الاستيراد: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الإعدادات'),
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            ListTile(
              leading: const Icon(Icons.business, color: Colors.blueGrey),
              title: const Text('بيانات الشركة'),
              subtitle: const Text('الاسم، الشعار، بيانات البنك والاتصال'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () {
                context.go('/settings/company-setup');
              },
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'النسخ الاحتياطي',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.backup, color: Colors.green),
              title: const Text('تصدير نسخة احتياطية'),
              subtitle: const Text('تصدير قاعدة البيانات الحالية لمشاركتها أو حفظها'),
              onTap: () => _handleExport(context, ref),
            ),
            ListTile(
              leading: const Icon(Icons.restore, color: Colors.orange),
              title: const Text('استيراد نسخة احتياطية'),
              subtitle: const Text('استعادة البيانات من ملف نسخة احتياطية (.sqlite)'),
              onTap: () => _handleImport(context, ref),
            ),
            const Divider(),
          ],
        ),
      ),
    );
  }
}
