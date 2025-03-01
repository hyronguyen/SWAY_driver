import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _addressController = TextEditingController();
  LatLng? _selectedLocation;

//////////////////////////// Functions ////////////////////////////////////////////

  Future<void> _getAddressFromLatLng(LatLng latLng) async {
    try {
      List<Placemark> placemarks =
          await placemarkFromCoordinates(latLng.latitude, latLng.longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        String address =
            "${place.street}, ${place.subLocality}, ${place.locality}, ${place.country}";

        // Loại bỏ dấu ",,," dư thừa
        address = address.replaceAll(RegExp(r',\s*,+'), ',').trim();

        setState(() {
          _addressController.text = address;
        });
      }
    } catch (e) {
      debugPrint("Lỗi lấy địa chỉ: $e");
    }
  }

  // Lấy vị trí hiện tại và cập nhật địa chỉ
  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Kiểm tra quyền truy cập vị trí
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    // Lấy tọa độ vị trí hiện tại
    Position position = await Geolocator.getCurrentPosition();
    LatLng latLng = LatLng(position.latitude, position.longitude);

    setState(() {
      _selectedLocation = latLng;
    });

    _mapController.move(latLng, 16);
    _getAddressFromLatLng(latLng);
  }

  // Tìm kiếm vị trí theo địa chỉ nhập vào
  Future<void> _searchLocationByAddress() async {
    String address = _addressController.text;
    if (address.isEmpty) return;

    try {
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        Location location = locations.first;
        LatLng latLng = LatLng(location.latitude, location.longitude);

        setState(() {
          _selectedLocation = latLng;
        });

        _mapController.move(latLng, 16);
      }
    } catch (e) {
      debugPrint("Lỗi tìm vị trí: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(10.7769, 106.7009),
              initialZoom: 13,
              onTap: (tapPosition, point) {
                setState(() {
                  _selectedLocation = point;
                });
                _getAddressFromLatLng(point);
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://api.mapbox.com/styles/v1/hothanhgiang9/cm6n57t2u007201sg15ac9swb/tiles/256/{z}/{x}/{y}@2x?access_token=pk.eyJ1IjoiaG90aGFuaGdpYW5nOSIsImEiOiJjbTZuMnhsbWUwMmtkMnFwZDhtNmZkcDJ0In0.0OXsluwAO14jJxPMUowtaA',
              ),
              if (_selectedLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedLocation!,
                      width: 30,
                      height: 30,
                      child: const Icon(Icons.location_pin,
                          color: Colors.amber, size: 30),
                    ),
                  ],
                ),
            ],
          ),

          // Ô thông tin chỉ só tài xế (tỷ lệ hoàn thành , hủy, doanh thu)
          Positioned(
            left: 10,
            right: 20,
            bottom: 50,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF35383F),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber, width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Chỉ số tài xế',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          Icon(Icons.check_circle,
                              color: const Color.fromARGB(255, 255, 255, 255), size: 24),
                          SizedBox(height: 4),
                          Text(
                            '95%',
                            style: TextStyle(color: Colors.amber, fontSize: 16),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Tỷ lệ hoàn thành',
                            style: TextStyle(color:  Color.fromARGB(255, 147, 146, 146), fontSize: 12),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Icon(Icons.cancel, color: const Color.fromARGB(255, 255, 255, 255), size: 24),
                          SizedBox(height: 4),
                          Text(
                            '5%',
                            style: TextStyle(color: Colors.amber, fontSize: 16),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Tỷ lệ hủy',
                            style: TextStyle(color:  Color.fromARGB(255, 147, 146, 146), fontSize: 12),
                          ),
                        ],
                      ),
                      Container(
                        height: 60,
                        child: VerticalDivider(
                          color: const Color.fromARGB(255, 255, 255, 255),
                          thickness: 2,
                        ),
                      ),
                      Column(
                        children: [
                          Icon(Icons.monetization_on,
                              color: const Color.fromARGB(255, 255, 255, 255), size: 24),
                          SizedBox(height: 4),
                          Text(
                            '10,000,000 VND',
                            style: TextStyle(color: Colors.amber, fontSize: 16),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Doanh thu',
                            style: TextStyle(color: const Color.fromARGB(255, 147, 146, 146), fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Nút tìm vị trí hiện tại
          Positioned(
            bottom: 200,
            right: 20,
            child: FloatingActionButton(
              onPressed: _getCurrentLocation,
              backgroundColor: const Color(0xFF35383F),
              child: const Icon(Icons.my_location, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
