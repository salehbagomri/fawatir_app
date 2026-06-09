import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:restart_app/restart_app.dart';
import 'package:fawatir/app/theme.dart';
import 'package:fawatir/features/backup/data/backup_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isGoogleSignedIn = false;
  String? _googleUserEmail;
  DateTime? _lastBackupTime;
  bool _isDriveLoading = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkGoogleStatus();
  }

  void _setLoading(bool value) {
    if (mounted) {
      setState(() {
        _isLoading = value;
      });
    }
  }

  Future<void> _checkGoogleStatus({bool showLocalLoading = true}) async {
    if (!mounted) return;
    if (showLocalLoading) {
      setState(() {
        _isDriveLoading = true;
      });
    }
    try {
      final backupService = ref.read(backupServiceProvider);
      final signedIn = await backupService.isSignedIn();
      if (signedIn) {
        final account = await backupService.currentUser;
        _isGoogleSignedIn = true;
        _googleUserEmail = account?.email;
        _lastBackupTime = await backupService.getLastBackupTime();
      } else {
        _isGoogleSignedIn = false;
        _googleUserEmail = null;
        _lastBackupTime = null;
      }
    } catch (e) {
      // Handle network failure or other errors silently as requested
    } finally {
      if (mounted && showLocalLoading) {
        setState(() {
          _isDriveLoading = false;
        });
      }
    }
  }

  Future<void> _handleExport() async {
    final messenger = ScaffoldMessenger.of(context);
    _setLoading(true);
    try {
      await ref.read(backupServiceProvider).exportBackup();
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('تم تصدير النسخة الاحتياطية بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء التصدير: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _handleImport() async {
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
    if (!mounted) return;

    _setLoading(true);
    try {
      final imported = await ref.read(backupServiceProvider).importBackup();
      if (!mounted) return;

      if (imported) {
        _setLoading(false);
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('✅ تمت الاستعادة بنجاح'),
            content: Text(
              kDebugMode
                  ? 'تم استيراد النسخة الاحتياطية بنجاح.\n\nبما أن التطبيق يعمل في وضع التطوير (Debug Mode)، يرجى إغلاقه والتشغيل يدوياً.\n(في وضع التشغيل النهائي Release Mode، سيعاد تشغيل التطبيق تلقائياً).'
                  : 'تم استيراد النسخة الاحتياطية بنجاح. سيتم إعادة تشغيل التطبيق تلقائياً لتطبيق التغييرات.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await Restart.restartApp();
                },
                child: const Text('موافق'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء الاستيراد: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    _setLoading(true);
    try {
      final backupService = ref.read(backupServiceProvider);
      final account = await backupService.signIn();
      if (!mounted) return;
      if (account != null) {
        await _checkGoogleStatus(showLocalLoading: false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم تسجيل الدخول بنجاح: ${account.email}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل تسجيل الدخول: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _handleGoogleSignOut() async {
    _setLoading(true);
    try {
      final backupService = ref.read(backupServiceProvider);
      await backupService.signOut();
      if (!mounted) return;
      await _checkGoogleStatus(showLocalLoading: false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تسجيل الخروج بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل تسجيل الخروج: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _handleGoogleBackup() async {
    _setLoading(true);
    try {
      final backupService = ref.read(backupServiceProvider);
      await backupService.backupToDrive();
      if (!mounted) return;
      await _checkGoogleStatus(showLocalLoading: false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم رفع النسخة الاحتياطية إلى Google Drive بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _handleGoogleRestore() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('استعادة من Google Drive'),
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
    if (!mounted) return;

    _setLoading(true);

    // Phase 1: Download backup to temp file (DB stays OPEN — UI still works)
    String? tempPath;
    try {
      final backupService = ref.read(backupServiceProvider);
      tempPath = await backupService.downloadBackupToTemp();
    } catch (e) {
      if (!mounted) return;
      _setLoading(false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!mounted) return;
    _setLoading(false);

    // Phase 2: DB is still open here — show success dialog safely
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('✅ تمت الاستعادة بنجاح'),
        content: Text(
          kDebugMode
              ? 'تم تحميل واستعادة النسخة الاحتياطية بنجاح.\n\nبما أن التطبيق يعمل في وضع التطوير (Debug Mode)، يرجى إغلاقه والتشغيل يدوياً.\n(في وضع التشغيل النهائي Release Mode، سيعاد تشغيل التطبيق تلقائياً).'
              : 'تم تحميل واستعادة النسخة الاحتياطية بنجاح. سيتم إعادة تشغيل التطبيق تلقائياً لتطبيق التغييرات.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // Phase 3: Apply backup (closes DB) then restart app automatically
              final backupService = ref.read(backupServiceProvider);
              await backupService.applyRestoredBackup(tempPath!);
              await Restart.restartApp();
            },
            child: const Text('موافق'),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    final localDate = date.toLocal();
    final year = localDate.year;
    final month = localDate.month.toString().padLeft(2, '0');
    final day = localDate.day.toString().padLeft(2, '0');
    final hour = localDate.hour.toString().padLeft(2, '0');
    final minute = localDate.minute.toString().padLeft(2, '0');
    return '$year/$month/$day $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الإعدادات'),
        ),
        body: Stack(
          children: [
            ListView(
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
                
                // Backup Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'النسخ الاحتياطي اليدوي (أوفلاين)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.accent,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.file_upload, color: Colors.blue),
                  title: const Text('تصدير نسخة احتياطية'),
                  subtitle: const Text('حفظ نسخة احتياطية من البيانات على جهازك'),
                  onTap: _handleExport,
                ),
                ListTile(
                  leading: const Icon(Icons.file_download, color: Colors.orange),
                  title: const Text('استيراد نسخة احتياطية'),
                  subtitle: const Text('استعادة البيانات من ملف نسخة احتياطية محفوظ'),
                  onTap: _handleImport,
                ),
                const Divider(),

                // Cloud Backup Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'النسخ الاحتياطي السحابي (Google Drive)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.accent,
                    ),
                  ),
                ),
                if (_isDriveLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else ...[
                  if (!_isGoogleSignedIn)
                    ListTile(
                      leading: const Icon(Icons.cloud_queue, color: Colors.grey),
                      title: const Text('ربط حساب Google Drive'),
                      subtitle: const Text('تسجيل الدخول لتفعيل النسخ الاحتياطي السحابي'),
                      trailing: const Icon(Icons.login),
                      onTap: _handleGoogleSignIn,
                    )
                  else ...[
                    ListTile(
                      leading: const Icon(Icons.account_circle, color: Colors.blue),
                      title: Text(_googleUserEmail ?? 'حساب غير معروف'),
                      subtitle: Text(
                        _lastBackupTime != null
                            ? 'آخر نسخة احتياطية: ${_formatDateTime(_lastBackupTime!)}'
                            : 'لا توجد نسخة احتياطية سابقة',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.logout, color: Colors.red),
                        tooltip: 'تسجيل الخروج',
                        onPressed: _handleGoogleSignOut,
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.cloud_upload, color: Colors.green),
                      title: const Text('نسخ احتياطي الآن'),
                      subtitle: const Text('رفع النسخة الحالية إلى Google Drive'),
                      onTap: _handleGoogleBackup,
                    ),
                    ListTile(
                      leading: const Icon(Icons.cloud_download, color: Colors.orange),
                      title: const Text('استعادة من Google Drive'),
                      subtitle: const Text('تنزيل واستعادة آخر نسخة احتياطية من السحاب'),
                      onTap: _handleGoogleRestore,
                    ),
                  ],
                ],
                const Divider(),
              ],
            ),
            if (_isLoading)
              Container(
                color: const Color(0x59000000),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
