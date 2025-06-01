import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ParkingSlotPage extends StatefulWidget {
  final List<bool> bookedSlots;
  final Function(int, bool) onSlotUpdated;

  const ParkingSlotPage({
    super.key,
    required this.bookedSlots,
    required this.onSlotUpdated,
  });

  @override
  State<ParkingSlotPage> createState() => _ParkingSlotPageState();
}

class _ParkingSlotPageState extends State<ParkingSlotPage> {
  final DatabaseReference _database = FirebaseDatabase.instance
      .ref("XYZ_Mall/ParkingSpaces/ParkingSpace_1/BookedSlots");
  final DatabaseReference _sensorDatabase =
      FirebaseDatabase.instance.ref("IR_Sensors");

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  late List<bool> _localBookedSlots;
  List<bool> _sensorOccupied = [];

  @override
  void initState() {
    super.initState();
    _localBookedSlots = List<bool>.from(widget.bookedSlots);
    _sensorOccupied = List<bool>.filled(_localBookedSlots.length, false);
    _listenToSlotUpdates();
    _listenToSensorData();
  }

  void _listenToSlotUpdates() {
    _database.onValue.listen((event) {
      if (!mounted) return;
      final data = event.snapshot.value as Map?;
      if (data != null) {
        List<bool> updatedSlots = List<bool>.filled(_localBookedSlots.length, false);
        for (int i = 0; i < _localBookedSlots.length; i++) {
          final slotKey = "slot_${i + 1}";
          if (data.containsKey(slotKey)) {
            final slotData = data[slotKey];
            if (slotData is Map && slotData["status"] == "booked") {
              updatedSlots[i] = true;
            }
          }
        }
        setState(() {
          _localBookedSlots = updatedSlots;
        });
      }
    });
  }

  void _listenToSensorData() {
    _sensorDatabase.onValue.listen((event) {
      if (!mounted) return;
      final data = event.snapshot.value as Map?;
      if (data != null) {
        List<bool> sensorData = List.filled(_localBookedSlots.length, false);
        for (int i = 0; i < _localBookedSlots.length; i++) {
          final sensorKey = "IR${i + 1}";
          final sensorVal = data[sensorKey];
          if (sensorVal != null) {
            sensorData[i] = sensorVal.toString().toLowerCase() == "occupied";
          }
        }
        setState(() {
          _sensorOccupied = sensorData;
        });
      }
    });
  }

  Future<void> _bookSlot(int index) async {
    final user = _currentUser;
    if (user == null) return _showMessage("❌ User not logged in!");

    if (_sensorOccupied[index]) {
      _showMessage("⚠️ Slot ${index + 1} is already occupied!");
      return;
    }

    bool confirmed = await _showConfirmationDialog(
      "Confirm Booking",
      "Do you want to book Slot ${index + 1}?",
    );

    if (!confirmed) return;

    final slotId = "slot_${index + 1}";
    try {
      await _database.child(slotId).set({
        "slotId": slotId,
        "userId": user.uid,
        "email": user.email ?? "No email",
        "status": "booked",
        "timestamp": DateTime.now().toIso8601String(),
      });
      setState(() {
        _localBookedSlots[index] = true;
      });
      widget.onSlotUpdated(index, true);
      _showMessage("✅ Slot ${index + 1} booked successfully!");
    } catch (e) {
      _showMessage("❌ Booking failed: $e");
    }
  }

  Future<void> _cancelSlot(int index) async {
    final user = _currentUser;
    if (user == null) return _showMessage("❌ User not logged in!");

    bool confirmed = await _showConfirmationDialog(
      "Cancel Booking",
      "Are you sure you want to cancel Slot ${index + 1}?",
    );

    if (!confirmed) return;

    final slotId = "slot_${index + 1}";
    try {
      await _database.child(slotId).remove();
      setState(() {
        _localBookedSlots[index] = false;
      });
      widget.onSlotUpdated(index, false);
      _showMessage("✅ Slot ${index + 1} cancelled successfully!");
    } catch (e) {
      _showMessage("❌ Cancellation failed: $e");
    }
  }

  Future<bool> _showConfirmationDialog(String title, String content) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                child: const Text("Cancel"),
                onPressed: () => Navigator.pop(context, false),
              ),
              ElevatedButton(
                child: const Text("Confirm"),
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<String> _generateQrData() async {
    final snapshot = await _database.get();
    final data = snapshot.value as Map?;

    List<int> bookedSlots = [];
    List<int> availableSlots = [];

    int totalSlots = _localBookedSlots.length;

    if (data != null) {
      for (int i = 0; i < totalSlots; i++) {
        final key = "slot_${i + 1}";
        if (data.containsKey(key)) {
          bookedSlots.add(i + 1);
        } else {
          availableSlots.add(i + 1);
        }
      }
    } else {
      availableSlots = List.generate(totalSlots, (i) => i + 1);
    }

    final qrMap = {
      "total_slots": totalSlots,
      "booked_slots": bookedSlots,
      "available_slots": availableSlots,
      "link": "https://yourapp.com/parking?available_slots=${availableSlots.join(',')}"
    };

    return jsonEncode(qrMap);
  }

  void _showQrCodeDialog() async {
  try {
    final qrData = await _generateQrData();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Parking Slot QR Code",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 250,
                backgroundColor: Colors.white,
                errorStateBuilder: (cxt, err) => const Center(
                  child: Text(
                    '❌ Unable to generate QR',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SelectableText(
                jsonDecode(qrData)['link'],
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.blue),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Close"),
              ),
            ],
          ),
        ),
      ),
    );
  } catch (e) {
    _showMessage("❌ Failed to generate QR: $e");
  }
}


  void _showMessage(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Parking Slot"),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code),
            onPressed: _showQrCodeDialog,
          ),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1,
        ),
        itemCount: _localBookedSlots.length,
        itemBuilder: (context, index) {
          final isBooked = _localBookedSlots[index];
          final isOccupied = _sensorOccupied.length > index && _sensorOccupied[index];

          Color slotColor;
          String slotText;
          if (isOccupied) {
            slotColor = Colors.orange;
            slotText = "Occupied ${index + 1}";
          } else if (isBooked) {
            slotColor = Colors.red;
            slotText = "Cancel ${index + 1}";
          } else {
            slotColor = Colors.green;
            slotText = "Book Slot ${index + 1}";
          }

          return GestureDetector(
            onTap: () {
              if (isBooked) {
                _cancelSlot(index);
              } else if (isOccupied) {
                _showMessage("⚠️ Slot ${index + 1} is occupied!");
              } else {
                _bookSlot(index);
              }
            },
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: slotColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                slotText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
