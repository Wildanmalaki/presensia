import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:presensia/theme/app_theme.dart';

class AttendanceTab extends StatefulWidget {
  const AttendanceTab({
    super.key,
    required this.statsData,
    required this.todayData,
    required this.onRefresh,
  });

  final Map<String, dynamic>? statsData;
  final Map<String, dynamic>? todayData;
  final Future<void> Function() onRefresh;

  @override
  State<AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<AttendanceTab> {
  static const double _ppkdLatitude = -6.2108808;
  static const double _ppkdLongitude = 106.8129424;
  static const double _attendanceRadiusMeters = 400;

  GoogleMapController? _mapController;
  LatLng? _cameraTarget;
  LatLng _currentLocation = const LatLng(
    -6.200000,
    106.816666,
  ); // Default: Jakarta
  final Set<Marker> _markers = {};
  bool _isLoadingLocation = true;
  bool _hasLocationPermission = false;
  bool _isWithinZone = false;
  double? _distanceToTargetMeters;
  String _currentAddress =
      'Pusat Pelatihan Kerja Daerah Jakarta Pusat (Bendungan Hilir)';
  String _addressDetails = 'Jalan: 15 Menit dari kantor pusat';
  StreamSubscription<Position>? _positionStreamSubscription;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    try {
      debugPrint('🔄 Starting location initialization...');
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      debugPrint('📡 Location service enabled: $serviceEnabled');

      var permission = await Geolocator.checkPermission();
      debugPrint('🔐 Permission status: $permission');

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        debugPrint('🔐 Permission requested: $permission');
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('❌ Permission denied, using default location');
        if (mounted) {
          setState(() {
            _hasLocationPermission = false;
            _addMarker();
            _isLoadingLocation = false;
          });
        }
        return;
      }

      _hasLocationPermission = true;
      debugPrint('✅ Permission granted');
      Position? position;

      if (serviceEnabled) {
        position = await Geolocator.getLastKnownPosition();
        debugPrint('📍 Last known position: $position');

        if (position == null) {
          debugPrint('🌍 Getting current position...');
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 10),
          );
          debugPrint('📍 Current position: $position');
        }
      }

      if (position != null) {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _syncLocationLabel(_currentLocation);
        _updateZoneStatus(_currentLocation);
        debugPrint('📌 Updated location: $_currentLocation');
      }

      if (mounted) {
        setState(() {
          _addMarker();
          _isLoadingLocation = false;
        });
      }

      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted && _mapController != null) {
        debugPrint('🎬 Animating camera to: $_currentLocation');
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(_currentLocation, 16),
        );
      }

      // ✅ Start listening to real-time location updates
      _startLocationStream();
    } catch (e) {
      debugPrint('⚠️ Error initializing location: $e');
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
          _addMarker();
        });
      }
    }
  }

  // ✅ NEW: Real-time location stream listener
  void _startLocationStream() {
    debugPrint('🔔 Starting real-time location stream...');
    _positionStreamSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10, // Update kalo sudah bergerak 10 meter
          ),
        ).listen(
          (Position position) {
            debugPrint(
              '📍 Location updated: ${position.latitude}, ${position.longitude}',
            );
            if (mounted) {
              setState(() {
                _currentLocation = LatLng(
                  position.latitude,
                  position.longitude,
                );
                _syncLocationLabel(_currentLocation);
                _updateZoneStatus(_currentLocation);
                _addMarker();

                // Auto-update map camera
                if (_mapController != null) {
                  _mapController!.animateCamera(
                    CameraUpdate.newLatLngZoom(_currentLocation, 16),
                  );
                }
              });
            }
          },
          onError: (e) {
            debugPrint('❌ Location stream error: $e');
          },
        );
  }

  void _addMarker() {
    _markers.clear();
    _markers.add(
      const Marker(
        markerId: MarkerId('attendance_target'),
        position: LatLng(_ppkdLatitude, _ppkdLongitude),
        infoWindow: InfoWindow(title: 'Titik lokasi absensi'),
      ),
    );
    _markers.add(
      Marker(
        markerId: const MarkerId('current_location'),
        position: _currentLocation,
        infoWindow: const InfoWindow(title: 'YOU ARE HERE'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
    );
  }

  void _syncLocationLabel(LatLng target) {
    final lat = target.latitude.toStringAsFixed(6);
    final lng = target.longitude.toStringAsFixed(6);
    _currentAddress = 'PPKD Jakarta Pusat (Bendungan Hilir)';
    _addressDetails = 'Posisi map: $lat, $lng';
  }

  void _updateZoneStatus(LatLng target) {
    final distance = Geolocator.distanceBetween(
      target.latitude,
      target.longitude,
      _ppkdLatitude,
      _ppkdLongitude,
    );
    _distanceToTargetMeters = distance;
    _isWithinZone = distance <= _attendanceRadiusMeters;
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime dateTime) {
    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    final day = days[dateTime.weekday - 1];
    final month = months[dateTime.month - 1];
    return '$day - ${dateTime.day.toString().padLeft(2, '0')} $month \'${dateTime.year.toString().substring(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final theme = Theme.of(context);
    final palette = context.appPalette;

    return SizedBox.expand(
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // Google Map
          Positioned.fill(
            child: GoogleMap(
              onMapCreated: (controller) {
                _mapController = controller;
                debugPrint('✅ Map created successfully');
                if (!_isLoadingLocation) {
                  _mapController!.animateCamera(
                    CameraUpdate.newLatLngZoom(_currentLocation, 16),
                  );
                }
              },
              onCameraMove: (position) {
                _cameraTarget = position.target;
                debugPrint('📍 Camera moved to: ${position.target}');
              },
              onCameraIdle: () {
                final target = _cameraTarget;
                if (target == null || !mounted) return;
                setState(() {
                  _currentLocation = target;
                  _syncLocationLabel(target);
                  _updateZoneStatus(target);
                  _addMarker();
                });
              },
              initialCameraPosition: CameraPosition(
                target: _currentLocation,
                zoom: 16,
              ),
              markers: _markers,
              myLocationEnabled: _hasLocationPermission,
              myLocationButtonEnabled: _hasLocationPermission,
              zoomControlsEnabled: false,
              mapType: MapType.normal,
            ),
          ),

          // Loading indicator
          if (_isLoadingLocation)
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: palette.border),
                ),
                child: const CircularProgressIndicator(),
              ),
            ),

          // Bottom card with location details
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SingleChildScrollView(
              child: Container(
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    border: Border(top: BorderSide(color: palette.border)),
                    boxShadow: [
                      BoxShadow(
                        color: palette.shadow,
                        blurRadius: 24,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Verified Location Header
                        Text(
                          'VERIFIED LOCATION',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: palette.primaryStrong,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Current Time
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _currentAddress,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          color: palette.textPrimary,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _addressDetails,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: palette.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _formatTime(now),
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                        color: const Color(0xFF2E7BEF),
                                        fontWeight: FontWeight.w800,
                                        height: 1,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatDate(now),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: palette.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Status Grid
                        Row(
                          children: [
                            // Shift Starts
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: palette.surfaceMuted,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Masuk jam pelatihan',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: palette.textSecondary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '8.00 WIB',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            color: palette.textPrimary,
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Status
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: _isWithinZone
                                      ? palette.successSurface
                                      : palette.dangerSurface,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'STATUS',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: _isWithinZone
                                                ? const Color(0xFF29A35A)
                                                : const Color(0xFFE8515B),
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _isWithinZone
                                          ? 'Bisa Absen'
                                          : 'Di Luar Area',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            color: _isWithinZone
                                                ? const Color(0xFF29A35A)
                                                : const Color(0xFFE8515B),
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    if (_distanceToTargetMeters != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        '${_distanceToTargetMeters!.round()} meter dari titik absen',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: palette.textSecondary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Confirm Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _isWithinZone ? () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Lokasi valid. Anda berada dalam radius 400 meter.',
                                  ),
                                ),
                              );
                            } : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: palette.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.check_circle_outline),
                            label: Text(
                              _isWithinZone
                                  ? 'Absensi Tersedia'
                                  : 'Absensi Tidak Tersedia',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Disclaimer
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: palette.surfaceMuted,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'DATA KEHADIRAN AKAN DISIMPAN DAN DIGUNAKAN UNTUK KEPERLUAN VERIFIKASI GPS & BIOMETRIC',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: palette.textSecondary,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }
}
