import 'package:flutter/material.dart';
import 'parking_slot.dart';
import 'profile.dart';
import 'qr_scanner.dart';
import 'booking_history.dart';
import 'wallet.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<bool> bookedSlots = List.filled(6, false); // Track slot availability
  List<Map<String, dynamic>> bookingHistory = []; // ✅ Store history
  int _selectedIndex = 0; // Track selected tab
  String searchQuery = ""; // ✅ Stores search input
  List<String> parkingAreas = ["XYZ Mall", "Apollo Hospital", "Green Plaza"]; // ✅ Example areas
  List<String> selectedGrounds = ["Parking Space 1", "Parking Space 2"]; // ✅ Example grounds

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Parking Space"), centerTitle: true),
      backgroundColor: Colors.grey[200],
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // ✅ Search Bar
            TextField(
              decoration: InputDecoration(
                labelText: "Search Areas",
                hintText: "Enter mall or hospital name...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
            ),
            const SizedBox(height: 20),

            // ✅ Display search results
            Expanded(
              child: searchQuery.isEmpty
                  ? const Center(child: Text("Search for parking areas"))
                  : ListView.builder(
                      itemCount: parkingAreas.length,
                      itemBuilder: (context, index) {
                        if (parkingAreas[index].toLowerCase().contains(searchQuery.toLowerCase())) {
                          return Card(
                            child: ListTile(
                              title: Text(parkingAreas[index]),
                              trailing: const Icon(Icons.arrow_forward_ios),
                              onTap: () {
                                // ✅ Show available parking grounds
                                _showGroundSelection(parkingAreas[index]);
                              },
                            ),
                          );
                        } else {
                          return const SizedBox(); // Hide unmatched items
                        }
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.qr_code), label: "QR Scan"),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "History"),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: "Wallet"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }

  void _onItemTapped(int index) {
    if (index == 1) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const QRScannerScreen()));
    } else if (index == 2) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => BookingHistoryScreen(history: bookingHistory)));
    } else if (index == 3) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const WalletScreen()));
    } else if (index == 4) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  // ✅ Show parking ground selection
  void _showGroundSelection(String areaName) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return ListView.builder(
          itemCount: selectedGrounds.length,
          itemBuilder: (context, index) {
            return ListTile(
              title: Text(selectedGrounds[index]),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.pop(context); // Close the bottom sheet
                _navigateToParkingSlot(selectedGrounds[index]);
              },
            );
          },
        );
      },
    );
  }

  // ✅ Navigate to ParkingSlotPage with required parameters
  void _navigateToParkingSlot(String groundName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ParkingSlotPage(
          bookedSlots: bookedSlots,
          onSlotUpdated: (slotIndex, isBooked) {
            setState(() {
              bookedSlots[slotIndex] = isBooked;
              if (isBooked) {
                bookingHistory.add({
                  "slotNumber": slotIndex + 1,
                  "dateTime": DateTime.now().toString(),
                });
              } else {
                bookingHistory.removeWhere((booking) => booking["slotNumber"] == slotIndex + 1);
              }
            });
          },
        ),
      ),
    );
  }
}
