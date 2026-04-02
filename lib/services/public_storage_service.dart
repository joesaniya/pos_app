import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:developer' as developer;
import 'package:flutter/services.dart';

/// Service to handle saving files to device's public Downloads folder
/// Works across Android, iOS, and Web platforms with proper fallbacks
class PublicStorageService {
  // Platform channel for Android-specific operations
  static const _androidChannel = MethodChannel('android_intent_channel');

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
  ///
  /// Strategy:
  /// 1. For Android: Try platform channel (MediaStore API - Android 10+)
  /// 2. Fallback: Try direct write to public Downloads
  /// 3. Fallback: App documents directory
  /// 4. Fallback: Temporary directory
  static Future<String?> saveFileToPublicDownloads({
    required String fileName,
    required List<int> fileBytes,
  }) async {
    try {
      // First priority for Android: Use platform channel for MediaStore API (Android 10+)
      if (Platform.isAndroid) {
        try {
          developer.log(
            '📱 Android: Attempting to save via platform channel (MediaStore API)...',
            name: 'PublicStorageService',
          );

          final result = await _androidChannel.invokeMethod<String>(
            'saveFileToPublicDownloads',
            {'fileName': fileName, 'fileBytes': fileBytes},
          );

          if (result != null) {
            developer.log(
              '✅ File saved to public Downloads via MediaStore: $result',
              name: 'PublicStorageService',
            );
            return result;
          }
        } on PlatformException catch (e) {
          developer.log(
            '⚠️ Platform channel error: ${e.code} - ${e.message}',
            name: 'PublicStorageService',
          );
        } catch (e) {
          developer.log(
            '⚠️ Platform channel call failed: $e',
            name: 'PublicStorageService',
          );
        }
      }

      // Second priority: Try public Downloads via getPublicDownloadsDirectory
      try {
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
      } catch (e) {
        developer.log(
          '⚠️ Error getting public downloads directory: $e',
          name: 'PublicStorageService',
        );
      }

      // Fallback 1: App-specific documents directory
      try {
        var targetDir = await getApplicationDocumentsDirectory();
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
      } catch (e) {
        developer.log(
          '⚠️ Error saving to app documents: $e',
          name: 'PublicStorageService',
        );
      }

      // Fallback 2: Temporary directory
      try {
        var targetDir = await getTemporaryDirectory();
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
          '⚠️ Error saving to temporary directory: $e',
          name: 'PublicStorageService',
        );
      }

      developer.log(
        '❌ All attempts to save file failed',
        name: 'PublicStorageService',
      );
      return null;
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

  /// Check if app has permission to access public Downloads folder
  /// For Android 11+, requires MANAGE_EXTERNAL_STORAGE permission
  static Future<bool> hasDownloadsFolderPermission() async {
    try {
      if (Platform.isAndroid) {
        // Try to test if we can write to Downloads
        final result = await _androidChannel.invokeMethod<bool>(
          'hasDownloadsFolderPermission',
        );
        return result ?? false;
      } else if (Platform.isIOS) {
        // iOS doesn't need special permission for app documents
        return true;
      } else {
        // Desktop platforms
        return true;
      }
    } catch (e) {
      developer.log(
        'Error checking Downloads permission: $e',
        name: 'PublicStorageService',
      );
      return false;
    }
  }

  /// Open Android settings to grant MANAGE_EXTERNAL_STORAGE permission
  /// Call this if hasDownloadsFolderPermission() returns false
  static Future<bool> openSettingsForStoragePermission() async {
    try {
      if (Platform.isAndroid) {
        final result = await _androidChannel.invokeMethod<bool>(
          'openStoragePermissionSettings',
        );
        return result ?? false;
      }
    } catch (e) {
      developer.log(
        'Error opening storage settings: $e',
        name: 'PublicStorageService',
      );
    }
    return false;
  }
}
