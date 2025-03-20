import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sway_driver/config/colors.dart';
import 'package:sway_driver/mainpage.dart';
import 'package:sway_driver/page/authen/login.dart';

class TestScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundblack, // Nền trắng theo phong cách Apple
      appBar: AppBar(
        title: Text(
          'SWAY DRIVER LAUNCH OPTIONS',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        backgroundColor: backgroundblack,
        elevation: 0, // Bỏ bóng cho app bar
        iconTheme: IconThemeData(color: Colors.black), // Màu icon về đen
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _buildButton(
                text: "Live",
                color: primary,
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (context) => DriverLoginScreen()),
                  );
                },
              ),
              SizedBox(height: 20),
              _buildButton(
                text: "Run Test",
                color: greymenu,
                onPressed: () async {
                  SharedPreferences prefs =
                      await SharedPreferences.getInstance();

                  // Xóa nếu tồn tại
                  if (prefs.containsKey('driver_id')) {
                    await prefs.remove('driver_id');
                  }
                  if (prefs.containsKey('driver_vehicle')) {
                    await prefs.remove('driver_vehicle');
                  }

                  // Thiết lập giá trị mới
                  await prefs.setString('driver_id', 'driver_id_test');
                  await prefs.setString('driver_vehicle', 'xemay');

                  // Chuyển hướng đến TripPicker()
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => DriverMainpage()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildButton({
    required String text,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 60, // Tăng chiều cao button
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12), // Bo góc mềm mại hơn
          ),
          elevation: 2, // Nhẹ nhàng tạo chiều sâu
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
