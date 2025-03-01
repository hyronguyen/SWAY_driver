
import 'package:flutter/material.dart';
import 'package:sway_driver/mainpage.dart';
import 'package:sway_driver/page/authen/register.dart';


class DriverLoginScreen extends StatelessWidget {
  ////////////////////////////// BIẾN WIDGETS  ////////////////////////////////////////////////////////
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  DriverLoginScreen({super.key});

  ////////////////////////////// LAYOUT  ////////////////////////////////////////////////////////
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView( // Add SingleChildScrollView here
          padding: const EdgeInsets.all(15),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Image.asset('assets/images/ob_2.png'),
              const SizedBox(height: 30),

              // Field số điện thoại
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: "Số điện thoại",
                  labelStyle: TextStyle(color: Colors.white),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFedae10), width: 1),
                  ),
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 10),

              // Field mật khẩu
              TextField(
                controller: passwordController,
                obscureText: true, // Ẩn mật khẩu
                decoration: const InputDecoration(
                  labelText: "Mật khẩu",
                  labelStyle: TextStyle(color: Colors.white),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFedae10), width: 1),
                  ),
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 10),

              //Driver
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        transitionDuration: const Duration(milliseconds: 600),
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            DriverMainpage(),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                          const begin = Offset(1.0, 0.0); // Đi từ bên phải vào
                          const end = Offset.zero;
                          const curve = Curves.easeInOut;

                          var tween = Tween(begin: begin, end: end)
                              .chain(CurveTween(curve: curve));

                          return SlideTransition(
                            position: animation.drive(tween),
                            child: child,
                          );
                        },
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 12),
                    backgroundColor:
                        Color.fromARGB(255, 255, 255, 255), // Đổi màu nền nút
                    foregroundColor: Color(0xFFedae10), // Đổi màu chữ trên nút
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(12), // Bo tròn viền nút
                    ),
                  ),
                  child: const Text("Đăng nhập",
                      style: TextStyle(fontSize: 16)),
                ),
              ),

              const SizedBox(height: 20),
              // Divider và chữ "or"
              Row(
                children: [
                  Expanded(
                    child: Divider(color: Colors.white, thickness: 1),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: 10), // Khoảng cách giữa Divider và chữ "or"
                    child: Text(
                      "or",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    child: Divider(color: Colors.white, thickness: 1),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Chuyển đến trang đăng ký
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      transitionDuration: const Duration(milliseconds: 600),
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          DriverSignupScreen(),
                      transitionsBuilder:
                          (context, animation, secondaryAnimation, child) {
                        const begin = Offset(1.0, 0.0); // Đi từ bên phải vào
                        const end = Offset.zero;
                        const curve = Curves.easeInOut;

                        var tween = Tween(begin: begin, end: end)
                            .chain(CurveTween(curve: curve));

                        return SlideTransition(
                          position: animation.drive(tween),
                          child: child,
                        );
                      },
                    ),
                  );
                },
                child: const Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: "Tài xế mới? ",
                        style: TextStyle(
                            color: Colors.white), // Màu trắng cho phần đầu
                      ),
                      TextSpan(
                        text: "Đăng ký ở đây",
                        style: TextStyle(
                            color: Color(0xFFedae10),
                            fontWeight:
                                FontWeight.bold), // Màu vàng cho phần sau
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  ////////////////////////////// FUNCTION  ////////////////////////////////////////////////////////

}
