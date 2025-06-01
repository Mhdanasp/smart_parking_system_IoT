import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'parking_slot.dart';
import 'dart:math';

class ScanAndPayScreen extends StatefulWidget {
  final Map<String, dynamic> slotData;

  const ScanAndPayScreen({required this.slotData, super.key});

  @override
  _ScanAndPayScreenState createState() => _ScanAndPayScreenState();
}

class _ScanAndPayScreenState extends State<ScanAndPayScreen> {
  late Razorpay _razorpay;
  final _dbRef = FirebaseDatabase.instance.ref();
  final _user = FirebaseAuth.instance.currentUser;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onFailure);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
  }

  void _onSuccess(PaymentSuccessResponse response) async {
    setState(() => _isProcessing = true);

    try {
      final now = DateTime.now();
      final formattedTime = "${now.hour}:${now.minute}:${now.second}";
      final formattedDate = "${now.day}-${now.month}-${now.year}";
      final epochTime = now.millisecondsSinceEpoch;

      final qrEntryRef = _dbRef.child("QREntries").child(_user!.uid);

      DataSnapshot snapshot = await qrEntryRef.get();

      if (!snapshot.exists) {
        // 🔐 First-time Entry
        await qrEntryRef.set({
          "slot": widget.slotData["slot_id"] ?? "unknown_slot",
          "status": "Entered",
          "entry_time": formattedTime,
          "entry_date": formattedDate,
          "entry_epoch": epochTime,
        });

        // 🔓 Open the gate for entry
        await _dbRef.child("GateStatus").set("open");

      } else {
        // 🚗 Exit Flow
        final entryEpoch = snapshot.child("entry_epoch").value as int;
        final durationInMillis = epochTime - entryEpoch;
        final durationInHours = (durationInMillis / (1000 * 60 * 60)).ceil();
        final rate = 20;
        final totalAmount = durationInHours * rate;

        await qrEntryRef.update({
          "status": "Exited",
          "exit_time": formattedTime,
          "exit_date": formattedDate,
          "exit_epoch": epochTime,
          "duration_hours": durationInHours,
          "amount_charged": totalAmount,
        });

        // 🔓 Open the gate for exit
        await _dbRef.child("GateStatus").set("open");

        // 💰 Deduct from user's wallet
        final userRef = _dbRef.child("Users").child(_user!.uid);
        DataSnapshot userSnap = await userRef.get();
        int balance = (userSnap.child("wallet").value ?? 0) as int;
        await userRef.child("wallet").set(balance - totalAmount);
      }

      // ✅ Proceed to ParkingSlotPage
      List<int> bookedIndices = List<int>.from(widget.slotData['booked_slots'] ?? []);
      int totalSlots = widget.slotData['total_slots'] ?? 10;

      List<bool> bookedSlots = List<bool>.filled(totalSlots, false);
      for (int index in bookedIndices) {
        if (index > 0 && index <= totalSlots) {
          bookedSlots[index - 1] = true;
        }
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ParkingSlotPage(
            bookedSlots: bookedSlots,
            onSlotUpdated: (i, v) {},
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _onFailure(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("❌ Payment failed: ${response.message}")),
    );
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Wallet selected: ${response.walletName}")),
    );
  }

  void _startPayment() {
    var options = {
      'key': 'rzp_test_bfZpMcNoBvJZcB',
      'amount': 2000,
      'name': 'Smart Parking',
      'description': 'QR Access UPI Payment',
      'currency': 'INR',
      'prefill': {
        'contact': '9999999999',
        'email': 'test@example.com',
      },
      'method': {
        'upi': true,
        'card': true,
        'netbanking': false,
      }
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint("Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to start payment")),
      );
    }
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Confirm Payment")),
      body: Center(
        child: _isProcessing
            ? const CircularProgressIndicator()
            : ElevatedButton(
                onPressed: _startPayment,
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
                child: const Text("Pay ₹20 via UPI & Access Gate"),
              ),
      ),
    );
  }
}
