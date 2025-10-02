import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/location_service.dart';

/// Widget to display collaborators on an interactive Google Map
class CollaboratorMap extends StatefulWidget {
  final List<UserLocation> participantLocations;
  final LatLng? currentUserLocation;
  final String? taskOwnerId;
  final String currentUserId;
  final bool showCurrentUserLocation;
  final double? height;

  const CollaboratorMap({
    super.key,
    required this.participantLocations,
    this.currentUserLocation,
    this.taskOwnerId,
    required this.currentUserId,
    this.showCurrentUserLocation = true,
    this.height,
  });

  @override
  State<CollaboratorMap> createState() => _CollaboratorMapState();
}

class _CollaboratorMapState extends State<CollaboratorMap> {
  GoogleMapController? _mapController;
  LatLng? _mapCenter;
  final Set<Marker> _markers = {};
  final Set<Circle> _circles = {};

  @override
  void initState() {
    super.initState();
    _calculateMapCenter();
    _createMarkers();
  }

  @override
  void didUpdateWidget(CollaboratorMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.participantLocations != oldWidget.participantLocations ||
        widget.currentUserLocation != oldWidget.currentUserLocation) {
      _calculateMapCenter();
      _createMarkers();
    }
  }

  void _calculateMapCenter() {
    final allLocations = <LatLng>[];

    // Add participant locations
    for (final location in widget.participantLocations) {
      allLocations.add(location.position);
    }

    // Add current user location if available and should be shown
    if (widget.showCurrentUserLocation && widget.currentUserLocation != null) {
      allLocations.add(widget.currentUserLocation!);
    }

    if (allLocations.isNotEmpty) {
      // Calculate center of all locations
      double totalLat = 0;
      double totalLng = 0;

      for (final location in allLocations) {
        totalLat += location.latitude;
        totalLng += location.longitude;
      }

      _mapCenter = LatLng(
        totalLat / allLocations.length,
        totalLng / allLocations.length,
      );
    } else {
      // Default to a general location if no locations available
      _mapCenter = const LatLng(20.0, 0.0); // Center of the world
    }
  }

  void _createMarkers() {
    _markers.clear();
    _circles.clear();

    // Add current user location marker (if not already in participant list)
    if (widget.showCurrentUserLocation && widget.currentUserLocation != null) {
      // Check if current user is already in participant locations
      final currentUserInParticipants = widget.participantLocations.any(
        (location) => location.userId == widget.currentUserId,
      );

      if (!currentUserInParticipants) {
        final userMarkerId = MarkerId('current_user_location');
        _markers.add(
          Marker(
            markerId: userMarkerId,
            position: widget.currentUserLocation!,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueBlue,
            ),
            infoWindow: const InfoWindow(
              title: 'Your Location',
              snippet: 'You are here',
            ),
          ),
        );

        // Add accuracy circle for current user location
        final userCircleId = CircleId('current_user_accuracy');
        _circles.add(
          Circle(
            circleId: userCircleId,
            center: widget.currentUserLocation!,
            radius: 50, // Default 50m accuracy circle
            fillColor: Colors.blue.withValues(alpha: 0.1),
            strokeColor: Colors.blue.withValues(alpha: 0.3),
            strokeWidth: 2,
          ),
        );
      }
    }

    // Add participant markers (owner and collaborators)
    for (int i = 0; i < widget.participantLocations.length; i++) {
      final location = widget.participantLocations[i];
      final markerId = MarkerId('participant_${location.userId}');

      // Determine marker color and title based on role
      BitmapDescriptor markerIcon;
      String markerTitle;
      String markerSnippet;

      if (location.userId == widget.taskOwnerId) {
        // Task owner - purple/gold marker
        markerIcon = BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueViolet,
        );
        markerTitle = 'Task Owner';
        markerSnippet = location.isOnline
            ? 'Owner - Online'
            : 'Owner - Last seen: ${_formatLastSeen(location.lastSeen)}';
      } else if (location.userId == widget.currentUserId) {
        // Current user - blue marker
        markerIcon = BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueBlue,
        );
        markerTitle = 'You';
        markerSnippet = location.isOnline
            ? 'You - Online'
            : 'You - Last seen: ${_formatLastSeen(location.lastSeen)}';
      } else {
        // Other collaborators - green/orange
        markerIcon = BitmapDescriptor.defaultMarkerWithHue(
          location.isOnline
              ? BitmapDescriptor.hueGreen
              : BitmapDescriptor.hueOrange,
        );
        markerTitle = location.email ?? 'Collaborator';
        markerSnippet = location.isOnline
            ? 'Collaborator - Online'
            : 'Collaborator - Last seen: ${_formatLastSeen(location.lastSeen)}';
      }

      _markers.add(
        Marker(
          markerId: markerId,
          position: location.position,
          icon: markerIcon,
          infoWindow: InfoWindow(
            title: markerTitle,
            snippet: markerSnippet,
            onTap: () => _showParticipantInfo(context, location),
          ),
        ),
      );

      // Add accuracy circle if accuracy is available
      if (location.accuracy != null && location.accuracy! > 0) {
        final circleId = CircleId('participant_accuracy_${location.userId}');
        Color circleColor;
        if (location.userId == widget.taskOwnerId) {
          circleColor = Colors.purple;
        } else if (location.userId == widget.currentUserId) {
          circleColor = Colors.blue;
        } else {
          circleColor = location.isOnline ? Colors.green : Colors.orange;
        }

        _circles.add(
          Circle(
            circleId: circleId,
            center: location.position,
            radius: location.accuracy!,
            fillColor: circleColor.withValues(alpha: 0.1),
            strokeColor: circleColor.withValues(alpha: 0.3),
            strokeWidth: 1,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_mapCenter == null) {
      return Container(
        height: widget.height ?? 300,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      height: widget.height ?? 300,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: _mapCenter!,
            zoom: 13.0,
          ),
          markers: _markers,
          circles: _circles,
          mapType: MapType.normal,
          myLocationEnabled: false, // We handle location manually
          myLocationButtonEnabled: false, // We have custom controls
          zoomControlsEnabled: false, // We have custom controls
          onMapCreated: (GoogleMapController controller) {
            _mapController = controller;
          },
          onTap: (LatLng position) {
            // Handle map tap if needed
          },
        ),
      ),
    );
  }

  void _showParticipantInfo(BuildContext context, UserLocation location) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: location.isOnline
                        ? Colors.green.withValues(alpha: 0.8)
                        : Colors.grey.withValues(alpha: 0.8),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    location.email ?? 'Unknown User',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              location.isOnline
                  ? 'Online'
                  : 'Last seen: ${_formatLastSeen(location.lastSeen)}',
              style: TextStyle(
                color: location.isOnline ? Colors.green : Colors.grey,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Location: ${location.position.latitude.toStringAsFixed(4)}, ${location.position.longitude.toStringAsFixed(4)}',
              style: const TextStyle(fontSize: 14),
            ),
            if (location.accuracy != null) ...[
              const SizedBox(height: 4),
              Text(
                'Accuracy: ±${location.accuracy!.toStringAsFixed(0)}m',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Updated: ${_formatTimestamp(location.timestamp)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  String _formatLastSeen(DateTime? lastSeen) {
    if (lastSeen == null) return 'Unknown';

    final now = DateTime.now();
    final difference = now.difference(lastSeen);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';

    return lastSeen.toString().split(' ')[0]; // Date only
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes} minutes ago';
    if (difference.inHours < 24) return '${difference.inHours} hours ago';
    if (difference.inDays < 7) return '${difference.inDays} days ago';

    return timestamp.toString().split(' ')[0]; // Date only
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
