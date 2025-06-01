import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'log_in.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? user;
  String fullName = "Loading...";
  String email = "Loading...";
  String phone = "Loading...";
  String profileImage = "";

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // 🔄 Fetch user data from Firebase Auth and Realtime Database
  Future<void> _loadUserData() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    await currentUser?.reload(); // Refresh user data

    if (currentUser != null) {
      setState(() {
        user = currentUser;
        email = user?.email ?? "No Email";
      });

      // 🔄 Fetch extra info from Realtime Database
      DatabaseReference ref = FirebaseDatabase.instance.ref("Users/${currentUser.uid}");

      DatabaseEvent event = await ref.once();
      if (event.snapshot.exists) {
        Map data = event.snapshot.value as Map;
        setState(() {
          fullName = data["name"] ?? "No Name";
          phone = data["mobile"] ?? "No Phone Number";
        });
      } else {
        setState(() {
          fullName = "Name not found";
          phone = "Phone not found";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.grey[300],
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 🏞 Profile Image
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.grey[300],
              backgroundImage: profileImage.isNotEmpty ? NetworkImage(profileImage) : null,
              child: profileImage.isEmpty
                  ? const Icon(Icons.person, size: 50, color: Colors.white)
                  : null,
            ),
            const SizedBox(height: 20),

            // 📋 Full Name Field
            buildProfileField("Full Name", fullName),
            const SizedBox(height: 15),

            // 📞 Phone Number Field
            buildProfileField("Phone Number", phone),
            const SizedBox(height: 15),

            // 📧 Email Address Field
            buildProfileField("Email Address", email),
            const SizedBox(height: 40),

            // 🔴 Log Out Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => LoginScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: const Text("Log out", style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 📌 Helper Widget for Read-Only Fields
  Widget buildProfileField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black54),
        ),
        const SizedBox(height: 5),
        TextField(
          readOnly: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey[200],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
          ),
          style: const TextStyle(fontSize: 16),
          controller: TextEditingController(text: value),
        ),
      ],
    );
  }
}
