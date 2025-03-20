import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sway_driver/config/colors.dart';
import 'package:sway_driver/mainpage.dart';
import 'package:sway_driver/page/authen/login.dart';

class TestScreen extends StatefulWidget {
  @override
  _TestScreenState createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  String selectedVehicle = 'xemay';
  String selectedDriverId = 'driver_id_test';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundblack, // Nền trắng theo phong cách Apple
      appBar: AppBar(
        title: Text(
          'SWAY DRIVER',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: backgroundblack,
        elevation: 0, // Bỏ bóng cho app bar
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Dropdown chọn phương tiện
            _buildDropdown(
              label: "Chọn phương tiện",
              value: selectedVehicle,
              items: ['xemay', '4cho', '7cho'],
              onChanged: (value) {
                setState(() {
                  selectedVehicle = value!;
                });
              },
            ),
            SizedBox(height: 20),

            // Dropdown chọn ID tài xế
            _buildDropdown(
              label: "Chọn ID tài xế",
              value: selectedDriverId,
              items: ['driver_id_test', 'driver_id_test2', 'driver_id_test3'],
              onChanged: (value) {
                setState(() {
                  selectedDriverId = value!;
                });
              },
            ),
            SizedBox(height: 40),

            // Nút Live
            _buildButton(
              text: "Live",
              color: primary,
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => DriverLoginScreen()),
                );
              },
            ),
            SizedBox(height: 20),

            // Nút Run Test
            _buildButton(
              text: "Run Test",
              color: greymenu,
              onPressed: _runTest,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade400),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              onChanged: onChanged,
              isExpanded: true,
              style: TextStyle(fontSize: 16, color: primary),
              items: items
                  .map((item) => DropdownMenuItem(
                        value: item,
                        child: Text(item),
                      ))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildButton({
    required String text,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 55,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
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

  Future<void> _runTest() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Xóa nếu tồn tại
    await prefs.remove('driver_id');
    await prefs.remove('driver_vehicle');

    // Thiết lập giá trị mới từ dropdown
    await prefs.setString('driver_id', selectedDriverId);
    await prefs.setString('driver_vehicle', selectedVehicle);

    // Chuyển hướng đến DriverMainpage()
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => DriverMainpage()),
    );
  }
}
