import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';

class StorageService {
  StorageService._();

  static final StorageService instance = StorageService._();
  static const _maxPhotoBytes = 1024 * 1024;
  static const _maxAttachmentBytes = 10 * 1024 * 1024;
  static const _maxDocumentBytes = 10 * 1024 * 1024;
  static const _maxAudioNoteBytes = 10 * 1024 * 1024;
  static const _privateBuckets = {
    'company-media',
    'work-order-attachments',
    'technician-documents',
    'note-images',
  };

  SupabaseClient get _client => Supabase.instance.client;

  Future<String?> pickAndUploadPhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return null;
    final compressedBytes = _compressPhoto(bytes, maxBytes: _maxPhotoBytes);

    return _uploadBinary(
      bucket: 'work-order-photos',
      folder: 'photos',
      fileName: _forceJpgFileName(file.name),
      bytes: compressedBytes,
      contentType: 'image/jpeg',
    );
  }

  Future<String?> pickAndUploadAttachment() async {
    final result = await FilePicker.platform.pickFiles(withData: true);

    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return null;
    _ensureMaxBytes(
      bytes: bytes,
      maxBytes: _maxAttachmentBytes,
      errorMessage: 'O anexo excede o limite de 10 MB.',
    );

    return _uploadBinary(
      bucket: 'work-order-attachments',
      folder: 'attachments',
      fileName: file.name,
      bytes: bytes,
      contentType: _guessContentType(file.name),
    );
  }

  Future<String> uploadWorkOrderAudioNote({
    required String workOrderId,
    required Uint8List bytes,
    String fileName = 'nota_audio.m4a',
  }) async {
    _ensureMaxBytes(
      bytes: bytes,
      maxBytes: _maxAudioNoteBytes,
      errorMessage: 'A nota audio excede o limite de 10 MB.',
    );

    return _uploadBinary(
      bucket: 'work-order-attachments',
      folder: 'audio-notes/$workOrderId',
      fileName: fileName,
      bytes: bytes,
      contentType: _guessContentType(fileName) ?? 'audio/mp4',
    );
  }

  Future<String?> pickAndUploadTechnicianProfilePhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return null;
    final compressedBytes = _compressPhoto(bytes, maxBytes: _maxPhotoBytes);

    return _uploadBinary(
      bucket: 'technician-profile-photos',
      folder: 'profiles',
      fileName: _forceJpgFileName(file.name),
      bytes: compressedBytes,
      contentType: 'image/jpeg',
    );
  }

  Future<String?> pickAndUploadTechnicianDocument() async {
    final result = await FilePicker.platform.pickFiles(withData: true);

    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return null;
    _ensureMaxBytes(
      bytes: bytes,
      maxBytes: _maxDocumentBytes,
      errorMessage: 'O documento excede o limite de 10 MB.',
    );

    return _uploadBinary(
      bucket: 'technician-documents',
      folder: 'documents',
      fileName: file.name,
      bytes: bytes,
      contentType: _guessContentType(file.name),
    );
  }

  Future<String?> pickAndUploadAssetProfilePhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return null;
    final compressedBytes = _compressPhoto(bytes, maxBytes: _maxPhotoBytes);

    return _uploadBinary(
      bucket: 'asset-profile-photos',
      folder: 'profiles',
      fileName: _forceJpgFileName(file.name),
      bytes: compressedBytes,
      contentType: 'image/jpeg',
    );
  }

  Future<String?> pickAndUploadLocationPhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return null;
    final compressedBytes = _compressPhoto(bytes, maxBytes: _maxPhotoBytes);

    return _uploadBinary(
      bucket: 'location-photos',
      folder: 'locations',
      fileName: _forceJpgFileName(file.name),
      bytes: compressedBytes,
      contentType: 'image/jpeg',
    );
  }

  Future<String?> pickAndUploadCompanyLogo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return null;
    final compressedBytes = _compressPhoto(bytes, maxBytes: _maxPhotoBytes);

    return _uploadBinary(
      bucket: 'company-media',
      folder: 'logos',
      fileName: _forceJpgFileName(file.name),
      bytes: compressedBytes,
      contentType: 'image/jpeg',
    );
  }

  Future<String?> pickAndUploadCompanyCoverPhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return null;
    final compressedBytes = _compressPhoto(bytes, maxBytes: _maxPhotoBytes);

    return _uploadBinary(
      bucket: 'company-media',
      folder: 'covers',
      fileName: _forceJpgFileName(file.name),
      bytes: compressedBytes,
      contentType: 'image/jpeg',
    );
  }

  Future<List<Map<String, dynamic>>> pickAndUploadAssetDeviceDocumentation({
    required String assetId,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
      allowMultiple: true,
    );

    if (result == null || result.files.isEmpty) return const [];

    final uploads = <Map<String, dynamic>>[];
    for (final file in result.files) {
      final bytes = file.bytes;
      if (bytes == null) continue;

      final extension = _fileExtension(file.name);
      final isImage =
          extension == 'jpg' || extension == 'jpeg' || extension == 'png';

      late final String uploadedPath;
      late final String fileName;
      late final String contentType;

      if (isImage) {
        final compressedBytes = _compressPhoto(bytes, maxBytes: _maxPhotoBytes);
        fileName = _forceJpgFileName(file.name);
        contentType = 'image/jpeg';
        uploadedPath = await _uploadBinary(
          bucket: 'company-media',
          folder: 'asset-devices/$assetId/documentation',
          fileName: fileName,
          bytes: compressedBytes,
          contentType: contentType,
        );
      } else {
        _ensureMaxBytes(
          bytes: bytes,
          maxBytes: _maxDocumentBytes,
          errorMessage: 'O ficheiro excede o limite de 10 MB.',
        );
        fileName = _sanitizeFileName(file.name);
        contentType =
            _guessContentType(file.name) ?? 'application/octet-stream';
        uploadedPath = await _uploadBinary(
          bucket: 'company-media',
          folder: 'asset-devices/$assetId/documentation',
          fileName: fileName,
          bytes: bytes,
          contentType: contentType,
        );
      }

      uploads.add({
        'path': uploadedPath,
        'file_name': fileName,
        'content_type': contentType,
      });
    }

    return uploads;
  }

  Future<List<String>> pickAndUploadNoteImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
      allowMultiple: true,
    );

    if (result == null || result.files.isEmpty) return const [];

    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];

    final uploads = <String>[];
    for (final file in result.files) {
      final bytes = file.bytes;
      if (bytes == null) continue;
      final compressedBytes = _compressPhoto(bytes, maxBytes: _maxPhotoBytes);

      final uploaded = await _uploadBinary(
        bucket: 'note-images',
        folder: '$userId/notes',
        fileName: _forceJpgFileName(file.name),
        bytes: compressedBytes,
        contentType: 'image/jpeg',
      );
      uploads.add(uploaded);
    }

    return uploads;
  }

  Uint8List _compressPhoto(Uint8List bytes, {int maxBytes = _maxPhotoBytes}) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;

    var working = decoded;

    if (working.width > 1800 || working.height > 1800) {
      working = img.copyResize(
        working,
        width: working.width >= working.height ? 1800 : null,
        height: working.height > working.width ? 1800 : null,
        interpolation: img.Interpolation.average,
      );
    }

    var quality = 90;
    var best = Uint8List.fromList(img.encodeJpg(working, quality: quality));
    if (best.lengthInBytes <= maxBytes) return best;

    while (best.lengthInBytes > maxBytes && quality > 35) {
      quality -= 5;
      best = Uint8List.fromList(img.encodeJpg(working, quality: quality));
    }

    while (best.lengthInBytes > maxBytes &&
        (working.width > 480 || working.height > 480)) {
      final nextWidth = (working.width * 0.85).round();
      final nextHeight = (working.height * 0.85).round();
      if (nextWidth < 480 && nextHeight < 480) {
        break;
      }
      if (nextWidth >= working.width && nextHeight >= working.height) {
        break;
      }

      working = img.copyResize(
        working,
        width: nextWidth < 480 ? null : nextWidth,
        height: nextHeight < 480 ? null : nextHeight,
        interpolation: img.Interpolation.average,
      );
      best = Uint8List.fromList(img.encodeJpg(working, quality: quality));
    }

    return best;
  }

  void _ensureMaxBytes({
    required Uint8List bytes,
    required int maxBytes,
    required String errorMessage,
  }) {
    if (bytes.lengthInBytes > maxBytes) {
      throw StateError(errorMessage);
    }
  }

  String _forceJpgFileName(String fileName) {
    final sanitized = _sanitizeFileName(fileName);
    final dotIndex = sanitized.lastIndexOf('.');
    final stem = dotIndex > 0 ? sanitized.substring(0, dotIndex) : sanitized;
    return '${stem.isEmpty ? 'image' : stem}.jpg';
  }

  Future<String> _uploadBinary({
    required String bucket,
    required String folder,
    required String fileName,
    required Uint8List bytes,
    String? contentType,
  }) async {
    final safeFileName = _sanitizeFileName(fileName);
    final path =
        '$folder/${DateTime.now().millisecondsSinceEpoch}_$safeFileName';

    await _client.storage
        .from(bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(upsert: true, contentType: contentType),
        );

    if (_privateBuckets.contains(bucket)) {
      return path;
    }

    return _client.storage.from(bucket).getPublicUrl(path);
  }

  Future<void> deleteStoredObject({
    required String bucket,
    String? storedValue,
  }) {
    return deleteStoredObjects(bucket: bucket, storedValues: [storedValue]);
  }

  Future<void> deleteStoredObjects({
    required String bucket,
    required Iterable<String?> storedValues,
  }) async {
    final paths = <String>{};

    for (final rawValue in storedValues) {
      final value = rawValue?.trim() ?? '';
      if (value.isEmpty) continue;

      final storagePath = _extractStoragePath(bucket: bucket, value: value);
      if (storagePath == null || storagePath.trim().isEmpty) {
        throw StateError(
          'Nao foi possivel resolver o caminho do ficheiro no bucket $bucket.',
        );
      }
      paths.add(storagePath.trim());
    }

    if (paths.isEmpty) return;

    await _client.storage.from(bucket).remove(paths.toList());
  }

  Future<Uri?> resolveFileUri({
    required String bucket,
    required String storedValue,
    int expiresIn = 3600,
  }) async {
    final value = storedValue.trim();
    if (value.isEmpty) return null;

    final storagePath = _extractStoragePath(bucket: bucket, value: value);
    if (storagePath != null) {
      if (_privateBuckets.contains(bucket)) {
        final signedUrl = await _client.storage
            .from(bucket)
            .createSignedUrl(storagePath, expiresIn);
        return Uri.tryParse(signedUrl);
      }

      return Uri.tryParse(
        _client.storage.from(bucket).getPublicUrl(storagePath),
      );
    }

    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme) return null;
    return uri;
  }

  String? _extractStoragePath({required String bucket, required String value}) {
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme) {
      return value;
    }

    final markerPatterns = [
      '/storage/v1/object/public/$bucket/',
      '/storage/v1/object/sign/$bucket/',
      '/storage/v1/object/authenticated/$bucket/',
    ];

    for (final marker in markerPatterns) {
      final index = value.indexOf(marker);
      if (index >= 0) {
        final path = value.substring(index + marker.length);
        final queryIndex = path.indexOf('?');
        return queryIndex >= 0 ? path.substring(0, queryIndex) : path;
      }
    }

    return null;
  }

  String _sanitizeFileName(String fileName) {
    var sanitized = fileName.trim();
    sanitized = sanitized.replaceAll(RegExp(r'[^\w.\-]+', unicode: true), '_');
    sanitized = sanitized.replaceAll(RegExp(r'_+'), '_');
    sanitized = sanitized.replaceAll(RegExp(r'^\.+'), '');
    sanitized = sanitized.replaceAll(RegExp(r'^_+'), '');
    sanitized = sanitized.replaceAll(RegExp(r'_+\.'), '.');

    return sanitized.isEmpty ? 'file' : sanitized;
  }

  String _fileExtension(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex >= fileName.length - 1) {
      return '';
    }
    return fileName.substring(dotIndex + 1).toLowerCase();
  }

  String? _guessContentType(String fileName) {
    final extension = _fileExtension(fileName);

    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'pdf':
        return 'application/pdf';
      case 'm4a':
        return 'audio/mp4';
      case 'aac':
        return 'audio/aac';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'ogg':
      case 'oga':
        return 'audio/ogg';
      case 'txt':
        return 'text/plain';
      case 'csv':
        return 'text/csv';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      default:
        return null;
    }
  }
}
