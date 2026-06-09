import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../../../data/db/database.dart';

class BackupService {
  final AppDatabase _db;

  BackupService(this._db);

  Future<void> exportBackup() async {
    try {
      final tmpDir = await getTemporaryDirectory();
      final tmp = '${tmpDir.path}/fawatir_backup_${DateTime.now().millisecondsSinceEpoch}.sqlite';
      await _db.customStatement("VACUUM INTO '$tmp'");
      
      await Share.shareXFiles([XFile(tmp)], text: 'نسخة احتياطية لقاعدة بيانات فواتير');
    } catch (e) {
      throw Exception('فشل تصدير النسخة الاحتياطية: $e');
    }
  }

  Future<bool> importBackup() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
      );

      if (result == null || result.files.single.path == null) {
        return false;
      }

      final selectedPath = result.files.single.path!;
      final selectedFile = File(selectedPath);

      // Close database connection
      await _db.close();

      // Copy database file
      final dbFile = await _db.databaseFile();
      if (await dbFile.exists()) {
        await dbFile.delete();
      }
      await selectedFile.copy(dbFile.path);
      return true;
    } catch (e) {
      throw Exception('فشل استيراد النسخة الاحتياطية: $e');
    }
  }
}

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(ref.watch(databaseProvider));
});
