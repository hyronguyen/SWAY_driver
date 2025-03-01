import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:sway_driver/page/default.dart';
import 'package:sway_driver/page/home.dart';
import 'dart:async';


class DriverMainpage extends StatefulWidget {
  const DriverMainpage({super.key});

  @override
  State<DriverMainpage> createState() => _DriverMainpageState();
}

class _DriverMainpageState extends State<DriverMainpage> {
  //////////////////////////// Biến cục bộ ////////////////////////////////////////////

  bool isTracking = false; // Trạng thái theo dõi vị trí
  String driverId = "taxe123456"; // ID tài xế (Lấy từ Drawer)
  StreamSubscription<Position>? positionSubscription; // Quản lý stream vị trí

  int _selectedIndex = 0;

//////////////////////////// Functions ////////////////////////////////////////////

  // Hàm bật chức năng nhận cuốc xe
  void _toggleTracking() async {
    debugPrint("_toggleTracking: ⚡ Bắt đầu toggle tracking...");

    if (!isTracking) {
      debugPrint("_toggleTracking: 📍 Kiểm tra quyền truy cập vị trí...");

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.deniedForever) {
          debugPrint("_toggleTracking: 🚫 Quyền truy cập vị trí bị từ chối vĩnh viễn!");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Quyền truy cập vị trí bị từ chối!")),
          );
          return;
        }
      }

      debugPrint("✅ Quyền truy cập vị trí được cấp!");

      // Bắt đầu theo dõi vị trí
      setState(() {
        isTracking = true;
      });

      debugPrint("⏳ Bắt đầu nhận vị trí từ Geolocator...");

      positionSubscription = Geolocator.getPositionStream(
        locationSettings: LocationSettings(accuracy: LocationAccuracy.high),
      ).listen((Position position) async {
        
        LatLng latLng = LatLng(position.latitude, position.longitude);
        debugPrint("📌 Nhận vị trí mới: ${latLng}");
   
        try {
          await FirebaseFirestore.instance
              .collection('AVAILABLE_DRIVERS')
              .doc(driverId)
              .set({
            'latitude': position.latitude,
            'longitude': position.longitude,
            'status': "available",
            'timestamp': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          debugPrint("✅ Cập nhật Firestore thành công!");
        } catch (e) {
          debugPrint("🔥 Lỗi khi cập nhật Firestore: $e");
        }
      }, onError: (error) {
        debugPrint("⚠️ Lỗi khi lắng nghe vị trí: $error");
      });
    } else {
      debugPrint("🛑 Dừng theo dõi vị trí...");

      setState(() {
        isTracking = false;
      });

      // Hủy lắng nghe vị trí để dừng cập nhật Firestore
      await positionSubscription?.cancel();
      positionSubscription = null;
      debugPrint("🚫 Đã hủy lắng nghe vị trí.");

      // Xóa tài xế khỏi Firestore
      try {
        await FirebaseFirestore.instance
            .collection('AVAILABLE_DRIVERS')
            .doc(driverId)
            .delete();

        debugPrint("🗑️ Tài xế đã bị xóa khỏi Firestore.");
      } catch (e) {
        debugPrint("🔥 Lỗi khi xóa tài xế khỏi Firestore: $e");
      }
    }
  }

  // Hàm xử lý khi chọn BottomNavigationBarItem
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
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
                decoration: const BoxDecoration(
                  color: Color(0xFF1F212A), // Màu nền của DrawerHeader,
                  border: Border(bottom: BorderSide(width: 0)),
                ),
                child: Column(
                  children: const [
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
                    Text("taxe123456", style: TextStyle(color: Colors.white)),
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
}
