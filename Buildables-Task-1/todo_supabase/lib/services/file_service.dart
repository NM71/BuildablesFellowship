import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

class FileAttachment {
  final String id;
  final String fileName;
  final String fileUrl;
  final String fileType;
  final int fileSize;
  final DateTime uploadedAt;
  final String uploadedBy;

  FileAttachment({
    required this.id,
    required this.fileName,
    required this.fileUrl,
    required this.fileType,
    required this.fileSize,
    required this.uploadedAt,
    required this.uploadedBy,
  });

  factory FileAttachment.fromJson(Map<String, dynamic> json) {
    if (kDebugMode) {
      print('📎 [FILE_ATTACHMENT] Parsing attachment JSON: $json');
    }

    return FileAttachment(
      id: json['id'].toString(),
      // Handle both database format (filename, file_path, content_type)
      // and JSON format (file_name, file_url, file_type)
      fileName: json['filename'] as String? ?? json['file_name'] as String,
      fileUrl: json['file_path'] as String? ?? json['file_url'] as String,
      fileType: json['content_type'] as String? ?? json['file_type'] as String,
      fileSize: json['file_size'] as int,
      uploadedAt: DateTime.parse(json['uploaded_at'] as String),
      uploadedBy: json['uploaded_by'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'file_name': fileName,
      'file_url': fileUrl,
      'file_type': fileType,
      'file_size': fileSize,
      'uploaded_at': uploadedAt.toIso8601String(),
      'uploaded_by': uploadedBy,
    };
  }

  bool get isImage => fileType.startsWith('image/');
  bool get isVideo => fileType.startsWith('video/');
  bool get isDocument => !isImage && !isVideo;

  String get fileExtension => path.extension(fileName).toLowerCase();
}

class FileService {
  static final FileService _instance = FileService._internal();
  static FileService get instance => _instance;

  FileService._internal();

  final _supabase = Supabase.instance.client;
  final _imagePicker = ImagePicker();
  final _uuid = const Uuid();

  String get _currentUserId => _supabase.auth.currentUser?.id ?? '';

  // File type validation - Expanded to support all common file types
  static const List<String> allowedImageTypes = [
    'image/jpeg',
    'image/jpg',
    'image/png',
    'image/gif',
    'image/webp',
    'image/svg+xml',
    'image/bmp',
    'image/tiff',
  ];

  static const List<String> allowedVideoTypes = [
    'video/mp4',
    'video/avi',
    'video/mov',
    'video/wmv',
    'video/mpeg',
    'video/quicktime',
    'video/x-msvideo',
  ];

  static const List<String> allowedDocumentTypes = [
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.ms-powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'text/plain',
    'text/csv',
    'application/rtf',
    'application/json',
    'application/xml',
    'text/html',
    'text/css',
    'text/javascript',
    'application/javascript',
  ];

  static const List<String> allowedArchiveTypes = [
    'application/zip',
    'application/x-zip-compressed',
    'application/x-rar-compressed',
    'application/x-7z-compressed',
  ];

  static const List<String> allowedAudioTypes = [
    'audio/mpeg',
    'audio/wav',
    'audio/ogg',
    'audio/mp4',
    'audio/aac',
  ];

  static const int maxFileSize = 10 * 1024 * 1024; // 10MB

  bool _isValidFileType(String fileType) {
    return allowedImageTypes.contains(fileType) ||
        allowedVideoTypes.contains(fileType) ||
        allowedDocumentTypes.contains(fileType) ||
        allowedArchiveTypes.contains(fileType) ||
        allowedAudioTypes.contains(fileType);
  }

  bool _isValidFileSize(int fileSize) {
    return fileSize <= maxFileSize;
  }

