import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/connectivity_service.dart';

// Simple connectivity status
class ConnectivityState {
  final bool isOnline;

  const ConnectivityState({required this.isOnline});

  ConnectivityState copyWith({bool? isOnline}) {
    return ConnectivityState(isOnline: isOnline ?? this.isOnline);
  }
}

// Simple connectivity notifier
class ConnectivityNotifier extends StateNotifier<ConnectivityState> {
  final ConnectivityService _connectivityService;
  StreamSubscription<bool>? _connectivitySubscription;

  ConnectivityNotifier(this._connectivityService)
    : super(const ConnectivityState(isOnline: true)) {
    _initialize();
  }

  void _initialize() {
    _connectivitySubscription = _connectivityService.connectionStatus.listen((
      isOnline,
    ) {
      if (kDebugMode) {
        print('Connectivity: ${isOnline ? 'Online' : 'Offline'}');
      }
      state = state.copyWith(isOnline: isOnline);
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}

// Providers
final connectivityStatusProvider =
    StateNotifierProvider<ConnectivityNotifier, ConnectivityState>((ref) {
      final connectivityService = ref.watch(connectivityServiceProvider);
      return ConnectivityNotifier(connectivityService);
    });

// Convenience provider for online status
final isOnlineProvider = Provider<bool>((ref) {
  return ref.watch(connectivityStatusProvider).isOnline;
});
