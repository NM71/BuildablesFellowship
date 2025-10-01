import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Represents a user's location data
class UserLocation {
  final String userId;
  final String? email;
  final LatLng position;
  final double? accuracy;
  final DateTime timestamp;
  final bool isOnline;
  final DateTime? lastSeen;

  UserLocation({
    required this.userId,
    required this.position,
    this.email,
    this.accuracy,
    required this.timestamp,
    this.isOnline = false,
    this.lastSeen,
  });

  factory UserLocation.fromJson(Map<String, dynamic> json) {
    return UserLocation(
      userId: json['user_id'] as String,
      email: json['email'] as String?,
      position: LatLng(json['latitude'] as double, json['longitude'] as double),
      accuracy: json['accuracy'] as double?,
      timestamp: DateTime.parse(json['location_timestamp'] as String),
      isOnline: json['is_online'] as bool? ?? false,
      lastSeen: json['last_seen'] != null
          ? DateTime.parse(json['last_seen'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'email': email,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracy': accuracy,
      'timestamp': timestamp.toIso8601String(),
      'is_online': isOnline,
      'last_seen': lastSeen?.toIso8601String(),
    };
  }
}

/// Service for handling location tracking and permissions
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final _supabase = Supabase.instance.client;
  StreamSubscription<Position>? _positionStreamSubscription;
  Timer? _locationUpdateTimer;
  bool _isTracking = false;

  // Stream controller for location updates
  final StreamController<List<UserLocation>> _collaboratorLocationsController =
      StreamController<List<UserLocation>>.broadcast();

  Stream<List<UserLocation>> get collaboratorLocations =>
      _collaboratorLocationsController.stream;

  String get _currentUserId => _supabase.auth.currentUser?.id ?? '';

  /// Check and request location permissions
  Future<LocationPermissionStatus> checkAndRequestPermissions() async {
    if (kDebugMode) {
      print('📍 [LOCATION] Checking location permissions...');
    }

    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (kDebugMode) {
        print('❌ [LOCATION] Location services are disabled');
      }
      return LocationPermissionStatus.servicesDisabled;
    }

    // Check permission status
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      if (kDebugMode) {
        print('📍 [LOCATION] Requesting location permission...');
      }
      permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.denied) {
        if (kDebugMode) {
          print('❌ [LOCATION] Location permission denied');
        }
        return LocationPermissionStatus.denied;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (kDebugMode) {
        print('❌ [LOCATION] Location permission permanently denied');
      }
      return LocationPermissionStatus.permanentlyDenied;
    }

    // Check additional permissions for Android
    if (Platform.isAndroid) {
      final backgroundPermission = await Permission.locationAlways.status;
      if (!backgroundPermission.isGranted) {
        if (kDebugMode) {
          print('📍 [LOCATION] Requesting background location permission...');
        }
        final result = await Permission.locationAlways.request();
        if (!result.isGranted) {
          if (kDebugMode) {
            print('⚠️ [LOCATION] Background location permission denied');
          }
          // Continue with foreground-only location
        }
      }
    }