  // Pick image from gallery
  Future<XFile?> pickImageFromGallery() async {
    try {
      if (kIsWeb) {
        // On web, gallery and camera are the same (file picker)
        final XFile? image = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 80,
        );
        return image;
      } else {
        // Mobile: Use gallery source
        final XFile? image = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 80,
        );
        return image;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error picking image from gallery: $e');
      }
      return null;
    }
  }

  // Pick image from camera
  Future<XFile?> pickImageFromCamera() async {
    try {
      if (kIsWeb) {
        // On web, camera opens file picker (same as gallery)
        final XFile? image = await _imagePicker.pickImage(
          source: ImageSource.camera,
          imageQuality: 80,
        );
        return image;
      } else {
        // Mobile: Use camera source
        final XFile? image = await _imagePicker.pickImage(
          source: ImageSource.camera,
          imageQuality: 80,
        );
        return image;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error picking image from camera: $e');
      }
      return null;
    }
  }

  // Pick video from gallery
  Future<XFile?> pickVideoFromGallery() async {
    try {
      if (kIsWeb) {
        // On web, video picker works the same
        final XFile? video = await _imagePicker.pickVideo(
          source: ImageSource.gallery,
        );
        return video;
      } else {
        // Mobile: Use gallery source for videos
        final XFile? video = await _imagePicker.pickVideo(
          source: ImageSource.gallery,
        );
        return video;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error picking video from gallery: $e');
      }
      return null;
    }
  }

  // Web-specific file picker for multiple files
  Future<List<XFile>?> pickMultipleFiles() async {
    try {
      if (!kIsWeb) {
        // On mobile, we don't support multiple file selection yet
        return null;
      }

      // This would require additional web-specific implementation
      // For now, return null to indicate not supported
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error picking multiple files: $e');
      }
      return null;
    }
  }

  // Upload file to Supabase Storage and save metadata to database
  Future<FileAttachment?> uploadFile(XFile file, {String? taskId}) async {
    if (kDebugMode) {
      print('📎 [FILE_SERVICE] ===== STARTING FILE UPLOAD =====');
      print(
        '📎 [FILE_SERVICE] File: ${file.name}, Path: ${file.path}, Size: ${await file.length()} bytes',
      );
      print('📎 [FILE_SERVICE] Task ID: $taskId');
    }

    try {
      if (kDebugMode) {
        print('📎 [FILE_SERVICE] Step 1: Validating file...');
      }

      // Validate file
      final fileType = await _getFileType(file);
      final fileSize = await file.length();

      if (kDebugMode) {
        print(
          '📎 [FILE_SERVICE] File validation: type=$fileType, size=$fileSize bytes',
        );
        print(
          '📎 [FILE_SERVICE] File type valid: ${_isValidFileType(fileType)}',
        );
        print(
          '📎 [FILE_SERVICE] File size valid: ${_isValidFileSize(fileSize)}',
        );
      }

      if (!_isValidFileType(fileType)) {
        throw Exception('File type not supported: $fileType');
      }

      if (!_isValidFileSize(fileSize)) {
        throw Exception(
          'File size too large. Maximum size is ${maxFileSize ~/ (1024 * 1024)}MB',
        );
      }

      if (kDebugMode) {
        print('📎 [FILE_SERVICE] Step 2: File validation passed');
      }

      if (kDebugMode) {
        print('📎 [FILE_SERVICE] Step 3: Generating unique filename...');
      }

      // Generate unique file name
      final fileExtension = path.extension(file.name);
      final uniqueFileName = '${_uuid.v4()}$fileExtension';

      // Upload path based on task or general files
      final uploadPath = taskId != null
          ? 'task-files/$taskId/$uniqueFileName'
          : 'general-files/$uniqueFileName';

      if (kDebugMode) {
        print('📎 [FILE_SERVICE] Upload path: $uploadPath');
        print('📎 [FILE_SERVICE] Step 4: Reading file bytes...');
      }

      // Upload file to Supabase Storage
      final fileBytes = await file.readAsBytes();

      if (kDebugMode) {
        print('📎 [FILE_SERVICE] File bytes read: ${fileBytes.length} bytes');
        print('📎 [FILE_SERVICE] Step 5: Uploading to Supabase Storage...');
      }

      final uploadResponse = await _supabase.storage
          .from('task-attachments')
          .uploadBinary(
            uploadPath,
            fileBytes,
            fileOptions: FileOptions(contentType: fileType, upsert: false),
          );

      if (kDebugMode) {
        print('📎 [FILE_SERVICE] Upload response: $uploadResponse');
      }

      if (uploadResponse.isEmpty) {
        throw Exception('Failed to upload file');
      }

      if (kDebugMode) {
        print('📎 [FILE_SERVICE] Step 6: Getting public URL...');
      }

      // Get public URL
      final fileUrl = _supabase.storage
          .from('task-attachments')
          .getPublicUrl(uploadPath);

      if (kDebugMode) {
        print('📎 [FILE_SERVICE] Public URL: $fileUrl');
      }

      // Save metadata to database if taskId is provided
      String? attachmentId;
      if (taskId != null) {
        try {
          final dbResponse = await _supabase
              .from('task_attachments')
              .insert({
                'task_id': int.parse(taskId),
                'filename': file.name,
                'file_path': fileUrl,
                'file_size': fileSize,
                'content_type': fileType,
                'uploaded_by': _currentUserId,
              })
              .select()
              .single();

          // Use the returned ID from database (auto-generated bigint)
          attachmentId = dbResponse['id'].toString();

          if (kDebugMode) {
            print('Attachment metadata saved to database: $dbResponse');
          }
        } catch (dbError) {
          if (kDebugMode) {
            print('Failed to save attachment metadata to database: $dbError');
          }
          // Continue with the attachment creation even if DB save fails
          // The file is already uploaded to storage
        }
      }

      // Create file attachment record
      final attachment = FileAttachment(
        id:
            attachmentId ??
            _uuid.v4(), // Use DB ID if available, otherwise generate UUID
        fileName: file.name,
        fileUrl: fileUrl,
        fileType: fileType,
        fileSize: fileSize,
        uploadedAt: DateTime.now(),
        uploadedBy: _currentUserId,
      );

      if (kDebugMode) {
        print('File uploaded successfully: ${attachment.fileName}');
      }

      return attachment;
    } catch (e) {
      if (kDebugMode) {
        print('Error uploading file: $e');
      }
      return null;
    }
  }

  // Get file type from XFile
  Future<String> _getFileType(XFile file) async {
    // For web, we might not have mime type, so we'll infer from extension
    if (kIsWeb) {
      final extension = path.extension(file.name).toLowerCase();
      switch (extension) {
        // Images
        case '.jpg':
        case '.jpeg':
          return 'image/jpeg';
        case '.png':
          return 'image/png';
        case '.gif':
          return 'image/gif';
        case '.webp':
          return 'image/webp';
        case '.svg':
          return 'image/svg+xml';
        case '.bmp':
          return 'image/bmp';
        case '.tiff':
        case '.tif':
          return 'image/tiff';

        // Videos
        case '.mp4':
          return 'video/mp4';
        case '.avi':
          return 'video/x-msvideo';
        case '.mov':
          return 'video/quicktime';
        case '.wmv':
          return 'video/x-ms-wmv';
        case '.mpeg':
        case '.mpg':
          return 'video/mpeg';

        // Documents
        case '.pdf':
          return 'application/pdf';
        case '.doc':
          return 'application/msword';
        case '.docx':
          return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
        case '.xls':
          return 'application/vnd.ms-excel';
        case '.xlsx':
          return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
        case '.ppt':
          return 'application/vnd.ms-powerpoint';
        case '.pptx':
          return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
        case '.txt':
          return 'text/plain';
        case '.csv':
          return 'text/csv';
        case '.rtf':
          return 'application/rtf';
        case '.json':
          return 'application/json';
        case '.xml':
          return 'application/xml';
        case '.html':
        case '.htm':
          return 'text/html';
        case '.css':
          return 'text/css';
        case '.js':
          return 'application/javascript';

        // Archives
        case '.zip':
          return 'application/zip';
        case '.rar':
          return 'application/x-rar-compressed';
        case '.7z':
          return 'application/x-7z-compressed';

        // Audio
        case '.mp3':
          return 'audio/mpeg';
        case '.wav':
          return 'audio/wav';
        case '.ogg':
          return 'audio/ogg';
        case '.aac':
          return 'audio/aac';
        case '.m4a':
          return 'audio/mp4';

        default:
          return 'application/octet-stream';
      }
    } else {
      // For mobile, try to get mime type from file
      final filePath = file.path;
      final mimeType = await _getMimeTypeFromPath(filePath);
      return mimeType ?? 'application/octet-stream';
    }
  }

  Future<String?> _getMimeTypeFromPath(String filePath) async {
    try {
      // This is a simplified approach. In a real app, you might want to use
      // a more robust mime type detection library
      final extension = path.extension(filePath).toLowerCase();
      switch (extension) {
        case '.jpg':
        case '.jpeg':
          return 'image/jpeg';
        case '.png':
          return 'image/png';
        case '.gif':
          return 'image/gif';
        case '.webp':
          return 'image/webp';
        case '.mp4':
          return 'video/mp4';
        case '.pdf':
          return 'application/pdf';
        default:
          return null;
      }
    } catch (e) {
      return null;
    }
  }

  // Delete file from Supabase Storage and database
  Future<bool> deleteFile(String fileUrl, {String? attachmentId}) async {
    if (kDebugMode) {
      print('📎 [FILE_SERVICE] ===== STARTING FILE DELETION =====');
      print('📎 [FILE_SERVICE] File URL: $fileUrl');
      print('📎 [FILE_SERVICE] Attachment ID: $attachmentId');
    }

    try {
      if (kDebugMode) {
        print('📎 [FILE_SERVICE] Step 1: Extracting file path from URL...');
      }

      // Extract file path from URL
      final uri = Uri.parse(fileUrl);
      final pathSegments = uri.pathSegments;
      final filePath = pathSegments
          .sublist(pathSegments.indexOf('task-attachments') + 1)
          .join('/');

      if (kDebugMode) {
        print('📎 [FILE_SERVICE] Extracted file path: $filePath');
        print('📎 [FILE_SERVICE] Step 2: Deleting from Supabase Storage...');
      }

      // Delete from storage
      final storageResponse = await _supabase.storage
          .from('task-attachments')
          .remove([filePath]);

      if (kDebugMode) {
        print('📎 [FILE_SERVICE] Storage deletion response: $storageResponse');
      }

      // Delete from database if attachmentId is provided
      if (attachmentId != null) {
        if (kDebugMode) {
          print('📎 [FILE_SERVICE] Step 3: Deleting metadata from database...');
        }

        try {
          final dbResponse = await _supabase
              .from('task_attachments')
              .delete()
              .eq('id', attachmentId)
              .select();

          if (kDebugMode) {
            print('📎 [FILE_SERVICE] Database deletion response: $dbResponse');
            print('Attachment metadata deleted from database: $attachmentId');
          }
        } catch (dbError) {
          if (kDebugMode) {
            print(
              'Failed to delete attachment metadata from database: $dbError',
            );
          }
          // Continue even if DB deletion fails
        }
      } else {
        if (kDebugMode) {
          print(
            '📎 [FILE_SERVICE] No attachment ID provided, skipping database deletion',
          );
        }
      }

      if (kDebugMode) {
        print('📎 [FILE_SERVICE] File deletion completed successfully');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [FILE_SERVICE] Error deleting file: $e');
      }
      return false;
    }
  }

  // Get file size formatted
  String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  // Get file icon based on type - Enhanced for all supported file types
  IconData getFileIcon(String fileType) {
    if (fileType.startsWith('image/')) {
      return Icons.image;
    } else if (fileType.startsWith('video/')) {
      return Icons.video_file;
    } else if (fileType.startsWith('audio/')) {
      return Icons.audio_file;
    } else if (fileType == 'application/pdf') {
      return Icons.picture_as_pdf;
    } else if (fileType == 'application/msword' ||
        fileType ==
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document') {
      return Icons.description;
    } else if (fileType == 'application/vnd.ms-excel' ||
        fileType ==
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet') {
      return Icons.table_chart;
    } else if (fileType == 'application/vnd.ms-powerpoint' ||
        fileType ==
            'application/vnd.openxmlformats-officedocument.presentationml.presentation') {
      return Icons.slideshow;
    } else if (fileType == 'text/plain') {
      return Icons.text_snippet;
    } else if (fileType == 'text/csv') {
      return Icons.table_rows;
    } else if (fileType == 'application/json') {
      return Icons.data_object;
    } else if (fileType == 'application/xml' || fileType == 'text/xml') {
      return Icons.code;
    } else if (fileType == 'text/html') {
      return Icons.html;
    } else if (fileType == 'text/css') {
      return Icons.css;
    } else if (fileType == 'application/javascript' ||
        fileType == 'text/javascript') {
      return Icons.javascript;
    } else if (fileType == 'application/zip' ||
        fileType == 'application/x-zip-compressed' ||
        fileType == 'application/x-rar-compressed' ||
        fileType == 'application/x-7z-compressed') {
      return Icons.archive;
    } else {
      return Icons.insert_drive_file;
    }
  }
}
