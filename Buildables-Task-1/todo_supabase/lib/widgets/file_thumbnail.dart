import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/file_service.dart';

class FileThumbnail extends StatelessWidget {
  final FileAttachment attachment;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final bool showDeleteButton;
  final double size;

  const FileThumbnail({
    super.key,
    required this.attachment,
    this.onTap,
    this.onDelete,
    this.showDeleteButton = true,
    this.size = 80.0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () => _openFile(context),
      child: Container(
        width: size,
        height: size,
        margin: const EdgeInsets.only(right: 12, bottom: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Stack(
          children: [
            // File content
            ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: _buildFileContent(),
            ),

            // Delete button
            if (showDeleteButton)
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

            // File type indicator for non-images
            if (!attachment.isImage)
              Positioned(
                bottom: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    attachment.fileExtension.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileContent() {
    if (attachment.isImage) {
      return CachedNetworkImage(
        imageUrl: attachment.fileUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: Colors.grey[800],
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.grey[800],
          child: const Icon(
            Icons.broken_image,
            color: Colors.white54,
            size: 24,
          ),
        ),
      );
    } else {
      // For non-image files, show icon
      return Container(
        color: Colors.grey[800],
        child: Icon(
          FileService.instance.getFileIcon(attachment.fileType),
          color: Colors.white,
          size: 32,
        ),
      );
    }
  }

  void _openFile(BuildContext context) {
    // Platform-specific file opening
    if (Theme.of(context).platform == TargetPlatform.android ||
        Theme.of(context).platform == TargetPlatform.iOS) {
      // Mobile: Show dialog with options
      _showMobileFileDialog(context);
    } else {
      // Web: Direct image viewing or download
      if (attachment.isImage) {
        _showFullImage(context);
      } else {
        _showWebFileDialog(context);
      }
    }
  }

  void _showMobileFileDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          attachment.fileName,
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Type: ${attachment.fileType}',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
            Text(
              'Size: ${FileService.instance.formatFileSize(attachment.fileSize)}',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
            Text(
              'Uploaded: ${_formatDate(attachment.uploadedAt)}',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (attachment.isImage)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showFullImage(context);
              },
              child: const Text('View Full Image'),
            ),
        ],
      ),
    );
  }

  void _showWebFileDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          attachment.fileName,
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Type: ${attachment.fileType}',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
            Text(
              'Size: ${FileService.instance.formatFileSize(attachment.fileSize)}',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
            Text(
              'Uploaded: ${_formatDate(attachment.uploadedAt)}',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.web, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Web Platform',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // On web, open file in new tab
              _openFileInNewTab(context);
            },
            child: const Text('Open in New Tab'),
          ),
        ],
      ),
    );
  }

  Future<void> _openFileInNewTab(BuildContext context) async {
    final url = attachment.fileUrl;
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(
          Uri.parse(url),
          webOnlyWindowName: '_blank', // Opens in new tab on web
        );
      } else {
        // Fallback: show error message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open file'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showFullImage(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            InteractiveViewer(
              child: CachedNetworkImage(
                imageUrl: attachment.fileUrl,
                fit: BoxFit.contain,
                placeholder: (context, url) =>
                    const Center(child: CircularProgressIndicator()),
                errorWidget: (context, url, error) => const Center(
                  child: Icon(
                    Icons.broken_image,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
