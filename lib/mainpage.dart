import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:sway_driver/config/colors.dart';
import 'package:sway_driver/page/default.dart';
import 'package:sway_driver/page/home_map.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sway_driver/page/trip_tracking/picking_up.dart';

class DriverMainpage extends StatefulWidget {
  const DriverMainpage({super.key});

  @override
  State<DriverMainpage> createState() => _DriverMainpageState();
}

class _DriverMainpageState extends State<DriverMainpage> {
  //////////////////////////// LOCAL VARIBLE ////////////////////////////////////////////

  bool isTracking = false; // Trạng thái theo dõi vị trí
  String? driverId = "null";
  String? driverVehicle = "null";
  StreamSubscription<Position>? positionSubscription; // Quản lý stream vị trí
  StreamSubscription<QuerySnapshot>? rideRequestSubscription;
  int _selectedIndex = 0;
  AudioPlayer audioplayer = AudioPlayer();
  LatLng? lastPosition;

///////////////////////////// Life Cycle /////////////////////////////////////////////
  @override
  void initState() {
    super.initState();
    getDriverInfo();
    _loadTrackingState();
  }

//////////////////////////// Functions ////////////////////////////////////////////

  // KIỂM TRA CHỨC TRẠNG THÁI CHỨC NĂNG NHẬN CUỐC
  void _loadTrackingState() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool? savedTracking = prefs.getBool('isTracking');

    if (savedTracking != null && savedTracking) {
      setState(() {
        isTracking = true;
      });
      _startListeningLocation(); // Tiếp tục theo dõi vị trí
      _listenForRideRequests(); // Tiếp tục lắng nghe cuốc xe
    }
  }

  // BẬT CHỨC NĂNG NHẬN CUỐC
  void _toggleTracking() async {
    debugPrint("_toggleTracking: ⚡ Bắt đầu toggle tracking...");

    SharedPreferences prefs = await SharedPreferences.getInstance();

    if (!isTracking) {
      debugPrint("_toggleTracking: 📍 Kiểm tra quyền truy cập vị trí...");

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.deniedForever) {
          debugPrint(
              "_toggleTracking: 🚫 Quyền truy cập vị trí bị từ chối vĩnh viễn!");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Quyền truy cập vị trí bị từ chối!")),
          );
          return;
        }
      }

      debugPrint("✅ Quyền truy cập vị trí được cấp!");

      setState(() {
        isTracking = true;
      });

      // 🔥 Lưu trạng thái isTracking vào SharedPreferences
      await prefs.setBool('isTracking', true);

      // 🔥 Bắt đầu theo dõi vị trí của tài xế
      _startListeningLocation();
      _listenForRideRequests();
    } else {
      debugPrint("🛑 Dừng theo dõi vị trí...");

      setState(() {
        isTracking = false;
      });

      // 🔥 Lưu trạng thái isTracking vào SharedPreferences
      await prefs.setBool('isTracking', false);

      positionSubscription?.cancel();
      positionSubscription = null;

      try {
        await FirebaseFirestore.instance
            .collection('AVAILABLE_DRIVERS')
            .doc(driverId)
            .delete();
        debugPrint("🗑️ Tài xế đã bị xóa khỏi Firestore.");
      } catch (e) {
        debugPrint("🔥 Lỗi khi xóa tài xế khỏi Firestore: $e");
      }
      debugPrint("🚫 Đã hủy lắng nghe vị trí.");

      rideRequestSubscription?.cancel();
      rideRequestSubscription = null;
      debugPrint("🚫 Đã hủy chế độ nhận cuốc.");
    }
  }