    if (kDebugMode) {
      print('✅ [LOCATION] Location permissions granted');
    }
    return LocationPermissionStatus.granted;
  }

  /// Get current position
  Future<Position?> getCurrentPosition() async {
    try {
      if (kDebugMode) {
        print('📍 [LOCATION] Getting current position...');
      }

      final permissionStatus = await checkAndRequestPermissions();
      if (permissionStatus != LocationPermissionStatus.granted) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      if (kDebugMode) {
        print(
          '✅ [LOCATION] Current position: ${position.latitude}, ${position.longitude}',
        );
      }

      return position;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [LOCATION] Error getting current position: $e');
      }
      return null;
    }
  }

  /// Start location tracking
  Future<bool> startLocationTracking() async {
    if (_isTracking) {
      if (kDebugMode) {
        print('⚠️ [LOCATION] Location tracking already active');
      }
      return true;
    }

    try {
      if (kDebugMode) {
        print('🚀 [LOCATION] Starting location tracking...');
      }

      final permissionStatus = await checkAndRequestPermissions();
      if (permissionStatus != LocationPermissionStatus.granted) {
        return false;
      }

      // Get initial position and update
      final initialPosition = await getCurrentPosition();
      if (initialPosition != null) {
        await _updateLocationToSupabase(initialPosition);
      }

      // Start periodic updates (every 30 seconds)
      _locationUpdateTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _updateCurrentLocation(),
      );

      // Start listening to position changes
      _positionStreamSubscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 50, // Update every 50 meters
            ),
          ).listen(
            (Position position) async {
              await _updateLocationToSupabase(position);
            },
            onError: (error) {
              if (kDebugMode) {
                print('❌ [LOCATION] Position stream error: $error');
              }
            },
          );

      _isTracking = true;

      if (kDebugMode) {
        print('✅ [LOCATION] Location tracking started successfully');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [LOCATION] Error starting location tracking: $e');
      }
      return false;
    }
  }

  /// Stop location tracking
  Future<void> stopLocationTracking() async {
    if (!_isTracking) return;

    if (kDebugMode) {
      print('🛑 [LOCATION] Stopping location tracking...');
    }

    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;

    await _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;

    // Mark user as offline
    await _markUserOffline();

    _isTracking = false;

    if (kDebugMode) {
      print('✅ [LOCATION] Location tracking stopped');
    }
  }

  /// Update current location to Supabase
  Future<void> _updateCurrentLocation() async {
    try {
      final position = await getCurrentPosition();
      if (position != null) {
        await _updateLocationToSupabase(position);
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [LOCATION] Error updating current location: $e');
      }
    }
  }

  /// Update location to Supabase database
  Future<void> _updateLocationToSupabase(Position position) async {
    try {
      if (kDebugMode) {
        print(
          '📡 [LOCATION] Updating location to Supabase: ${position.latitude}, ${position.longitude}',
        );
      }

      final response = await _supabase.rpc(
        'update_user_location',
        params: {
          'p_user_id': _currentUserId,
          'p_latitude': position.latitude,
          'p_longitude': position.longitude,
          'p_accuracy': position.accuracy,
        },
      );

      if (kDebugMode) {
        print('✅ [LOCATION] Location updated successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [LOCATION] Error updating location to Supabase: $e');
      }
    }
  }

  /// Mark user as offline
  Future<void> _markUserOffline() async {
    try {
      await _supabase.rpc(
        'mark_user_offline',
        params: {'p_user_id': _currentUserId},
      );

      if (kDebugMode) {
        print('✅ [LOCATION] User marked as offline');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [LOCATION] Error marking user offline: $e');
      }
    }
  }

  /// Get all task participant locations (including owner)
  Future<List<UserLocation>> getTaskParticipantLocations(String taskId) async {
    try {
      if (kDebugMode) {
        print(
          '📍 [LOCATION] Fetching all task participant locations for task: $taskId',
        );
      }

      final response = await _supabase.rpc(
        'get_task_participant_locations',
        params: {'p_task_id': taskId},
      );

      final locations = (response as List)
          .map((json) => UserLocation.fromJson(json as Map<String, dynamic>))
          .toList();

      if (kDebugMode) {
        print('✅ [LOCATION] Found ${locations.length} participant locations');
      }

      return locations;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [LOCATION] Error fetching participant locations: $e');
      }
      return [];
    }
  }

  /// Get collaborator locations for a specific task (legacy method)
  Future<List<UserLocation>> getCollaboratorLocations(String taskId) async {
    return getTaskParticipantLocations(taskId);
  }

  /// Start listening to collaborator location updates for a task
  Future<void> listenToCollaboratorLocations(
    String taskId, {
    required Function(List<UserLocation>) onData,
  }) async {
    // Initial fetch
    final initialLocations = await getCollaboratorLocations(taskId);
    onData(initialLocations);

    // Listen to realtime updates
    final channel = _supabase.channel('collaborator_locations_$taskId');

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_locations',
          callback: (payload) async {
            if (kDebugMode) {
              print('📡 [LOCATION] Location update received');
            }
            final locations = await getCollaboratorLocations(taskId);
            onData(locations);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_online_status',
          callback: (payload) async {
            if (kDebugMode) {
              print('📡 [LOCATION] Online status update received');
            }
            final locations = await getCollaboratorLocations(taskId);
            onData(locations);
          },
        )
        .subscribe();
  }

  /// Check if location tracking is active
  bool get isTracking => _isTracking;

  /// Dispose of resources
  void dispose() {
    stopLocationTracking();
    _collaboratorLocationsController.close();
  }
}

/// Location permission status enum
enum LocationPermissionStatus {
  granted,
  denied,
  permanentlyDenied,
  servicesDisabled,
}
