import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:developer' as developer;

/// Service to handle saving files to device's public Downloads folder
/// Works across Android, iOS, and Web platforms with proper fallbacks
class PublicStorageService {
  /// Get the public Downloads directory path
  /// For Android: /storage/emulated/0/Download/
  /// For iOS: Uses app documents directory (iOS doesn't have public Downloads)
  /// Returns null if unable to access
  static Future<Directory?> getPublicDownloadsDirectory() async {
    try {
      if (Platform.isAndroid) {
        return await _getAndroidPublicDownloads();
      } else if (Platform.isIOS) {
        // iOS doesn't have a public Downloads folder - use app documents
        return await getApplicationDocumentsDirectory();
      } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        // Desktop platforms - use system Downloads folder
        return await _getDesktopDownloads();
      }
    } catch (e) {
      developer.log(
        'Error getting public downloads directory: $e',
        name: 'PublicStorageService',
        error: e,
      );
    }
    return null;
  }

  /// Android-specific: Get public Downloads directory
  /// Prioritizes public external storage (/storage/emulated/0/Download/)
  static Future<Directory?> _getAndroidPublicDownloads() async {
    try {
      // Try to use external storage directories API (Android 6.0+)
      final externalDirs = await getExternalStorageDirectories();
      if (externalDirs != null && externalDirs.isNotEmpty) {
        // Get the primary external storage directory
        final primaryDir = externalDirs.first;

        // Navigate to public Downloads folder
        // Pattern: /storage/emulated/0/Android/data/com.example.app/files → /storage/emulated/0/Download
        final downloadPath = primaryDir.path.replaceAll(
          RegExp(r'Android/data/.*?/files$'),
          'Download',
        );

        final downloadDir = Directory(downloadPath);

        developer.log(
          '✅ Android public Downloads path: $downloadPath',
          name: 'PublicStorageService',
        );

        return downloadDir;
      }

      // Fallback: Try to construct Downloads path manually for Android 5.0+
      // Standard public external storage path
      final sdCardPath = '/storage/emulated/0';
      final downloadDir = Directory('$sdCardPath/Download');

      if (await downloadDir.exists()) {
        developer.log(
          '✅ Android public Downloads path (fallback): ${downloadDir.path}',
          name: 'PublicStorageService',
        );
        return downloadDir;
      }

      developer.log(
        '⚠️ Android public Downloads folder does not exist or cannot be accessed',
        name: 'PublicStorageService',
      );

      return null;
    } catch (e) {
      developer.log(
        'Error getting Android public downloads: $e',
        name: 'PublicStorageService',
        error: e,
      );
      return null;
    }
  }

  /// Desktop platforms: Get system Downloads directory
  static Future<Directory?> _getDesktopDownloads() async {
    try {
      if (Platform.isWindows) {
        // Windows: %USERPROFILE%\Downloads
        final userHome = Platform.environment['USERPROFILE'];
        if (userHome != null) {
          final downloadDir = Directory('$userHome\\Downloads');
          if (await downloadDir.exists()) {
            return downloadDir;
          }
        }
      } else if (Platform.isLinux) {
        // Linux: ~/Downloads
        final userHome = Platform.environment['HOME'];
        if (userHome != null) {
          final downloadDir = Directory('$userHome/Downloads');
          if (await downloadDir.exists()) {
            return downloadDir;
          }
        }
      } else if (Platform.isMacOS) {
        // macOS: ~/Downloads
        final userHome = Platform.environment['HOME'];
        if (userHome != null) {
          final downloadDir = Directory('$userHome/Downloads');
          if (await downloadDir.exists()) {
            return downloadDir;
          }
        }
      }
    } catch (e) {
      developer.log(
        'Error getting desktop downloads: $e',
        name: 'PublicStorageService',
        error: e,
      );
    }
    return null;
  }

  /// Save file to public Downloads directory with fallback chain
  /// Returns the full file path if successful, null otherwise
  static Future<String?> saveFileToPublicDownloads({
    required String fileName,
    required List<int> fileBytes,
  }) async {
    try {
      // First priority: Public Downloads folder
      var targetDir = await getPublicDownloadsDirectory();

      if (targetDir != null) {
        try {
          // Ensure directory exists
          if (!await targetDir.exists()) {
            await targetDir.create(recursive: true);
          }

          final filePath = '${targetDir.path}/$fileName';
          final file = File(filePath);

          await file.writeAsBytes(fileBytes);

          developer.log(
            '✅ File saved to public Downloads: $filePath',
            name: 'PublicStorageService',
          );

          return filePath;
        } catch (e) {
          developer.log(
            '⚠️ Could not save to public Downloads, trying fallback: $e',
            name: 'PublicStorageService',
          );
        }
      }

      // Fallback 1: App-specific documents directory
      targetDir = await getApplicationDocumentsDirectory();
      if (targetDir != null) {
        final filePath = '${targetDir.path}/$fileName';
        final file = File(filePath);

        await file.writeAsBytes(fileBytes);

        developer.log(
          '⚠️ File saved to app documents directory (fallback 1): $filePath',
          name: 'PublicStorageService',
        );

        return filePath;
      }

      // Fallback 2: Temporary directory
      targetDir = await getTemporaryDirectory();
      final filePath = '${targetDir.path}/$fileName';
      final file = File(filePath);

      await file.writeAsBytes(fileBytes);

      developer.log(
        '⚠️ File saved to temporary directory (fallback 2): $filePath',
        name: 'PublicStorageService',
      );

      return filePath;
    } catch (e) {
      developer.log(
        '❌ All attempts to save file failed: $e',
        name: 'PublicStorageService',
        error: e,
      );
      return null;
    }
  }

  /// Check if the file path is in public Downloads folder
  static bool isPublicDownloadsPath(String filePath) {
    return filePath.contains('/Download/') ||
        filePath.contains('\\Downloads\\') ||
        filePath.toLowerCase().contains('downloads');
  }

  /// Get user-friendly location description
  static String getLocationDescription(String filePath) {
    if (isPublicDownloadsPath(filePath)) {
      return '📥 Downloads Folder';
    } else if (filePath.contains('Documents') ||
        filePath.contains('documents')) {
      return '📁 App Documents';
    } else if (filePath.contains('temp') || filePath.contains('Temp')) {
      return '🔄 Temporary Folder';
    }
    return '📂 App Storage';
  }
}
