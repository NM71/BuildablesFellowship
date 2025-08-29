import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/sync_status_provider.dart';

class SyncStatusIndicator extends ConsumerWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isOnline
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOnline
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.red.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Connectivity Icon
          Icon(
            isOnline ? Icons.wifi : Icons.wifi_off,
            size: 16,
            color: isOnline ? Colors.green : Colors.red,
          ),
          // const SizedBox(width: 6),

          // Status Text
          // Text(
          //   isOnline ? 'Online' : 'Offline',
          //   style: TextStyle(
          //     color: isOnline ? Colors.green : Colors.red,
          //     fontSize: 12,
          //     fontWeight: FontWeight.w500,
          //   ),
          // ),
        ],
      ),
    );
  }
}

// Compact version for smaller spaces
class CompactSyncStatusIndicator extends ConsumerWidget {
  const CompactSyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);

    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: isOnline ? Colors.green : Colors.red,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: (isOnline ? Colors.green : Colors.red).withOpacity(0.3),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Icon(
        isOnline ? Icons.wifi : Icons.wifi_off,
        size: 8,
        color: Colors.white,
      ),
    );
  }
}

// Tooltip version with detailed information
class SyncStatusTooltip extends ConsumerWidget {
  final Widget child;

  const SyncStatusTooltip({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);

    return Tooltip(message: isOnline ? 'Online' : 'Offline', child: child);
  }
}
