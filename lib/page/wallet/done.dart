import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sway_driver/mainpage.dart';


class DonePage extends StatefulWidget {
  final String tripId;

  const DonePage({Key? key, required this.tripId}) : super(key: key);

  @override
  _DonePageState createState() => _DonePageState();
}

class _DonePageState extends State<DonePage> {
  Map<String, dynamic>? tripData;
  bool isLoading = true;
  bool isProcessing = false; // Trạng thái để hiển thị loading khi bấm nút

  @override
  void initState() {
    super.initState();
    fetchTripData();
  }

  Future<void> fetchTripData() async {
    try {
      DocumentSnapshot tripSnapshot = await FirebaseFirestore.instance
          .collection('RIDE_REQUESTS')
          .doc(widget.tripId)
          .get();

      if (tripSnapshot.exists) {
        setState(() {
          tripData = tripSnapshot.data() as Map<String, dynamic>;
          isLoading = false;
        });
      } else {
        setState(() {
          tripData = null;
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        tripData = null;
        isLoading = false;
      });
      print('Error fetching trip data: $e');
    }
  }

  Future<void> completeTrip() async {
    if (tripData == null) return;

    setState(() {
      isProcessing = true; // Hiển thị trạng thái loading khi đang xử lý
    });

    String driverId = tripData!['driver_id'];

    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;

      // Cập nhật trạng thái tài xế thành "available"
      await firestore.collection('AVAILABLE_DRIVERS').doc(driverId).update({
        'status': 'available',
      });


      // Xóa chuyến đi khỏi RIDE_REQUESTS
      await firestore.collection('RIDE_REQUESTS').doc(widget.tripId).delete();

      // Xóa dữ liệu khỏi TRACKING_TRIP
      await firestore.collection('TRACKING_TRIP').doc(widget.tripId).delete();

      // Điều hướng về trang DriverMainPage
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => DriverMainpage()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      print('Error completing trip: $e');
    } finally {
      if (mounted) {
        setState(() {
          isProcessing = false; // Tắt trạng thái loading
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip Details'),
        backgroundColor: Colors.green,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : tripData == null
              ? const Center(child: Text('Trip not found'))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ListView(
                    children: [
                      buildInfoTile('Pickup Address', tripData!['pickup_address']),
                      buildInfoTile('Destination Address', tripData!['destination_address']),
                      buildInfoTile('Vehicle Type', tripData!['vehicle_type']),
                      buildInfoTile('Fare', '${tripData!['fare']} VND'),
                      buildInfoTile('Payment Method', tripData!['payment_method']),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: isProcessing ? null : completeTrip,
                        child: isProcessing
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Hoàn thành cuốc'),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget buildInfoTile(String title, String value) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(value),
      contentPadding: const EdgeInsets.symmetric(vertical: 4.0),
    );
  }
}
