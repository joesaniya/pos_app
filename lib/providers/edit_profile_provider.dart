import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:pos_app/providers/profile_provider.dart';
import 'package:pos_app/services/storage_service.dart';

enum EditSaveState { idle, saving, success, error }

class EditProfileProvider extends ChangeNotifier {
  // ── External deps ──────────────────────────────────────────
  final ProfileProvider _profileProv;
  final StorageService _storage = StorageService.instance;
  final _picker = ImagePicker();
  final _firestore = FirebaseFirestore.instance;
  final _fireStorage = FirebaseStorage.instance;

  // ── State ──────────────────────────────────────────────────
  String _name = '';
  File? _pickedImage;
  String _existingPhotoUrl = '';
  bool _nameChanged = false;
  bool _photoChanged = false;
  EditSaveState _saveState = EditSaveState.idle;
  String _errorMessage = '';

  // ── Getters ────────────────────────────────────────────────
  String get name => _name;
  File? get pickedImage => _pickedImage;
  String get existingPhotoUrl => _existingPhotoUrl;
  bool get nameChanged => _nameChanged;
  bool get photoChanged => _photoChanged;
  EditSaveState get saveState => _saveState;
  String get errorMessage => _errorMessage;
  bool get hasChanges => _nameChanged || _photoChanged;
  bool get isSaving => _saveState == EditSaveState.saving;

  EditProfileProvider(this._profileProv) {
    _init();
  }

  void _init() {
    final p = _profileProv.profile;
    if (p == null) return;
    _name = p.name;
    _existingPhotoUrl = p.profilePhoto;
    notifyListeners();
  }

  // ── Name editing ───────────────────────────────────────────
  void onNameChanged(String value) {
    _name = value;
    _nameChanged = value.trim() != (_profileProv.profile?.name ?? '');
    notifyListeners();
  }

  // ── Image — pick from gallery ─────────────────────────────
  Future<void> pickFromGallery(BuildContext context) async {
    final xFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (xFile != null) await _crop(context, xFile.path);
  }

  // ── Image — pick from camera ──────────────────────────────
  Future<void> pickFromCamera(BuildContext context) async {
    final xFile = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (xFile != null) await _crop(context, xFile.path);
  }

  // ── Crop ──────────────────────────────────────────────────
  Future<void> _crop(BuildContext context, String path) async {
    final cropped = await ImageCropper().cropImage(
      sourcePath: path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Photo',
          toolbarColor: const Color(0xFF1847C4),
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: const Color(0xFF1847C4),
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
          hideBottomControls: false,
        ),
        IOSUiSettings(
          title: 'Crop Photo',
          aspectRatioLockEnabled: true,
          minimumAspectRatio: 1.0,
        ),
      ],
    );

    if (cropped != null) {
      _pickedImage = File(cropped.path);
      _photoChanged = true;
      notifyListeners();
    }
  }

  // ── Remove current photo ──────────────────────────────────
  void removePhoto() {
    _pickedImage = null;
    _existingPhotoUrl = '';
    _photoChanged = true;
    notifyListeners();
  }

  // ── Save to Firebase ──────────────────────────────────────
  Future<bool> saveChanges() async {
    final profile = _profileProv.profile;
    if (profile == null) return false;
    if (!hasChanges) return true;

    _saveState = EditSaveState.saving;
    _errorMessage = '';
    notifyListeners();

    try {
      String photoUrl = _existingPhotoUrl;

      // 1. Upload new photo to Firebase Storage (if changed)
      if (_photoChanged && _pickedImage != null) {
        final uid = profile.id;

        // ✅ FIX: path now matches Storage rule /users/{userId}/{allPaths=**}
        final ref = _fireStorage
            .ref()
            .child('users')
            .child(uid)
            .child('profilePhotos')
            .child('$uid.jpg');

        final uploadTask = await ref.putFile(
          _pickedImage!,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        photoUrl = await uploadTask.ref.getDownloadURL();
      } else if (_photoChanged && _pickedImage == null) {
        // User removed photo
        photoUrl = '';
      }

      // 2. Build Firestore update map
      final Map<String, dynamic> updates = {
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_nameChanged) updates['name'] = _name.trim();
      if (_photoChanged) updates['profilePhoto'] = photoUrl;

      // 3. Write to Firestore
      await _firestore.collection('users').doc(profile.id).update(updates);

      // 4. Sync back to SharedPreferences + in-memory provider
      await _profileProv.updateProfile(
        name: _nameChanged ? _name.trim() : null,
      );

      // Update profilePhoto in storage if changed
      if (_photoChanged) {
        final stored = await _storage.getUserData();
        await _storage.saveUserData(
          uid: profile.id,
          token: await _storage.getAuthToken() ?? '',
          name: _nameChanged ? _name.trim() : profile.name,
          email: profile.email,
          phone: profile.phone,
          role: stored['role'] ?? '',
          businessId: profile.businessId,
          businessName: profile.businessName,
          profilePhoto: photoUrl.isEmpty ? null : photoUrl,
        );
      }

      _saveState = EditSaveState.success;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to save: ${e.toString()}';
      _saveState = EditSaveState.error;
      notifyListeners();
      return false;
    }
  }

  void resetState() {
    _saveState = EditSaveState.idle;
    notifyListeners();
  }
}
