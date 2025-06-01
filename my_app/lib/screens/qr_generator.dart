import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:firebase_database/firebase_database.dart';

class QRCodeGenerator extends StatefulWidget {
  final String slotId;

  const QRCodeGenerator({super.key, required this.slotId});

  @override
  _QRCodeGeneratorState createState() => _QRCodeGeneratorState();
}

class _QRCodeGeneratorState extends State<QRCodeGenerator> {
  String qrData = "";
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchSlotData();
  }

  void fetchSlotData() async {
    DatabaseReference ref = FirebaseDatabase.instance.ref("bookedSlots/${widget.slotId}");
    DatabaseEvent event = await ref.once();
    
    if (event.snapshot.exists) {
      setState(() {
        qrData = "https://yourapp.com/parking-slot?slot_id=${widget.slotId}";
        isLoading = false;
      });
    } else {
      setState(() {
        qrData = "Invalid Slot ID";
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Parking QR Code")),
      body: Center(
        child: isLoading
            ? CircularProgressIndicator()
            : qrData != "Invalid Slot ID"
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Scan to Check Slot: ${widget.slotId}"),
                      QrImageView(
                        data: qrData,
                        size: 200,
                        backgroundColor: Colors.white,
                      ),
                    ],
                  )
                : Text("No Data Found for Slot: ${widget.slotId}"),
      ),
    );
  }
}
