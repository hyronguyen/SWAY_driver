import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:sway_driver/config/colors.dart';
import 'package:http/http.dart' as http;
import 'package:sway_driver/config/icon.dart';
import 'package:sway_driver/page/trip_tracking/to_destination.dart';

class PickingUpPage extends StatefulWidget {
  // ATTRIBUTES/////////////////////////////////////////////////////////////////////////////////////////////////////////
  final String trackingTripId;
  final String driverID;
  final LatLng pickupLocation;
  final LatLng destinationLocation;

  const PickingUpPage(
      {Key? key, required this.trackingTripId, required this.driverID, required this.pickupLocation, required this.destinationLocation})
      : super(key: key);

  @override
  _PickingUpPageState createState() => _PickingUpPageState();
}

class _PickingUpPageState extends State<PickingUpPage> {
// LOCAL VARIBLE /////////////////////////////////////////////////////////////////////////////////////////////////////////
  Map<String, dynamic>? trackingTripData;
  bool isLoading = true;
  LatLng? driverLocation;
  StreamSubscription<DocumentSnapshot>? driverLocationSubscription;
  int countdown = 20;
  List<LatLng> routePoints = [];
  final MapController _mapController = MapController();
  final String mapBoxToken =
      'pk.eyJ1IjoiaG90aGFuaGdpYW5nOSIsImEiOiJjbTd6azNwbmYwazQ5MmxzZm10cmJ2OHplIn0.FnRAAi3J7jVs4FxUhd1KAA';
  bool isDriverAtPickup = false; // Biến kiểm soát trạng thái nút
  Timer? autoConfirmTimer; // Timer để xác nhận tự động
  Timer? countdownTimer;

// LIFE CYCLE /////////////////////////////////////////////////////////////////////////////////////////////////////////
  @override
  void initState() {
    super.initState();
    _fetchTrackingTrip();
    _listenToDriverLocation();
  }

  @override
  void dispose() {
    // Hủy Timer khi widget bị huỷ
    super.dispose();
  }

// FUNCTION/////////////////////////////////////////////////////////////////////////////////////////////////////////

  // Vẽ đường
  void _drawRoute() async {
    if (driverLocation == null || trackingTripData == null) return;

    final pickup = trackingTripData!['pickup_location'];
    if (pickup == null ||
        pickup['latitude'] == null ||
        pickup['longitude'] == null) {
      debugPrint("🚨 Không tìm thấy vị trí đón khách");
      return;
    }

    final String url = 'https://api.mapbox.com/directions/v5/mapbox/driving/'
        '${driverLocation!.longitude},${driverLocation!.latitude};'
        '${pickup['longitude']},${pickup['latitude']}'
        '?geometries=geojson&access_token=$mapBoxToken';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List coordinates = data['routes'][0]['geometry']['coordinates'];

        setState(() {
          routePoints =
              coordinates.map((coord) => LatLng(coord[1], coord[0])).toList();
        });
      } else {
        debugPrint("❌ Lỗi khi lấy tuyến đường: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("❌ Lỗi khi gọi API Mapbox: $e");
    }
  }

  // Lấy thông tin tracking
  Future<void> _fetchTrackingTrip() async {
    try {
      DocumentSnapshot tripDoc = await FirebaseFirestore.instance
          .collection('TRACKING_TRIP')
          .doc(widget.trackingTripId)
          .get();

      if (tripDoc.exists) {
        setState(() {
          trackingTripData = tripDoc.data() as Map<String, dynamic>;
          isLoading = false;
        });
      } else {
        debugPrint("⚠️ Không tìm thấy TRACKING_TRIP!");
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint("🔥 Lỗi khi lấy TRACKING_TRIP: $e");
      setState(() => isLoading = false);
    }
  }

  // Theo dõi vị trí tài xế
  void _listenToDriverLocation() {
    driverLocationSubscription = FirebaseFirestore.instance
        .collection('AVAILABLE_DRIVERS')
        .doc(widget.driverID)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.exists) {
        var data = snapshot.data();
        if (data != null &&
            data['latitude'] != null &&
            data['longitude'] != null) {
          LatLng newLocation = LatLng(data['latitude'], data['longitude']);

          setState(() {
            driverLocation = newLocation;
          });

          Move(newLocation);
          _drawRoute(); // Gọi hàm vẽ đường

          // Kiểm tra tài xế có đến gần điểm đón không
          Future.delayed(Duration(seconds: 1), _checkDriverProximity);
        }
      }
    });
  }

