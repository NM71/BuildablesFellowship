import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/location_service.dart';
import '../widgets/collaborator_map.dart';
import '../providers/task_provider.dart';

/// Screen to display all collaborators' locations on a map
class CollaboratorMapScreen extends ConsumerStatefulWidget {
  final String? taskId; // If null, show all collaborators from all tasks

  const CollaboratorMapScreen({super.key, this.taskId});

  @override
  ConsumerState<CollaboratorMapScreen> createState() =>
      _CollaboratorMapScreenState();
}

class _CollaboratorMapScreenState extends ConsumerState<CollaboratorMapScreen> {
  final LocationService _locationService = LocationService();
  List<UserLocation> _participantLocations = [];
  LatLng? _currentUserLocation;
  String? _taskOwnerId;
  bool _isLoading = true;
  bool _isLocationTracking = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeLocationTracking();
    _loadCollaboratorLocations();
  }

  Future<void> _initializeLocationTracking() async {
    try {
      // Check if location tracking is already active
      if (_locationService.isTracking) {
        setState(() => _isLocationTracking = true);
        return;
      }

      // Request permissions and start tracking
      final permissionStatus = await _locationService
          .checkAndRequestPermissions();

      if (permissionStatus == LocationPermissionStatus.granted) {
        final started = await _locationService.startLocationTracking();
        setState(() => _isLocationTracking = started);

        if (!started) {
          setState(() => _errorMessage = 'Failed to start location tracking');
        }
      } else {
        setState(() {
          _errorMessage = _getPermissionErrorMessage(permissionStatus);
        });
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error initializing location: $e');
    }
  }

  Future<void> _loadCollaboratorLocations() async {
    setState(() => _isLoading = true);

    try {
      // Get task owner ID if we have a specific task
      if (widget.taskId != null) {
        final tasks = ref.read(taskProvider).tasks;
        final task = tasks.firstWhere(
          (t) => t.id.toString() == widget.taskId,
          orElse: () => throw Exception('Task not found'),
        );
        _taskOwnerId = task.ownerId;
      }

      // Get current user ID from Supabase auth
      final currentUserId = Supabase.instance.client.auth.currentUser?.id ?? '';

      // Get user's current location
      final position = await _locationService.getCurrentPosition();
      if (position != null) {
        setState(
          () => _currentUserLocation = LatLng(
            position.latitude,
            position.longitude,
          ),
        );
      }

      // Get participant locations
      List<UserLocation> locations;
      if (widget.taskId != null) {
        // Load locations for specific task
        locations = await _locationService.getTaskParticipantLocations(
          widget.taskId!,
        );
      } else {
        // Load locations for all user's tasks
        final tasks = ref.read(taskProvider).tasks;
        final allLocations = <UserLocation>[];

        for (final task in tasks) {
          final taskLocations = await _locationService
              .getTaskParticipantLocations(task.id.toString());
          allLocations.addAll(taskLocations);
        }

        // Remove duplicates by userId
        final uniqueLocations = <String, UserLocation>{};
        for (final location in allLocations) {
          uniqueLocations[location.userId] = location;
        }
        locations = uniqueLocations.values.toList();
      }

      setState(() => _participantLocations = locations);

      // Start listening for real-time updates
      await _locationService.listenToCollaboratorLocations(
        widget.taskId ?? 'all_tasks',
        onData: (locations) {
          if (mounted) {
            setState(() => _participantLocations = locations);
          }
        },
      );
    } catch (e) {
      setState(() => _errorMessage = 'Error loading locations: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _getPermissionErrorMessage(LocationPermissionStatus status) {
    switch (status) {
      case LocationPermissionStatus.denied:
        return 'Location permission denied. Please enable location access in settings.';
      case LocationPermissionStatus.permanentlyDenied:
        return 'Location permission permanently denied. Please enable location access in app settings.';
      case LocationPermissionStatus.servicesDisabled:
        return 'Location services are disabled. Please enable location services.';
      default:
        return 'Location permission required to show collaborator locations.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.taskId != null ? 'Task Collaborators' : 'All Collaborators',
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isLocationTracking ? Icons.location_on : Icons.location_off,
            ),
            onPressed: _toggleLocationTracking,
            tooltip: _isLocationTracking
                ? 'Stop Location Tracking'
                : 'Start Location Tracking',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCollaboratorLocations,
            tooltip: 'Refresh Locations',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null) {
      return _buildErrorView();
    }

    if (_isLoading) {
      return _buildLoadingView();
    }

    if (_participantLocations.isEmpty && _currentUserLocation == null) {
      return _buildEmptyView();
    }

    return _buildMapView();
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() => _errorMessage = null);
                _initializeLocationTracking();
              },
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading collaborator locations...'),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No collaborator locations available',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Collaborators need to enable location sharing and be online to appear on the map.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadCollaboratorLocations,
              child: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapView() {
    // Get current user ID
    final currentUserId = Supabase.instance.client.auth.currentUser?.id ?? '';

    return Stack(
      children: [
        CollaboratorMap(
          participantLocations: _participantLocations,
          currentUserLocation: _currentUserLocation,
          taskOwnerId: _taskOwnerId,
          currentUserId: currentUserId,
          height: MediaQuery.of(context).size.height - kToolbarHeight - 24,
        ),
        // Status indicator
        Positioned(
          top: 16,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _isLocationTracking ? Colors.green : Colors.orange,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isLocationTracking ? Icons.location_on : Icons.location_off,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  _isLocationTracking ? 'Tracking Active' : 'Tracking Inactive',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Participant count
        Positioned(
          top: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              '${_participantLocations.length} participant${_participantLocations.length == 1 ? '' : 's'}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _toggleLocationTracking() async {
    if (_isLocationTracking) {
      await _locationService.stopLocationTracking();
      setState(() => _isLocationTracking = false);
    } else {
      final started = await _locationService.startLocationTracking();
      setState(() => _isLocationTracking = started);
    }
  }
}
