import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/file_service.dart';

class FileAttachmentWidget extends StatefulWidget {
  final Function(FileAttachment) onFileSelected;
  final String? taskId;
  final bool showProgress;

  const FileAttachmentWidget({
    super.key,
    required this.onFileSelected,
    this.taskId,
    this.showProgress = true,
  });

  @override
  State<FileAttachmentWidget> createState() => _FileAttachmentWidgetState();
}

class _FileAttachmentWidgetState extends State<FileAttachmentWidget> {
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  Future<void> _pickAndUploadFile(ImageSource source) async {
    if (_isUploading) return;

    XFile? file;
    try {
      if (source == ImageSource.gallery) {
        file = await FileService.instance.pickImageFromGallery();
      } else if (source == ImageSource.camera) {
        file = await FileService.instance.pickImageFromCamera();
      }
    } catch (e) {
      _showErrorSnackBar('Error picking file: $e');
      return;
    }

    if (file != null) {
      await _uploadFile(file);
    }
  }

  Future<void> _uploadFile(XFile file) async {
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      // Simulate progress updates
      for (int i = 1; i <= 10; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) {
          setState(() {
            _uploadProgress = i / 10;
          });
        }
      }

      final attachment = await FileService.instance.uploadFile(
        file,
        taskId: widget.taskId,
      );

      if (attachment != null) {
        widget.onFileSelected(attachment);
        _showSuccessSnackBar('File uploaded successfully');
      } else {
        _showErrorSnackBar('Failed to upload file');
      }
    } catch (e) {
      _showErrorSnackBar('Upload failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0.0;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green),
      );
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Attach File',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            // Different layout for web vs mobile
            if (Theme.of(context).platform == TargetPlatform.android ||
                Theme.of(context).platform == TargetPlatform.iOS)
              // Mobile layout with camera/gallery distinction
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildAttachmentOption(
                        icon: Icons.photo_library,
                        label: 'Gallery',
                        onTap: () {
                          Navigator.pop(context);
                          _pickAndUploadFile(ImageSource.gallery);
                        },
                      ),
                      _buildAttachmentOption(
                        icon: Icons.camera_alt,
                        label: 'Camera',
                        onTap: () {
                          Navigator.pop(context);
                          _pickAndUploadFile(ImageSource.camera);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildAttachmentOption(
                        icon: Icons.video_library,
                        label: 'Video',
                        onTap: () async {
                          Navigator.pop(context);
                          final video = await FileService.instance
                              .pickVideoFromGallery();
                          if (video != null) {
                            await _uploadFile(video);
                          }
                        },
                      ),
                      _buildAttachmentOption(
                        icon: Icons.insert_drive_file,
                        label: 'Document',
                        onTap: () async {
                          Navigator.pop(context);
                          // For mobile, we'll use image picker with gallery to allow any file
                          // This is a limitation of the current image_picker package
                          final file = await FileService.instance
                              .pickImageFromGallery();
                          if (file != null) {
                            await _uploadFile(file);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              )
            else
              // Web layout with more options
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildAttachmentOption(
                        icon: Icons.photo_library,
                        label: 'Photos',
                        onTap: () {
                          Navigator.pop(context);
                          _pickAndUploadFile(ImageSource.gallery);
                        },
                      ),
                      _buildAttachmentOption(
                        icon: Icons.video_library,
                        label: 'Videos',
                        onTap: () async {
                          Navigator.pop(context);
                          final video = await FileService.instance
                              .pickVideoFromGallery();
                          if (video != null) {
                            await _uploadFile(video);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildAttachmentOption(
                        icon: Icons.insert_drive_file,
                        label: 'Documents',
                        onTap: () async {
                          Navigator.pop(context);
                          // On web, we can handle any file type
                          final file = await FileService.instance
                              .pickImageFromGallery();
                          if (file != null) {
                            await _uploadFile(file);
                          }
                        },
                      ),
                      _buildAttachmentOption(
                        icon: Icons.archive,
                        label: 'Archives',
                        onTap: () async {
                          Navigator.pop(context);
                          final file = await FileService.instance
                              .pickImageFromGallery();
                          if (file != null) {
                            await _uploadFile(file);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '💡 On web, all options open your file picker - select any supported file type',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            const SizedBox(height: 20),
            Text(
              'Supported: Images, Videos, Documents, Archives, Audio (max 10MB)',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
              size: 30,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_isUploading && widget.showProgress)
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Uploading file...',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: _uploadProgress,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        GestureDetector(
          onTap: _isUploading ? null : _showAttachmentOptions,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isUploading
                  ? Colors.white.withValues(alpha: 0.05)
                  : Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isUploading
                    ? Colors.white.withValues(alpha: 0.1)
                    : Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.attach_file,
                  color: _isUploading
                      ? Colors.white.withValues(alpha: 0.5)
                      : Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  _isUploading ? 'Uploading...' : 'Attach File',
                  style: TextStyle(
                    color: _isUploading
                        ? Colors.white.withValues(alpha: 0.5)
                        : Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.add,
                  color: _isUploading
                      ? Colors.white.withValues(alpha: 0.5)
                      : Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
