import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  _WalletScreenState createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref("Users");
  final User? _user = FirebaseAuth.instance.currentUser;

  double _balance = 0.0;
  List<Map<String, dynamic>> _transactions = [];
  late Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    _listenToWalletChanges();
    _razorpay = Razorpay();

    // Razorpay Event Listeners
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear(); // Clean up Razorpay resources
    super.dispose();
  }

  /// **Listen for Real-Time Wallet Updates from Firebase**
  void _listenToWalletChanges() {
    if (_user == null) return;
    DatabaseReference userWalletRef = _dbRef.child(_user!.uid);

    userWalletRef.onValue.listen((event) {
      if (event.snapshot.exists) {
        Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;

        setState(() {
          _balance = double.tryParse(data["balance"].toString()) ?? 0.0;
          _transactions = (data["transactions"] as Map<dynamic, dynamic>?)
                  ?.values
                  .map((txn) => Map<String, dynamic>.from(txn))
                  .toList() ??
              [];

          _transactions.sort((a, b) => b["date"].compareTo(a["date"])); // Sort transactions
        });

        print("🔄 Wallet Updated: ₹$_balance");
      }
    }, onError: (error) {
      _showMessage("⚠️ Failed to load wallet data");
    });
  }

  /// **Razorpay Payment Integration**
  void _rechargeWallet() {
    var options = {
      'key': 'rzp_test_bfZpMcNoBvJZcB', // Replace with your Razorpay Key
      'amount': 10000, // Amount in paise (₹100.00)
      'currency': 'INR',
      'name': 'Smart Parking Wallet',
      'description': 'Wallet Recharge',
      'prefill': {
        'email': _user?.email ?? 'test@example.com',
        'contact': '9999999999' // Replace with the user's phone number
      },
      'theme': {'color': '#3399cc'}
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      print("⚠️ Error launching Razorpay: $e");
      _showMessage("⚠️ Error launching Razorpay");
    }
  }

  /// **Handle Successful Payment**
  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    print("✅ Payment Success: ${response.paymentId}");

    _updateBalance(100.0); // Add ₹100 to the wallet
    _showMessage("✅ Payment Successful! ₹100 added to wallet.");
  }

  /// **Handle Payment Failure**
  void _handlePaymentError(PaymentFailureResponse response) {
    print("❌ Payment Failed: ${response.message}");
    _showMessage("❌ Payment Failed. Try again.");
  }

  /// **Handle External Wallet Selection**
  void _handleExternalWallet(ExternalWalletResponse response) {
    print("💳 External Wallet Used: ${response.walletName}");
    _showMessage("💳 External Wallet Used: ${response.walletName}");
  }

  /// **Update Balance in Firebase**
  Future<void> _updateBalance(double amount) async {
    if (_user == null) return;

    DatabaseReference userWalletRef = _dbRef.child(_user!.uid);
    await userWalletRef.update({"balance": _balance + amount});
  }

  /// **Show Snackbar Message**
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Wallet"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _listenToWalletChanges,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// **Wallet Balance**
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Wallet Balance",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text("₹$_balance",
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            /// **Recharge Button**
            Center(
              child: ElevatedButton.icon(
                onPressed: _rechargeWallet,
                icon: const Icon(Icons.account_balance_wallet),
                label: const Text("Recharge Wallet"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 20),

            /// **Transaction History**
            const Text("Transaction History",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            Expanded(
              child: _transactions.isEmpty
                  ? const Center(child: Text("No transactions yet"))
                  : ListView.builder(
                      itemCount: _transactions.length,
                      itemBuilder: (context, index) {
                        final txn = _transactions[index];
                        return Card(
                          child: ListTile(
                            leading: Icon(
                              txn['type'] == 'Credit' ? Icons.add_circle : Icons.remove_circle,
                              color: txn['type'] == 'Credit' ? Colors.green : Colors.red,
                            ),
                            title: Text(
                              "${txn['type']} ₹${txn['amount']}",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: txn['type'] == 'Credit' ? Colors.green : Colors.red,
                              ),
                            ),
                            subtitle: Text(txn['date']),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
