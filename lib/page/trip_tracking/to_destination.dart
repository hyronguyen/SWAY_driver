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
import 'package:sway_driver/page/wallet/done.dart';

class ToDestinationPage extends StatefulWidget {
  // ATTRIBUTES/////////////////////////////////////////////////////////////////////////////////////////////////////////
  final String trackingTripId;
  final String driverID;
  final LatLng destinationLocation;

  const ToDestinationPage(
      {Key? key, required this.trackingTripId, required this.driverID, required this.destinationLocation})
      : super(key: key);

  @override
  _ToDestinationPageState createState() => _ToDestinationPageState();
}

class _ToDestinationPageState extends State<ToDestinationPage> {
// LOCAL VARIBLE /////////////////////////////////////////////////////////////////////////////////////////////////////////
  Map<String, dynamic>? trackingTripData;
  bool isLoading = true;
  LatLng? driverLocation;
  StreamSubscription<DocumentSnapshot>? driverLocationSubscription;
  List<LatLng> routePoints = [];
  final MapController _mapController = MapController();
  final String mapBoxToken =
      'pk.eyJ1IjoiaG90aGFuaGdpYW5nOSIsImEiOiJjbTd6azNwbmYwazQ5MmxzZm10cmJ2OHplIn0.FnRAAi3J7jVs4FxUhd1KAA';
  bool isDriverAtDes = false; // Biến kiểm soát trạng thái nút
  Timer? autoConfirmTimer; // Timer để xác nhận tự động
  int countdown = 20;
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

    final destination = trackingTripData!['destination_location'];
    if (destination == null ||
        destination['latitude'] == null ||
        destination['longitude'] == null) {
      debugPrint("🚨 Không tìm thấy diểm đến");
      return;
    }

    final String url = 'https://api.mapbox.com/directions/v5/mapbox/driving/'
        '${driverLocation!.longitude},${driverLocation!.latitude};'
        '${destination['longitude']},${destination['latitude']}'
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

    final destination = trackingTripData!['destination_location'];
    if (destination == null ||
        destination['latitude'] == null ||
        destination['longitude'] == null) return;

    LatLng destinationLocation =
        LatLng(destination['latitude'], destination['longitude']);

    double distance = Geolocator.distanceBetween(
      driverLocation!.latitude,
      driverLocation!.longitude,
      destinationLocation.latitude,
      destinationLocation.longitude,
    );

    debugPrint("📏 Khoảng cách đến điểm đến: ${distance.toStringAsFixed(2)}m");

    if (distance <= 70 && !isDriverAtDes) {
      debugPrint("🚖 Tài xế đã đến điểm điến!");
      setState(() {
        isDriverAtDes = true;
      });

      countdownTimer?.cancel();
      countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
        if (countdown > 0) 
        {
          if(!mounted) return;
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
        if (isDriverAtDes) {
          debugPrint("⌛ hoàn thành cuốc xe (tự động xác nhận sau 20s)");
          _confirmDone();
        }
      });
    }
  }

  // Xác nhận tài xế đã đón khách
  void _confirmDone() async {
    debugPrint("Hoàn thành cuốc xe (tài xế bấm nút)");

    // Hủy tất cả các sự kiện lắng nghe
    _disposeListeners();

    // Cập nhật trạng thái của TRACKING_TRIP trên Firestore
    await FirebaseFirestore.instance
        .collection('TRACKING_TRIP')
        .doc(widget.trackingTripId)
        .update({'tracking_status': 'done'}).then((_) {
      debugPrint("🚀 Cập nhật tracking_status thành công!");
    }).catchError((error) {
      debugPrint("❌ Lỗi khi cập nhật tracking_status: $error");
    });

    // Chuyển sang màn hình ToDestinationPage
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => DonePage(
                tripId: widget.trackingTripId,
              )),
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
        title: Text("Đi ĐẾN ĐIỂM ĐẾN"),
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
                        point: widget.destinationLocation,
                        width: 50,
                        height: 50,
                        child: des_icon,
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

          // 📋 Thông tin chuyến đi
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
                                    Text('Thông tin cuốc xe',
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
                        SizedBox(height: 10),

                        // Nút "Đã xác nhận" đón khách
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isDriverAtDes
                                ? _confirmDone
                                : null, // Nếu chưa đến điểm đón, vô hiệu hóa nút
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDriverAtDes
                                  ? Colors.green
                                  : greymenu, // Đổi màu nếu kích hoạt
                              padding: EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              isDriverAtDes
                                  ? "Hoàn thành cuốc (${countdown}s)"
                                  : "Hoàn thành cuốc",
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