void _startListeningLocation() async {
  debugPrint("⏳ Bắt đầu nhận vị trí từ Geolocator...");

  try {
    // Lấy vị trí hiện tại ngay khi hàm được gọi
    Position currentPosition = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    LatLng initialLatLng = LatLng(currentPosition.latitude, currentPosition.longitude);

    // Cập nhật lên Firestore ngay lập tức
    await _updateDriverLocation(initialLatLng, true);

    // Sau khi cập nhật vị trí ban đầu, bắt đầu lắng nghe vị trí mới
    positionSubscription = Geolocator.getPositionStream(
      locationSettings: LocationSettings(accuracy: LocationAccuracy.high),
    ).listen((Position position) async {
      LatLng latLng = LatLng(position.latitude, position.longitude);

      // Kiểm tra nếu vị trí không thay đổi đáng kể thì bỏ qua
      if (lastPosition != null) {
        double distance = Geolocator.distanceBetween(
          lastPosition!.latitude, lastPosition!.longitude,
          latLng.latitude, latLng.longitude,
        );

        if (distance < 10) {
          debugPrint("🔹 Vị trí thay đổi không đáng kể (${distance.toStringAsFixed(2)}m), bỏ qua cập nhật.");
          return;
        }
      }

      debugPrint("📌 Nhận vị trí mới: $latLng");

      await _updateDriverLocation(latLng, false);
    }, onError: (error) {
      debugPrint("⚠️ Lỗi khi lắng nghe vị trí: $error");
    });

  } catch (e) {
    debugPrint("🔥 Lỗi khi lấy vị trí ban đầu: $e");
  }
}

