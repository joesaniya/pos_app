import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:pos_app/utils/upi_validator.dart';

class QrCodeProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  bool _isUploading = false;
  bool get isUploading => _isUploading;

  bool _isFetching = false;
  bool get isFetching => _isFetching;

  String _qrCodeUrl = '';
  String get qrCodeUrl => _qrCodeUrl;
  bool get hasQrCode => _qrCodeUrl.isNotEmpty;

  /// UPI ID storage and validation
  String _upiId = '';
  String get upiId => _upiId;
  bool get hasUpiId => _upiId.isNotEmpty;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  double _uploadProgress = 0.0;
  double get uploadProgress => _uploadProgress;

  Future<void> fetchQrUrl(String businessId) async {
    _isFetching = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final docSnapshot = await _firestore
          .collection('businesses')
          .doc(businessId)
          .get();
      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        _qrCodeUrl = data?['qrCodeUrl'] as String? ?? '';
        _upiId = data?['upiId'] as String? ?? '';
      } else {
        _qrCodeUrl = '';
        _upiId = '';
      }
    } catch (e) {
      _errorMessage = 'Failed to fetch QR Code URL: $e';
    } finally {
      _isFetching = false;
      notifyListeners();
    }
  }

  static Future<String?> getQrCodeUrl(String businessId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('businesses')
          .doc(businessId)
          .get();
      if (doc.exists) {
        return doc.data()?['qrCodeUrl'] as String?;
      }
    } catch (e) {
      debugPrint('Error getting QR Code URL: $e');
    }
    return null;
  }

  Future<File?> pickQrImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70, // To avoid Out of Memory crashes
      maxWidth: 1080,
    );
    if (picked != null) {
      return File(picked.path);
    }
    return null;
  }

  Future<bool> uploadQrCode({
    required String businessId,
    required File imageFile,
  }) async {
    _isUploading = true;
    _errorMessage = '';
    _uploadProgress = 0.0;
    notifyListeners();

    try {
      final inputImage = InputImage.fromFile(imageFile);
      final barcodeScanner = BarcodeScanner(formats: [BarcodeFormat.qrCode]);
      final barcodes = await barcodeScanner.processImage(inputImage);
      await barcodeScanner.close();

      if (barcodes.isEmpty) {
        _isUploading = false;
        _errorMessage = 'Invalid image: Does not contain a valid QR code.';
        notifyListeners();
        return false;
      }

      final ref = _storage.ref().child('businesses/$businessId/qrCode.jpg');

      final uploadTask = ref.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
        notifyListeners();
      });

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      await _firestore.collection('businesses').doc(businessId).set({
        'qrCodeUrl': downloadUrl,
      }, SetOptions(merge: true));

      _qrCodeUrl = downloadUrl;
      _isUploading = false;
      _uploadProgress = 1.0;
      notifyListeners();
      return true;
    } catch (e) {
      _isUploading = false;
      _errorMessage = 'Failed to upload QR Code: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeQrCode(String businessId) async {
    _isFetching = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final ref = _storage.ref().child('businesses/$businessId/qrCode.jpg');
      await ref.delete();

      await _firestore.collection('businesses').doc(businessId).update({
        'qrCodeUrl': FieldValue.delete(),
      });

      _qrCodeUrl = '';
      _isFetching = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isFetching = false;
      _errorMessage = 'Failed to remove QR Code: $e';
      notifyListeners();
      return false;
    }
  }

  /// Validates UPI ID format using UpiValidator
  bool isValidUpiId(String upi) {
    return UpiValidator.isValidUpiId(upi);
  }

  /// Returns error message for invalid UPI ID
  String getUpiErrorMessage(String upi) {
    return UpiValidator.getUpiErrorMessage(upi);
  }

  /// Saves UPI ID to Firebase
  Future<bool> saveUpiId({
    required String businessId,
    required String upiId,
  }) async {
    _isFetching = true;
    _errorMessage = '';
    notifyListeners();

    try {
      // Validate UPI ID format
      if (!isValidUpiId(upiId)) {
        _isFetching = false;
        _errorMessage = getUpiErrorMessage(upiId);
        notifyListeners();
        return false;
      }

      // Format and save
      final formattedUpiId = UpiValidator.formatUpiId(upiId);

      await _firestore.collection('businesses').doc(businessId).set({
        'upiId': formattedUpiId,
        'upiIdUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _upiId = formattedUpiId;
      _isFetching = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isFetching = false;
      _errorMessage = 'Failed to save UPI ID: $e';
      notifyListeners();
      return false;
    }
  }

  /// Removes UPI ID from Firebase
  Future<bool> removeUpiId(String businessId) async {
    _isFetching = true;
    _errorMessage = '';
    notifyListeners();

    try {
      await _firestore.collection('businesses').doc(businessId).update({
        'upiId': FieldValue.delete(),
        'upiIdUpdatedAt': FieldValue.serverTimestamp(),
      });

      _upiId = '';
      _isFetching = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isFetching = false;
      _errorMessage = 'Failed to remove UPI ID: $e';
      notifyListeners();
      return false;
    }
  }

  /// Checks if at least one payment option (QR code or UPI ID) is provided
  bool hasAtLeastOnePaymentOption() {
    return hasQrCode || hasUpiId;
  }

  /// Gets validation error if no payment option is selected
  String getPaymentOptionError() {
    if (!hasQrCode && !hasUpiId) {
      return 'Please provide at least one payment option (QR code or UPI ID)';
    }
    return '';
  }
}
