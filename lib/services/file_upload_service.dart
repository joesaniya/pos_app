import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'dart:developer' as developer;

/// Utility service for handling Excel file uploads with validation
class FileUploadService {
  // Allowed Excel file extensions
  static const List<String> allowedExcelExtensions = ['xlsx', 'xls'];

  // Maximum file size in bytes (50 MB)
  static const int maxFileSizeBytes = 50 * 1024 * 1024;

  /// Picks an Excel file from the device storage
  /// Returns [FilePickerResult] with the selected file or null if cancelled
  static Future<FilePickerResult?> pickExcelFile() async {
    try {
      developer.log(
        '📂 Opening file picker for Excel files',
        name: 'FileUploadService',
      );

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExcelExtensions,
        allowMultiple: false,
        dialogTitle: 'Select Excel File (.xlsx or .xls)',
      );

      if (result != null && result.files.isNotEmpty) {
        developer.log(
          '✅ File selected: ${result.files.single.name}',
          name: 'FileUploadService',
        );
        return result;
      }

      developer.log(
        'ℹ️ No file selected or file picker cancelled',
        name: 'FileUploadService',
      );
      return null;
    } catch (e) {
      developer.log(
        '❌ Error opening file picker: $e',
        name: 'FileUploadService',
        error: e,
      );
      return null;
    }
  }

  /// Validates if a file is a valid Excel file
  /// Checks file extension and size
  /// Returns validation result with error message if invalid
  static FileValidationResult validateExcelFile({required String filePath}) {
    try {
      developer.log(
        '🔍 Validating Excel file: $filePath',
        name: 'FileUploadService',
      );

      final file = File(filePath);

      // Check if file exists
      if (!file.existsSync()) {
        return FileValidationResult(
          isValid: false,
          errorMessage: 'File not found: $filePath',
          errorCode: 'FILE_NOT_FOUND',
        );
      }

      // Check file extension
      final extension = filePath.split('.').last.toLowerCase();
      if (!allowedExcelExtensions.contains(extension)) {
        return FileValidationResult(
          isValid: false,
          errorMessage:
              'Invalid file type. Only .xlsx and .xls files are allowed. Got: .$extension',
          errorCode: 'INVALID_FILE_TYPE',
          suggestedAction:
              'Please save your file as Excel format (.xlsx) and try again',
        );
      }

      // Check file size
      final fileSizeBytes = file.lengthSync();
      if (fileSizeBytes > maxFileSizeBytes) {
        final sizeMB = (fileSizeBytes / (1024 * 1024)).toStringAsFixed(2);
        final maxSizeMB = (maxFileSizeBytes / (1024 * 1024)).toStringAsFixed(2);
        return FileValidationResult(
          isValid: false,
          errorMessage:
              'File is too large ($sizeMB MB). Maximum allowed size is $maxSizeMB MB',
          errorCode: 'FILE_TOO_LARGE',
          suggestedAction:
              'Reduce the number of rows or split into multiple files',
        );
      }

      // Try to read file bytes to ensure it's accessible
      try {
        file.readAsBytesSync();
      } catch (e) {
        return FileValidationResult(
          isValid: false,
          errorMessage: 'Cannot read file. Make sure the file is not locked.',
          errorCode: 'FILE_READ_ERROR',
          errorDetails: e.toString(),
        );
      }

      developer.log(
        '✅ File validation passed: $filePath (${(fileSizeBytes / 1024).toStringAsFixed(2)} KB)',
        name: 'FileUploadService',
      );

      return FileValidationResult(
        isValid: true,
        fileName: filePath.split(Platform.pathSeparator).last,
        fileSizeBytes: fileSizeBytes,
      );
    } catch (e) {
      developer.log(
        '❌ Error validating file: $e',
        name: 'FileUploadService',
        error: e,
      );

      return FileValidationResult(
        isValid: false,
        errorMessage: 'Error validating file: $e',
        errorCode: 'VALIDATION_ERROR',
      );
    }
  }

  /// Copies a file to a temporary location for processing
  /// This helps prevent issues with locked files
  static Future<String?> copyFileToTemp({
    required String sourceFilePath,
    required String tempDirectory,
  }) async {
    try {
      developer.log(
        '📋 Copying file to temp directory: $sourceFilePath',
        name: 'FileUploadService',
      );

      final sourceFile = File(sourceFilePath);
      final fileName = sourceFile.path.split(Platform.pathSeparator).last;
      final tempFilePath = '$tempDirectory${Platform.pathSeparator}$fileName';

      final tempFile = await sourceFile.copy(tempFilePath);

      developer.log(
        '✅ File copied to temp: $tempFilePath',
        name: 'FileUploadService',
      );

      return tempFile.path;
    } catch (e) {
      developer.log(
        '❌ Error copying file to temp: $e',
        name: 'FileUploadService',
        error: e,
      );
      return null;
    }
  }

  /// Gets readable file size string (e.g., "2.5 MB")
  static String getReadableFileSize(int bytes) {
    const List<String> units = ['B', 'KB', 'MB', 'GB'];
    int unitIndex = 0;
    double size = bytes.toDouble();

    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }

    return '${size.toStringAsFixed(2)} ${units[unitIndex]}';
  }
}

/// Result of file validation
class FileValidationResult {
  final bool isValid;
  final String? fileName;
  final int? fileSizeBytes;
  final String? errorMessage;
  final String? errorCode;
  final String? suggestedAction;
  final String? errorDetails;

  FileValidationResult({
    required this.isValid,
    this.fileName,
    this.fileSizeBytes,
    this.errorMessage,
    this.errorCode,
    this.suggestedAction,
    this.errorDetails,
  });

  String get fileSizeDisplay => fileSizeBytes != null
      ? FileUploadService.getReadableFileSize(fileSizeBytes!)
      : '';
}
