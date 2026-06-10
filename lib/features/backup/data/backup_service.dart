import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import '../../../data/db/database.dart';

/// معرّف عميل الويب (Web Client ID) الخاص بك من Google Cloud Console.
/// مطلوب على نظام Android لتفعيل النسخ الاحتياطي السحابي عبر Google Drive.
const String googleDriveServerClientId =
    '678878516062-mgng9f7acotlnk4hlvid42ol4p2iiklc.apps.googleusercontent.com';

class BackupService {
  final AppDatabase _db;
  bool _isInitialized = false;
  GoogleSignInAccount? _currentUser;

  BackupService(this._db);

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await GoogleSignIn.instance.initialize(
        serverClientId: googleDriveServerClientId,
      );
      _isInitialized = true;
    }
  }

  Future<GoogleSignInAccount?> getCurrentUser() async {
    await _ensureInitialized();
    if (_currentUser != null) {
      return _currentUser;
    }
    try {
      debugPrint("[GOOGLE SIGN IN] Attempting lightweight authentication...");
      final future = GoogleSignIn.instance.attemptLightweightAuthentication();
      final account = future != null ? await future : null;
      debugPrint("[GOOGLE SIGN IN] Lightweight authentication returned: ${account?.email}");
      _currentUser = account;
      return account;
    } catch (e, stackTrace) {
      debugPrint("[GOOGLE SIGN IN] Error in getCurrentUser: $e");
      debugPrint(stackTrace.toString());
      return null;
    }
  }

  Future<GoogleSignInAccount?> signIn() async {
    await _ensureInitialized();
    try {
      final account = await GoogleSignIn.instance.authenticate();
      final scopes = [drive.DriveApi.driveAppdataScope];
      final authClient = account.authorizationClient;
      await authClient.authorizationForScopes(scopes) ??
          await authClient.authorizeScopes(scopes);
      _currentUser = account;
      return account;
    } catch (e) {
      _currentUser = null;
      throw Exception('فشل تسجيل الدخول: $e');
    }
  }

  Future<void> signOut() async {
    await _ensureInitialized();
    try {
      await GoogleSignIn.instance.signOut();
      _currentUser = null;
    } catch (e) {
      throw Exception('فشل تسجيل الخروج: $e');
    }
  }

  Future<bool> isSignedIn() async {
    final account = await getCurrentUser();
    if (account == null) {
      debugPrint("[GOOGLE SIGN IN] isSignedIn: account is null");
      return false;
    }
    try {
      debugPrint("[GOOGLE SIGN IN] Checking authorization for scope: ${drive.DriveApi.driveAppdataScope}");
      final auth = await account.authorizationClient.authorizationForScopes([
        drive.DriveApi.driveAppdataScope,
      ]);
      debugPrint("[GOOGLE SIGN IN] Authorization is: ${auth != null ? 'AUTHORIZED' : 'NOT AUTHORIZED'}");
      return auth != null;
    } catch (e, stackTrace) {
      debugPrint("[GOOGLE SIGN IN] Error in isSignedIn: $e");
      debugPrint(stackTrace.toString());
      _currentUser = null;
      return false;
    }
  }

  Future<GoogleSignInAccount?> get currentUser async {
    return getCurrentUser();
  }

  Future<drive.DriveApi?> _getDriveApi() async {
    final account = await getCurrentUser();
    if (account == null) return null;

    final scopes = [drive.DriveApi.driveAppdataScope];
    final authClient = account.authorizationClient;

    try {
      final auth =
          await authClient.authorizationForScopes(scopes) ??
          await authClient.authorizeScopes(scopes);

      final client = auth.authClient(scopes: scopes);
      return drive.DriveApi(client);
    } catch (e) {
      _currentUser = null;
      rethrow;
    }
  }

  // ─── النسخ الاحتياطي المحلي ────────────────────────────────────────────────

  Future<void> exportBackup() async {
    try {
      final tmpDir = await getTemporaryDirectory();
      final tmp =
          '${tmpDir.path}/fawatir_backup_${DateTime.now().millisecondsSinceEpoch}.sqlite';
      await _db.customStatement("VACUUM INTO '$tmp'");
      await Share.shareXFiles(
        [XFile(tmp)],
        text: 'نسخة احتياطية لقاعدة بيانات فواتير',
      );
    } catch (e) {
      throw Exception('فشل تصدير النسخة الاحتياطية: $e');
    }
  }

  Future<bool> importBackup() async {
    try {
      final result = await FilePicker.pickFiles(type: FileType.any);
      if (result == null || result.files.single.path == null) return false;

      final selectedFile = File(result.files.single.path!);
      await _db.close();

      final dbFile = await _db.databaseFile();
      if (await dbFile.exists()) await dbFile.delete();
      await selectedFile.copy(dbFile.path);

      return true;
    } catch (e) {
      throw Exception('فشل استيراد النسخة الاحتياطية: $e');
    }
  }

  // ─── النسخ الاحتياطي السحابي ───────────────────────────────────────────────

  Future<DateTime?> getLastBackupTime() async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) return null;

      final list = await driveApi.files.list(
        q: "name = 'fawatir_db.sqlite'",
        spaces: 'appDataFolder',
        $fields: 'files(id, name, modifiedTime)',
      );
      if (list.files != null && list.files!.isNotEmpty) {
        return list.files!.first.modifiedTime;
      }
    } catch (e) {
      // Quietly return null on network failure/errors
    }
    return null;
  }

  Future<void> backupToDrive() async {
    try {
      final driveApi = await _getDriveApi().timeout(const Duration(seconds: 30));
      if (driveApi == null) {
        throw Exception('الرجاء تسجيل الدخول أولاً');
      }

      final localFile = await _db.databaseFile();
      if (!await localFile.exists()) {
        throw Exception('ملف قاعدة البيانات غير موجود محلياً');
      }

      final media = drive.Media(localFile.openRead(), await localFile.length());

      final list = await driveApi.files.list(
        q: "name = 'fawatir_db.sqlite'",
        spaces: 'appDataFolder',
      ).timeout(const Duration(seconds: 30));

      if (list.files != null && list.files!.isNotEmpty) {
        final fileId = list.files!.first.id!;
        await driveApi.files
            .update(drive.File(), fileId, uploadMedia: media)
            .timeout(const Duration(seconds: 45));
      } else {
        final fileToUpload = drive.File()
          ..name = 'fawatir_db.sqlite'
          ..parents = ['appDataFolder'];
        await driveApi.files
            .create(fileToUpload, uploadMedia: media)
            .timeout(const Duration(seconds: 45));
      }
    } catch (e) {
      throw Exception('فشل النسخ الاحتياطي إلى Google Drive: $e');
    }
  }

  Future<String> downloadBackupToTemp() async {
    final driveApi = await _getDriveApi().timeout(const Duration(seconds: 30));
    if (driveApi == null) {
      throw Exception('الرجاء تسجيل الدخول أولاً');
    }

    final list = await driveApi.files.list(
      q: "name = 'fawatir_db.sqlite'",
      spaces: 'appDataFolder',
    ).timeout(const Duration(seconds: 30));

    if (list.files == null || list.files!.isEmpty) {
      throw Exception('لم يتم العثور على نسخة احتياطية في Google Drive');
    }

    final fileId = list.files!.first.id!;

    final drive.Media media =
        await driveApi.files.get(
              fileId,
              downloadOptions: drive.DownloadOptions.fullMedia,
            )
            .timeout(const Duration(seconds: 30))
            as drive.Media;

    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/temp_restore_db.sqlite');
    if (await tempFile.exists()) {
      await tempFile.delete();
    }

    final iosSink = tempFile.openWrite();
    await iosSink
        .addStream(media.stream)
        .timeout(const Duration(seconds: 60));
    await iosSink.close();

    return tempFile.path;
  }

  Future<void> applyRestoredBackup(String tempFilePath) async {
    await _db.close();

    final localFile = await _db.databaseFile();
    final walFile = File('${localFile.path}-wal');
    final shmFile = File('${localFile.path}-shm');
    final tempFile = File(tempFilePath);

    if (await localFile.exists()) await localFile.delete();
    if (await walFile.exists()) await walFile.delete();
    if (await shmFile.exists()) await shmFile.delete();

    await tempFile.copy(localFile.path);

    if (await tempFile.exists()) await tempFile.delete();
  }
}

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(ref.watch(databaseProvider));
});
