import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

enum CaptureSource {
  pdfFromFiles,
  cameraPhoto,
  gallery,
  csvFromFiles,
}

class CapturedFile {
  final File file;
  final String mimeType;
  final String originalFilename;
  final int sizeBytes;

  CapturedFile({
    required this.file,
    required this.mimeType,
    required this.originalFilename,
    required this.sizeBytes,
  });
}

class FiscalCaptureService {
  final ImagePicker _imagePicker = ImagePicker();

  Future<CapturedFile?> capture(CaptureSource source) async {
    switch (source) {
      case CaptureSource.pdfFromFiles:
        return _pickPdf();
      case CaptureSource.cameraPhoto:
        return _takePhoto();
      case CaptureSource.gallery:
        return _pickImage();
      case CaptureSource.csvFromFiles:
        return _pickCsv();
    }
  }

  Future<CapturedFile?> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: false,
    );
    if (result == null || result.files.isEmpty) return null;
    final picked = result.files.single;
    final file = File(picked.path!);
    final size = await file.length();
    if (size > 25 * 1024 * 1024) throw FileTooLargeException('El archivo supera el límite de 25MB');
    return CapturedFile(file: file, mimeType: 'application/pdf', originalFilename: picked.name, sizeBytes: size);
  }

  Future<CapturedFile?> _pickCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx', 'xls'],
      withData: false,
    );
    if (result == null || result.files.isEmpty) return null;
    final picked = result.files.single;
    final file = File(picked.path!);
    final size = await file.length();
    if (size > 10 * 1024 * 1024) throw FileTooLargeException('El archivo supera el límite de 10MB');
    return CapturedFile(file: file, mimeType: 'text/csv', originalFilename: picked.name, sizeBytes: size);
  }

  Future<CapturedFile?> _takePhoto() async {
    final xFile = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 2400,
      maxHeight: 2400,
    );
    if (xFile == null) return null;
    final file = File(xFile.path);
    final size = await file.length();
    return CapturedFile(
      file: file,
      mimeType: 'image/jpeg',
      originalFilename: 'foto_${DateTime.now().millisecondsSinceEpoch}.jpg',
      sizeBytes: size,
    );
  }

  Future<CapturedFile?> _pickImage() async {
    final xFile = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 2400);
    if (xFile == null) return null;
    final file = File(xFile.path);
    final size = await file.length();
    if (size > 25 * 1024 * 1024) throw FileTooLargeException('La imagen supera el límite de 25MB');
    return CapturedFile(file: file, mimeType: _detectImageMime(xFile.name), originalFilename: xFile.name, sizeBytes: size);
  }

  String _detectImageMime(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) return 'image/heic';
    return 'image/jpeg';
  }
}

class FileTooLargeException implements Exception {
  final String message;
  FileTooLargeException(this.message);
  @override
  String toString() => message;
}
