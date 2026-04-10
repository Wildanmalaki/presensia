// warning: in the working copy of 'lib/view/homepage.dart', LF will be replaced by CRLF the next time Git touches it
// warning: in the working copy of 'lib/view/widgets/attendance_tab.dart', LF will be replaced by CRLF the next time Git touches it
// [1mdiff --git a/lib/view/homepage.dart b/lib/view/homepage.dart[m
// [1mindex 410d2dc..5099fe5 100644[m
// [1m--- a/lib/view/homepage.dart[m
// [1m+++ b/lib/view/homepage.dart[m
// [36m@@ -23,7 +23,7 @@[m [mclass HomePage extends StatefulWidget {[m
//  class _HomePageState extends State<HomePage> {[m
//    static const double _ppkdLatitude = -6.2108808;[m
//    static const double _ppkdLongitude = 106.8129424;[m
// [31m-  static const double _attendanceRadiusMeters = 4000000000000000000;[m
// [32m+[m[32m  static const double _attendanceRadiusMeters = 400;[m
//  [m
//    final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();[m
//    int _selectedIndex = 0;[m
// [36m@@ -241,6 +241,13 @@[m [mclass _HomePageState extends State<HomePage> {[m
//  [m
//    Future<void> _handleCheckIn() async {[m
//      if (_isAttendanceLoading) return;[m
// [32m+[m[32m    if (!_canSubmitAttendance) {[m
// [32m+[m[32m      _showMessage([m
// [32m+[m[32m        context,[m
// [32m+[m[32m        _attendanceBlockedMessage,[m
// [32m+[m[32m      );[m
// [32m+[m[32m      return;[m
// [32m+[m[32m    }[m
//  [m
//      setState(() {[m
//        _isAttendanceLoading = true;[m
// [36m@@ -266,6 +273,13 @@[m [mclass _HomePageState extends State<HomePage> {[m
//  [m
//    Future<void> _handleCheckOut() async {[m
//      if (_isAttendanceLoading) return;[m
// [32m+[m[32m    if (!_canSubmitAttendance) {[m
// [32m+[m[32m      _showMessage([m
// [32m+[m[32m        context,[m
// [32m+[m[32m        _attendanceBlockedMessage,[m
// [32m+[m[32m      );[m
// [32m+[m[32m      return;[m
// [32m+[m[32m    }[m
//  [m
//      setState(() {[m
//        _isAttendanceLoading = true;[m
// [36m@@ -343,6 +357,12 @@[m [mclass _HomePageState extends State<HomePage> {[m
//          (_todayData?['data']?['check_out_time']?.toString().trim().isNotEmpty ==[m
//          true);[m
//  [m
// [32m+[m[32m    if (!_canSubmitAttendance && (status == null || status.isEmpty)) {[m
// [32m+[m[32m      return 'Absen hanya tersedia dalam radius 400 meter dari lokasi yang ditentukan.';[m
// [32m+[m[32m    }[m
// [32m+[m[32m    if (!_canSubmitAttendance && status == 'masuk' && !hasCheckOut) {[m
// [32m+[m[32m      return 'Absen keluar hanya tersedia dalam radius 400 meter dari lokasi yang ditentukan.';[m
// [32m+[m[32m    }[m
//      if (status == null || status.isEmpty) {[m
//        return 'Tap untuk melakukan absen masuk.';[m
//      }[m
// [36m@@ -362,14 +382,33 @@[m [mclass _HomePageState extends State<HomePage> {[m
//          true);[m
//  [m
//      if (status == null || status.isEmpty) {[m
// [32m+[m[32m      if (!_canSubmitAttendance) {[m
// [32m+[m[32m        return null;[m
// [32m+[m[32m      }[m
//        return _handleCheckIn;[m
//      }[m
//      if (status == 'masuk' && !hasCheckOut) {[m
// [32m+[m[32m      if (!_canSubmitAttendance) {[m
// [32m+[m[32m        return null;[m
// [32m+[m[32m      }[m
//        return _handleCheckOut;[m
//      }[m
//      return null;[m
//    }[m
//  [m
// [32m+[m[32m  bool get _canSubmitAttendance {[m
// [32m+[m[32m    final distance = _distanceToPpkdMeters;[m
// [32m+[m[32m    return distance != null && distance <= _attendanceRadiusMeters;[m
// [32m+[m[32m  }[m
// [32m+[m
// [32m+[m[32m  String get _attendanceBlockedMessage {[m
// [32m+[m[32m    final distance = _distanceToPpkdMeters;[m
// [32m+[m[32m    if (distance == null) {[m
// [32m+[m[32m      return 'Lokasi belum tersedia. Aktifkan GPS dan izinkan akses lokasi untuk absen.';[m
// [32m+[m[32m    }[m
// [32m+[m[32m    return 'Anda berada di luar radius 400 meter. Jarak saat ini ${distance.round()} meter dari lokasi absensi.';[m
// [32m+[m[32m  }[m
// [32m+[m
//    @override[m
//    Widget build(BuildContext context) {[m
//      final appTheme = MyApp.of(context);[m
// [36m@@ -593,7 +632,7 @@[m [mclass _HomePageState extends State<HomePage> {[m
//  [m
//      setState(() {[m
//        _distanceToPpkdMeters = distance;[m
// [31m-      _isWithinAttendanceZone = true;[m
// [32m+[m[32m      _isWithinAttendanceZone = distance <= _attendanceRadiusMeters;[m
//      });[m
//    }[m
//  [m
// [1mdiff --git a/lib/view/widgets/attendance_tab.dart b/lib/view/widgets/attendance_tab.dart[m
// [1mindex 1cda732..6a2f057 100644[m
// [1m--- a/lib/view/widgets/attendance_tab.dart[m
// [1m+++ b/lib/view/widgets/attendance_tab.dart[m
// [36m@@ -34,7 +34,8 @@[m [mclass _AttendanceTabState extends State<AttendanceTab> {[m
//    final Set<Marker> _markers = {};[m
//    bool _isLoadingLocation = true;[m
//    bool _hasLocationPermission = false;[m
// [31m-  bool _isWithinZone = true;[m
// [32m+[m[32m  bool _isWithinZone = false;[m
// [32m+[m[32m  double? _distanceToTargetMeters;[m
//    String _currentAddress =[m
//        'Pusat Pelatihan Kerja Daerah Jakarta Pusat (Bendungan Hilir)';[m
//    String _addressDetails = 'Jalan: 15 Menit dari kantor pusat';[m
// [36m@@ -167,6 +168,13 @@[m [mclass _AttendanceTabState extends State<AttendanceTab> {[m
//  [m
//    void _addMarker() {[m
//      _markers.clear();[m
// [32m+[m[32m    _markers.add([m
// [32m+[m[32m      const Marker([m
// [32m+[m[32m        markerId: MarkerId('attendance_target'),[m
// [32m+[m[32m        position: LatLng(_ppkdLatitude, _ppkdLongitude),[m
// [32m+[m[32m        infoWindow: InfoWindow(title: 'Titik lokasi absensi'),[m
// [32m+[m[32m      ),[m
// [32m+[m[32m    );[m
//      _markers.add([m
//        Marker([m
//          markerId: const MarkerId('current_location'),[m
// [36m@@ -185,7 +193,14 @@[m [mclass _AttendanceTabState extends State<AttendanceTab> {[m
//    }[m
//  [m
//    void _updateZoneStatus(LatLng target) {[m
// [31m-    _isWithinZone = true;[m
// [32m+[m[32m    final distance = Geolocator.distanceBetween([m
// [32m+[m[32m      target.latitude,[m
// [32m+[m[32m      target.longitude,[m
// [32m+[m[32m      _ppkdLatitude,[m
// [32m+[m[32m      _ppkdLongitude,[m
// [32m+[m[32m    );[m
// [32m+[m[32m    _distanceToTargetMeters = distance;[m
// [32m+[m[32m    _isWithinZone = distance <= _attendanceRadiusMeters;[m
//    }[m
//  [m
//    String _formatTime(DateTime dateTime) {[m
// [36m@@ -436,13 +451,28 @@[m [mclass _AttendanceTabState extends State<AttendanceTab> {[m
//                                      ),[m
//                                      const SizedBox(height: 6),[m
//                                      Text([m
// [31m-                                      'Bisa Absen',[m
// [32m+[m[32m                                      _isWithinZone[m
// [32m+[m[32m                                          ? 'Bisa Absen'[m
// [32m+[m[32m                                          : 'Di Luar Area',[m
//                                        style: theme.textTheme.titleMedium[m
//                                            ?.copyWith([m
// [31m-                                            color: const Color(0xFF29A35A),[m
// [32m+[m[32m                                            color: _isWithinZone[m
// [32m+[m[32m                                                ? const Color(0xFF29A35A)[m
// [32m+[m[32m                                                : const Color(0xFFE8515B),[m
//                                              fontWeight: FontWeight.w800,[m
//                                            ),[m
//                                      ),[m
// [32m+[m[32m                                    if (_distanceToTargetMeters != null) ...[[m
// [32m+[m[32m                                      const SizedBox(height: 4),[m
// [32m+[m[32m                                      Text([m
// [32m+[m[32m                                        '${_distanceToTargetMeters!.round()} meter dari titik absen',[m
// [32m+[m[32m                                        style: theme.textTheme.bodySmall[m
// [32m+[m[32m                                            ?.copyWith([m
// [32m+[m[32m                                              color: palette.textSecondary,[m
// [32m+[m[32m                                              fontWeight: FontWeight.w600,[m
// [32m+[m[32m                                            ),[m
// [32m+[m[32m                                      ),[m
// [32m+[m[32m                                    ],[m
//                                    ],[m
//                                  ),[m
//                                ),[m
// [36m@@ -456,15 +486,15 @@[m [mclass _AttendanceTabState extends State<AttendanceTab> {[m
//                            width: double.infinity,[m
//                            height: 50,[m
//                            child: ElevatedButton.icon([m
// [31m-                            onPressed: () {[m
// [32m+[m[32m                            onPressed: _isWithinZone ? () {[m
//                                ScaffoldMessenger.of(context).showSnackBar([m
// [31m-                                const SnackBar([m
// [32m+[m[32m                                SnackBar([m
//                                    content: Text([m
// [31m-                                    'Validasi radius lokasi dinonaktifkan sementara.',[m
// [32m+[m[32m                                    'Lokasi valid. Anda berada dalam radius 400 meter.',[m
//                                    ),[m
//                                  ),[m
//                                );[m
// [31m-                            },[m
// [32m+[m[32m                            } : null,[m
//                              style: ElevatedButton.styleFrom([m
//                                backgroundColor: palette.primary,[m
//                                foregroundColor: Colors.white,[m
// [36m@@ -474,7 +504,9 @@[m [mclass _AttendanceTabState extends State<AttendanceTab> {[m
//                              ),[m
//                              icon: const Icon(Icons.check_circle_outline),[m
//                              label: Text([m
// [31m-                              'Absensi Tersedia',[m
// [32m+[m[32m                              _isWithinZone[m
// [32m+[m[32m                                  ? 'Absensi Tersedia'[m
// [32m+[m[32m                                  : 'Absensi Tidak Tersedia',[m
//                                style: theme.textTheme.titleMedium?.copyWith([m
//                                  color: Colors.white,[m
//                                  fontWeight: FontWeight.w800,[m