// Kiểm tra tài xế có trong bán kính 20m của điểm đón không
  void _checkDriverProximity() {
    if (driverLocation == null || trackingTripData == null) return;

    final pickup = trackingTripData!['pickup_location'];
    if (pickup == null ||
        pickup['latitude'] == null ||
        pickup['longitude'] == null) return;

    LatLng pickupLocation = LatLng(pickup['latitude'], pickup['longitude']);

    double distance = Geolocator.distanceBetween(
      driverLocation!.latitude,
      driverLocation!.longitude,
      pickupLocation.latitude,
      pickupLocation.longitude,
    );

    debugPrint("📏 Khoảng cách đến điểm đón: ${distance.toStringAsFixed(2)}m");

    if (distance <= 50 && !isDriverAtPickup) {
      debugPrint("🚖 Tài xế đã đến điểm đón!");

      setState(() {
        isDriverAtPickup = true;
      });

      countdownTimer?.cancel();
      countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
        if (countdown > 0) {
          setState(() {
            countdown--;
          });
        } else {
          timer.cancel(); // Dừng đếm khi hết thời gian
        }
      });

      // Tự động xác nhận nếu tài xế không bấm nút sau 20 giây
      autoConfirmTimer?.cancel(); // Hủy timer cũ (nếu có)
      autoConfirmTimer = Timer(Duration(seconds: 20), () {
        if (isDriverAtPickup) {
          debugPrint("⌛ Khách đã lên xe (tự động xác nhận sau 20s)");
          _confirmPickup();
        }
      });
    }
  }

  // Xác nhận tài xế đã đón khách
  void _confirmPickup() async {
    debugPrint("✅ Khách đã lên xe (tài xế bấm nút)");

    // Hủy tất cả các sự kiện lắng nghe
    _disposeListeners();

    // Cập nhật trạng thái của TRACKING_TRIP trên Firestore
    await FirebaseFirestore.instance
        .collection('TRACKING_TRIP')
        .doc(widget.trackingTripId)
        .update({'tracking_status': 'goingtodes'}).then((_) {
      debugPrint("🚀 Cập nhật tracking_status thành công!");
    }).catchError((error) {
      debugPrint("❌ Lỗi khi cập nhật tracking_status: $error");
    });

    // Chuyển sang màn hình ToDestinationPage
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ToDestinationPage(
          trackingTripId: widget.trackingTripId,
          driverID: widget.driverID ?? '',
          destinationLocation: widget.destinationLocation
        ),
      ),
    );

    // Hủy tự động xác nhận nếu tài xế bấm nút trước
    autoConfirmTimer?.cancel();
  }

  // Di chuyển bản đồ theo tài xế
  void Move(LatLng newLocation) {
    final zoom = _mapController.camera.zoom;
    _mapController.move(newLocation, zoom);
  }

  /// Hủy tất cả sự kiện lắng nghe
  void _disposeListeners() {
    autoConfirmTimer?.cancel(); // Hủy Timer nếu có

    // Hủy lắng nghe vị trí tài xế
    driverLocationSubscription?.cancel();
    driverLocationSubscription = null;

    debugPrint("🛑 Đã hủy tất cả sự kiện lắng nghe!");
  }

// LAYOUT //////////////////////////////////////////////
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("VUI LÒNG ĐÓN KHÁCH"),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // 📍 Hiển thị bản đồ với vị trí tài xế và tuyến đường
          Expanded(
            flex: 3,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: const LatLng(10.7769, 106.7009),
                initialZoom: 16,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://api.mapbox.com/styles/v1/hothanhgiang9/cm6n57t2u007201sg15ac9swb/tiles/256/{z}/{x}/{y}@2x?access_token=$mapBoxToken',
                ),
                if (driverLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: driverLocation!,
                        width: 50,
                        height: 50,
                        child: point_icon,
                      ),

                      Marker(
                        point: widget.pickupLocation,
                        width: 50,
                        height: 50,
                        child: man_icon
                      ), 
                    ],
                  ),
                if (routePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: routePoints,
                        color: path,
                        strokeWidth: 5.0,
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // Thông tin chuyến đi
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: backgroundblack,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 5)],
              ),
              child: Column(
                children: [
                  // Cuộn nội dung tránh overflow
                  Expanded(
                    child: SingleChildScrollView(
                      child: isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : trackingTripData == null
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(20),
                                    child: Text(
                                      'Không tìm thấy dữ liệu chuyến đi',
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('📍 Đang đón khách',
                                        style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold)),
                                    SizedBox(height: 10),
                                    Text(
                                        '👤 Khách hàng: ${trackingTripData!['customer_id'] ?? 'N/A'}'),
                                    Text(
                                        '📍 Điểm đón: ${trackingTripData!['pickup_location'] ?? 'N/A'}'),
                                    Text(
                                        '🏁 Điểm đến: ${trackingTripData!['destination_location'] ?? 'N/A'}'),
                                    Text(
                                        '📅 Thời gian: ${trackingTripData!['timestamp'] ?? 'N/A'}'),
                                    Text(
                                        'Trạng thái: ${trackingTripData!['tracking_status'] ?? 'N/A'}'),
                                    SizedBox(height: 10),
                                    Divider(),
                                    Text("🚖 Vị trí hiện tại của tài xế:",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    SizedBox(height: 5),
                                    driverLocation == null
                                        ? Text("🔍 Đang tải vị trí tài xế...")
                                        : Text(
                                            "📍 ${driverLocation!.latitude}, ${driverLocation!.longitude}"),
                                  ],
                                ),
                    ),
                  ),

                  // Thanh chứa các nút
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min, // Giúp tránh overflow
                      children: [
                        // Hàng chứa 3 nút icon
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Flexible(
                              child: IconButton(
                                icon: Icon(Icons.phone,
                                    color: Colors.green, size: 30),
                                onPressed: () {
                                  debugPrint("Gọi khách hàng");
                                },
                              ),
                            ),
                            Flexible(
                              child: IconButton(
                                icon: Icon(Icons.message,
                                    color: Colors.blue, size: 30),
                                onPressed: () {
                                  debugPrint("Nhắn tin cho khách hàng");
                                },
                              ),
                            ),
                            Flexible(
                              child: IconButton(
                                icon: Icon(Icons.more_horiz,
                                    color: Colors.white, size: 30),
                                onPressed: () {
                                  debugPrint("Xem thêm");
                                },
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 10),

                        // Nút "Đã xác nhận" đón khách
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isDriverAtPickup
                                ? _confirmPickup
                                : null, // Nếu chưa đến điểm đón, vô hiệu hóa nút
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDriverAtPickup
                                  ? Colors.green
                                  : greymenu, // Đổi màu nếu kích hoạt
                              padding: EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              isDriverAtPickup
                                  ? "Khách lên xe (${countdown}s)"
                                  : "Khách lên xe",
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
