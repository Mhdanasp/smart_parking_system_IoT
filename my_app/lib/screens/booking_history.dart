import 'package:flutter/material.dart';

class BookingHistoryScreen extends StatelessWidget {
  final List<Map<String, dynamic>> history;

  const BookingHistoryScreen({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Booking History")),
      body: history.isEmpty
          ? const Center(child: Text("No bookings yet!"))
          : ListView.builder(
              itemCount: history.length,
              itemBuilder: (context, index) {
                final booking = history[index];
                return ListTile(
                  leading: const Icon(Icons.local_parking, color: Colors.blue),
                  title: Text("Slot ${booking["slotNumber"]}"),
                  subtitle: Text("Booked on: ${booking["dateTime"]}"),
                );
              },
            ),
    );
  }
}
