import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/sync_status_indicator.dart';
import '../providers/task_provider.dart';

class CustomAppbar extends ConsumerWidget {
  const CustomAppbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRefreshing = ref.watch(isRefreshingTasksProvider);

    return Container(
      decoration: const BoxDecoration(color: Colors.black),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Left side - Logo and Title
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    'assets/images/supabase-logo.svg',
                    width: 25,
                    height: 25,
                    fit: BoxFit.cover,
                  ),
                  const SizedBox(width: 20),
                  Text(
                    'T O D O ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),

            // Center - Refresh Button
            IconButton(
              onPressed: isRefreshing
                  ? null
                  : () async {
                      await ref.read(taskProvider.notifier).refreshTasks();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Tasks refreshed successfully'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
              icon: isRefreshing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.refresh, color: Colors.white, size: 24),
              tooltip: 'Refresh tasks',
            ),

            // Right side - Sync Status Indicator
            const SyncStatusIndicator(),
          ],
        ),
      ),
    );
  }
}