// Hàm cập nhật vị trí lên Firestore
Future<void> _updateDriverLocation(LatLng latLng, bool isInitialUpdate) async {
  try {
    DocumentSnapshot driverDoc = await FirebaseFirestore.instance
        .collection('AVAILABLE_DRIVERS')
        .doc(driverId)
        .get();

    if (driverDoc.exists) {
      Map<String, dynamic>? driverData = driverDoc.data() as Map<String, dynamic>?;

      if (driverData != null && (driverData['status'] == "pending" || driverData['status'] == "serving")) {
        await FirebaseFirestore.instance
            .collection('AVAILABLE_DRIVERS')
            .doc(driverId)
            .set({
          'latitude': latLng.latitude,
          'longitude': latLng.longitude,
          'timestamp': FieldValue.serverTimestamp(),
          'vehicle': driverVehicle,
        }, SetOptions(merge: true));

        debugPrint("✅ Cập nhật vị trí thành công, giữ nguyên trạng thái '${driverData['status']}'!");
      } else {
        await FirebaseFirestore.instance
            .collection('AVAILABLE_DRIVERS')
            .doc(driverId)
            .set({
          'latitude': latLng.latitude,
          'longitude': latLng.longitude,
          'status': "available",
          'timestamp': FieldValue.serverTimestamp(),
          'vehicle': driverVehicle,
        }, SetOptions(merge: true));

        debugPrint("✅ Cập nhật Firestore thành công!");
      }
    } else {
      await FirebaseFirestore.instance
          .collection('AVAILABLE_DRIVERS')
          .doc(driverId)
          .set({
        'latitude': latLng.latitude,
        'longitude': latLng.longitude,
        'status': "available",
        'timestamp': FieldValue.serverTimestamp(),
        'vehicle': driverVehicle,
      });

      debugPrint("✅ Tài xế chưa tồn tại, đã thêm mới với trạng thái 'available'!");
    }

    // Cập nhật lastPosition sau khi Firestore đã được cập nhật
    lastPosition = latLng;

    if (isInitialUpdate) {
      debugPrint("🚀 Vị trí ban đầu đã được cập nhật!");
    }
  } catch (e) {
    debugPrint("🔥 Lỗi khi cập nhật Firestore: $e");
  }
}

  // LẮNG NGHE YÊU CẦU CUỐC (RIDE_REQUESTS)
  void _listenForRideRequests() {
    debugPrint("🎧 Bắt đầu lắng nghe yêu cầu đặt xe...");

    rideRequestSubscription = FirebaseFirestore.instance
        .collection('RIDE_REQUESTS')
        .where('driver_id', isEqualTo: driverId)
        .where('request_status',
            isEqualTo: 'pending') // Chỉ lấy yêu cầu đang chờ xử lý
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.docs.isNotEmpty) {
        var rideData = snapshot.docs.first;
        // Cập nhật trạng thái của tài xế thành "pending" trước khi hiển thị hộp thoại
        try {
          await FirebaseFirestore.instance
              .collection('AVAILABLE_DRIVERS')
              .doc(driverId)
              .update({'status': 'pending'});

          debugPrint("✅ Đã cập nhật trạng thái tài xế thành 'pending'");

          // Hiển thị hộp thoại yêu cầu cuốc xe
          _showRideRequestDialog(rideData);
        } catch (e) {
          debugPrint("🔥 Lỗi khi cập nhật trạng thái tài xế: $e");
        }
      }
    }, onError: (error) {
      debugPrint("🔥 Lỗi khi lắng nghe yêu cầu đặt xe: $error");
    });
  }

  // POP UP CUỐC XE
  Future<void> _showRideRequestDialog(QueryDocumentSnapshot rideData) async {
    audioplayer.setVolume(1.0); // Đảm bảo âm lượng tối đa
    await audioplayer.play(AssetSource('audio/thongbao_cocuoc.mp3'));

    await Future.delayed(Duration(seconds: 2));
    Map<String, dynamic> rideInfo = rideData.data() as Map<String, dynamic>;
    double totalFare = (rideInfo['fare'] ?? 0) + (rideInfo['weather_fee'] ?? 0);
    BuildContext dialogContext; 

    LatLng pickupLocation = LatLng(rideInfo['pickup_location']['latitude'], rideInfo['pickup_location']['longitude']);
    LatLng destinationLocation = LatLng(rideInfo['destination_location']['latitude'], rideInfo['destination_location']['longitude']);
    

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
      dialogContext = context; 

        // Bắt đầu lắng nghe rideData.id để kiểm tra nếu bị xóa
      FirebaseFirestore.instance
          .collection("RIDE_REQUESTS")
          .doc(rideData.id)
          .snapshots()
          .listen((snapshot) async {
        if (!snapshot.exists) {
          // Nếu tài liệu bị xóa, cập nhật AVAILABLE_DRIVERS về "available"
          await FirebaseFirestore.instance
              .collection("AVAILABLE_DRIVERS")
              .doc(driverId)
              .update({"status": "available"});

          // Kiểm tra xem dialog có đang mở không, nếu có thì đóng
          if (dialogContext != null && mounted) {
            Navigator.of(dialogContext).pop();
          }
        }
      });

        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: EdgeInsets.zero,
          content: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: backgroundblack,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Tổng tiền hiển thị nổi bật
                Text(
                  "Giá cuốc: ${totalFare.toStringAsFixed(0)} đ",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: primary,
                  ),
                ),
                SizedBox(height: 10),
                Divider(),

                // Card chứa thông tin điểm đón & điểm đến
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("📍 Điểm đón:",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(rideInfo['pickup_address'] ?? "Không có dữ liệu"),
                        SizedBox(height: 6),
                        Text("📍 Điểm đến:",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(rideInfo['destination_address'] ??
                            "Không có dữ liệu"),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 10),

                // Card chứa thông tin chi tiết về chuyến đi
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow("🚗 Loại xe:", rideInfo['vehicle_type']),
                        _buildInfoRow("🌦️ Phụ phí thời tiết:",
                            "${rideInfo['weather_fee']} đ"),
                        _buildInfoRow(
                            "💳 Thanh toán:", rideInfo['payment_method']),
                        _buildInfoRow("⏳ Thời gian:",
                            rideInfo['timestamp'].toDate().toString()),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 16),

                // Nút hành động
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        _processRequest(rideData.id, "denied",pickupLocation,destinationLocation);
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: myorange,
                        padding:
                            EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      child: Text("Hủy",
                          style: TextStyle(fontSize: 16, color: Colors.white)),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        _processRequest(rideData.id, "accepted",pickupLocation,destinationLocation);
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        padding:
                            EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      child: Text("Nhận cuốc",
                          style:
                              TextStyle(fontSize: 16, color: backgroundblack)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // HÀM XỬ LÝ YÊU CẦU
  void _processRequest(String rideId, String status, LatLng pickup_location,LatLng destination_location) async {
    try {
      if (status == 'denied') {
        // 🔴 Nếu tài xế từ chối cuốc xe
        await FirebaseFirestore.instance
            .collection('RIDE_REQUESTS')
            .doc(rideId)
            .update({'request_status': 'denied'});

        await FirebaseFirestore.instance
            .collection('AVAILABLE_DRIVERS')
            .doc(driverId)
            .update({'status': 'available'});

        debugPrint(
            "🚖 Cuốc xe bị từ chối! ✅ Đã cập nhật trạng thái tài xế thành 'available'");
      } else if (status == 'accepted') {
        // 🟢 Nếu tài xế chấp nhận cuốc xe, cập nhật trạng thái ride request
        await FirebaseFirestore.instance
            .collection('RIDE_REQUESTS')
            .doc(rideId)
            .update({'request_status': 'accepted'});

        await FirebaseFirestore.instance
            .collection('AVAILABLE_DRIVERS')
            .doc(driverId)
            .update({'status': 'serving'});

        debugPrint(
            "🚖 Cuốc xe được chấp nhận! ✅ Đã cập nhật trạng thái tài xế thành 'serving'");

        // 🔄 Lấy thông tin từ RIDE_REQUESTS để lưu vào TRACKING_TRIP
        DocumentSnapshot rideDoc = await FirebaseFirestore.instance
            .collection('RIDE_REQUESTS')
            .doc(rideId)
            .get();

        if (rideDoc.exists) {
          Map<String, dynamic> rideData =
              rideDoc.data() as Map<String, dynamic>;

          // ✅ Xóa các trường không cần thiết
          rideData.remove('request_status');
          rideData.remove('vehicle_type');
          rideData.remove('weather_condition');
          rideData.remove('weather_fee');
          rideData.remove('payment_method');
          rideData.remove('fare');

          // ✅ Tạo một bản ghi mới trong TRACKING_TRIP
          await FirebaseFirestore.instance
              .collection('TRACKING_TRIP')
              .doc(rideId)
              .set({
            ...rideData, // Sao chép thông tin còn lại
            'driver_id': driverId, // Gán thêm ID của tài xế
            'tracking_status': 'pickingup', // Trạng thái mới của cuốc xe
            'timestamp': FieldValue.serverTimestamp(), // Ghi thời gian
          });

          // Chuyển đến PickingUpPage và truyền dữ liệu trackingTrip
          // Chuyển đến PickingUpPage chỉ với rideId
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PickingUpPage(
                  trackingTripId: rideId, 
                  driverID: driverId ?? '',
                  pickupLocation: pickup_location,
                  destinationLocation: destination_location),
            ),
          );

          debugPrint("📌 Đã tạo bản ghi TRACKING_TRIP thành công!");
        } else {
          debugPrint("⚠️ Không tìm thấy cuốc xe trong RIDE_REQUESTS!");
        }
      } else {
        debugPrint("⚠️ Trạng thái không hợp lệ: $status");
      }
    } catch (e) {
      debugPrint("🔥 Lỗi khi xử lý cuốc xe: $e");
    }
  }

  // Hàm xử lý khi chọn BottomNavigationBarItem
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // hàm lấy thông tin tài xế từ SharedPreference
  Future<void> getDriverInfo() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      setState(() {
        driverId = prefs.getString("driver_id") ?? "driver_id_test";
        driverVehicle = prefs.getString("driver_vehicle") ?? "xemay";
      });

      if (driverId == "driver_id_test" || driverId == "driver_id_test2" || driverId == "driver_id_test3") {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text("Bạn đang ở chế độ test với ID tài xế: $driverId"),
      duration: Duration(seconds: 1),
    ),
  );
}


    } catch (e) {
      debugPrint("Lỗi $e");
    }
  }

  // Hàm này trả về tên cho AppBar title và widget tương ứng
  _loadWidget(int index) {
    String nameWidgets = "Home";
    switch (index) {
      case 0:
        return HomeScreen();
      case 1:
        nameWidgets = "History";
        break;
      case 2:
        nameWidgets = "Wallet";
        break;
      case 3:
        nameWidgets = "Profile";
        break;
      default:
        nameWidgets = "None";
        break;
    }
    return DefaultWidget(title: nameWidgets);
  }

  //////////////////////////// Layout ////////////////////////////////////////////
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: Builder(
          builder: (context) => Container(
            margin: EdgeInsets.fromLTRB(16, 8, 0, 7),
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: Colors.amber[600],
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: Icon(Icons.menu, size: 24),
              color: Colors.black,
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            ),
          ),
        ),
        title: Text(
          _selectedIndex == 0
              ? 'Home'
              : _selectedIndex == 1
                  ? 'History'
                  : _selectedIndex == 2
                      ? 'Wallet'
                      : _selectedIndex == 3
                          ? 'Profile'
                          : '',
          style: TextStyle(color: Colors.white),
        ),
        actions: <Widget>[
          // Nút sẵn sàng nhận chuyến
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: isTracking ? Colors.green : Colors.amber[600],
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: Icon(Icons.bolt, size: 24),
              color: Colors.black,
              onPressed: _toggleTracking,
            ),
          ),

          SizedBox(width: 16),
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: Colors.amber[600],
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: Icon(Icons.notifications, size: 24),
              color: Colors.black,
              onPressed: () {},
            ),
          ),
          SizedBox(width: 16),
        ],
      ),
      extendBodyBehindAppBar: true,
      drawer: Drawer(
        child: Container(
          color: const Color(0xFF1F212A), // Thêm màu nền cho ListView
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  color: Color(0xFF1F212A), // Màu nền của DrawerHeader,
                  border: Border(bottom: BorderSide(width: 0)),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundImage: NetworkImage(
                        "https://googleflutter.com/sample_image.jpg",
                      ),
                    ),
                    SizedBox(height: 8),
                    Text('Nguyễn Hồ Ngọc Huy',
                        style: TextStyle(color: Colors.white)),
                    // Hiển thị ID tài xế
                    Text("$driverId", style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              // Các ListTile cho mục trong Drawer
              ListTile(
                leading: const Icon(
                  Icons.person,
                  color: Colors.white, // Màu biểu tượng trắng
                ),
                title: const Text(
                  "Tài khoản",
                  style: TextStyle(color: Colors.white), // Màu chữ trắng
                ),
                onTap: () {
                  Navigator.pop(context);
                  _selectedIndex = 0;
                  setState(() {});
                },
              ),
              const Divider(color: Colors.white),
              ListTile(
                leading: const Icon(
                  Icons.attach_money,
                  color: Colors.white, // Màu biểu tượng trắng
                ),
                title: const Text(
                  "History",
                  style: TextStyle(color: Colors.white), // Màu chữ trắng
                ),
                onTap: () {
                  Navigator.pop(context);
                  _selectedIndex = 1;
                  setState(() {});
                },
              ),
              const Divider(color: Colors.white),
              ListTile(
                leading: const Icon(
                  Icons.person,
                  color: Colors.white, // Màu biểu tượng trắng
                ),
                title: const Text(
                  "Wallet",
                  style: TextStyle(color: Colors.white), // Màu chữ trắng
                ),
                onTap: () {
                  Navigator.pop(context);
                  _selectedIndex = 2;
                  setState(() {});
                },
              ),
              const Divider(color: Colors.white),
              ListTile(
                leading: const Icon(
                  Icons.settings,
                  color: Colors.white, // Màu biểu tượng trắng
                ),
                title: const Text(
                  "Profile",
                  style: TextStyle(color: Colors.white), // Màu chữ trắng
                ),
                onTap: () {
                  Navigator.pop(context);
                  _selectedIndex = 3;
                  setState(() {});
                },
              ),
              const Divider(color: Colors.white),
              ListTile(
                leading: const Icon(
                  Icons.exit_to_app,
                  color: Colors.white, // Màu biểu tượng trắng
                ),
                title: const Text(
                  "Đăng xuất",
                  style: TextStyle(color: Colors.white), // Màu chữ trắng
                ),
                onTap: () {
                  Navigator.pop(context);
                  _selectedIndex = 0;
                  setState(() {});
                },
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Theme(
        data: ThemeData(
          canvasColor: Colors.black,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: "Home",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.lock_clock),
              label: "History",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.attach_money),
              label: "Wallet",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: "Profile",
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: Colors.amber[400],
          unselectedItemColor: Colors.grey,
          onTap: _onItemTapped,
          showUnselectedLabels: true,
          backgroundColor: Colors.black,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
      ),
      body: _loadWidget(_selectedIndex),
    );
  }

/////////////////////////////// Widget //////////////////////////////////////////
  // Widget hiển thị mỗi dòng thông tin
  Widget _buildInfoRow(String title, dynamic value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(width: 8),
          Expanded(
              child: Text(value.toString(),
                  style: TextStyle(color: Colors.white))),
        ],
      ),
    );
  }
}
