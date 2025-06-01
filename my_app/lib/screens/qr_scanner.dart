import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'scan_and_pay_screen.dart'; // 👈 NEW: Import the payment screen

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  _QRScannerScreenState createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  bool isScanning = true;

  void _onQRViewDetected(BarcodeCapture capture) {
    if (!isScanning) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
      setState(() => isScanning = false);

      String qrData = barcodes.first.rawValue!;
      print("📌 Scanned QR Data: $qrData");

      try {
        Map<String, dynamic> decodedData = jsonDecode(qrData);

        /// ✅ Navigate to Payment + Parking Flow
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ScanAndPayScreen(slotData: decodedData),
          ),
        );
      } catch (e) {
        print("❌ Error decoding QR data: $e");
        _showMessage("⚠️ Invalid QR Code!");
        setState(() => isScanning = true);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scan QR Code")),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: MobileScanner(
              onDetect: _onQRViewDetected,
            ),
          ),
          const Expanded(
            flex: 1,
            child: Center(
              child: Text(
                "📷 Scan a QR code to begin",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
