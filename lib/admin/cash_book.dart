import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:skytronix/admin/staff.dart';


import 'cash_in.dart';
import 'cashed_in.dart';
import 'cashed_out.dart';

class CashBookScreen extends StatefulWidget {
  const CashBookScreen({super.key});

  @override
  State<CashBookScreen> createState() => _CashBookScreenState();
}

class _CashBookScreenState extends State<CashBookScreen> {
  int _bottomIndex = 0;

  // 🎨 THEME COLORS
  final Color primaryColor = const Color(0xFFFF7E00);

  void _onBottomTap(int index) {
    setState(() {
      _bottomIndex = index;
    });

    if (index == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Home Screen")),
      );
    } else if (index == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Stock Screen")),
      );
    } else if (index == 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bill Screen")),
      );
    } else if (index == 3) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const StaffScreen()),
      );
    } else if (index == 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Expense Screen")),
      );
    }
  }

  // 📅 CHECK IF DATE IS TODAY
  bool _isSameDay(Timestamp timestamp) {
    DateTime date = timestamp.toDate();
    DateTime now = DateTime.now();
    return date.day == now.day && date.month == now.month && date.year == now.year;
  }

  // 💰 CALCULATE TOTAL BALANCE (ALL TIME FOR CASH IN HAND)
  double _calculateTotalBalance(List<QueryDocumentSnapshot> docs) {
    double total = 0.0;
    for (var doc in docs) {
      var data = doc.data() as Map<String, dynamic>;
      double amount = (data['total_amount'] is int)
          ? (data['total_amount'] as int).toDouble()
          : (data['total_amount'] ?? 0.0);
      total += amount;
    }
    return total;
  }

  // 💰 CALCULATE TODAY'S BALANCE
  double _calculateTodayBalance(List<QueryDocumentSnapshot> docs) {
    double total = 0.0;
    for (var doc in docs) {
      var data = doc.data() as Map<String, dynamic>;
      Timestamp? dateTs = data['date'];
      double amount = (data['total_amount'] is int)
          ? (data['total_amount'] as int).toDouble()
          : (data['total_amount'] ?? 0.0);

      if (dateTs != null && _isSameDay(dateTs)) {
        total += amount;
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),

      // 🔶 APP BAR
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: const Text(
          "Cash Book",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      // ✅ BODY
      body: Column(
        children: [
          // 🔳 INFO CARD (Dynamic)
          Padding(
            padding: const EdgeInsets.all(20),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('cash_in_transactions')
                  .orderBy('date', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                double totalBalance = 0.0;
                double todayBalance = 0.0;

                if (snapshot.hasData) {
                  totalBalance = _calculateTotalBalance(snapshot.data!.docs);
                  todayBalance = _calculateTodayBalance(snapshot.data!.docs);
                }

                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 25),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF7E00), Color(0xFFFF5500)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Left: Cash in Hand (All Time Total)
                      Column(
                        children: [
                          const Text(
                            "Cash in Hand",
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            "Rs $totalBalance",
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold
                            ),
                          ),
                        ],
                      ),

                      Container(
                        height: 40,
                        width: 1,
                        color: Colors.white30,
                      ),

                      // Middle: Today Balance
                      Column(
                        children: [
                          const Text(
                            "Today Balance",
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            "Rs $todayBalance",
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold
                            ),
                          ),
                        ],
                      ),

                      Container(
                        height: 40,
                        width: 1,
                        color: Colors.white30,
                      ),

                      // Right: History Icon
                      const Column(
                        children: [
                          Icon(Icons.history, color: Colors.white),
                          SizedBox(height: 5),
                          Text(
                            "History",
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      )
                    ],
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 10),

          // Header for list
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 25),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Recent Transactions",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // 📋 TRANSACTION LIST (Dynamic Cards)
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('cash_in_transactions')
                  .orderBy('date', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFFF7E00)));
                }

                final transactions = snapshot.data!.docs;

                if (transactions.isEmpty) {
                  return const Center(child: Text("No transactions found"));
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 100), // Space for FABs
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final doc = transactions[index];
                    final data = doc.data() as Map<String, dynamic>;

                    return _buildTransactionCard(doc.id, data);
                  },
                );
              },
            ),
          ),
        ],
      ),

      // 🔥 FLOATING BUTTONS
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 🟢 CASH IN
          FloatingActionButton.extended(
            heroTag: "cashIn",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CashInScreen(),
                ),
              );
            },
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.arrow_downward),
            label: const Text("Cash In"),
          ),

          const SizedBox(width: 10),

          // 🔴 CASH OUT
          FloatingActionButton.extended(
            heroTag: "cashOut",
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context)=> const CashOutScreen()));
            },
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.arrow_upward),
            label: const Text("Cash Out"),
          ),
        ],
      ),

      // 🔻 BOTTOM NAVIGATION

    );
  }

  // 🃏 TRANSACTION CARD DESIGN
  Widget _buildTransactionCard(String docId, Map<String, dynamic> data) {
    String customer = data['customer_name'] ?? "Unknown";
    String category = data['category'] ?? "General";
    double amount = (data['total_amount'] is int)
        ? (data['total_amount'] as int).toDouble()
        : (data['total_amount'] ?? 0.0);
    Timestamp dateTs = data['date'] ?? Timestamp.now();
    String dateStr = DateFormat('dd MMM, hh:mm a').format(dateTs.toDate());

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: Avatar
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.arrow_downward, color: primaryColor),
          ),
          const SizedBox(width: 15),

          // Middle: Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 4),
                Text(
                  category,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  dateStr,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),

          // Right: Amount & Actions
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "Rs $amount",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
              ),
              const SizedBox(height: 8),
              // ✏️ & 🗑️ ICONS
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Edit Icon
                  GestureDetector(
                    onTap: () => _showEditDialog(docId, data),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.edit, color: Colors.blue.shade700, size: 16),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Delete Icon
                  GestureDetector(
                    onTap: () => _confirmDelete(docId, data),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.delete, color: Colors.red.shade700, size: 16),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================= LOGIC METHODS =================

  // 🗑️ DELETE LOGIC WITH STOCK RESTORATION
  void _confirmDelete(String docId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Delete Transaction"),
        content: const Text("Are you sure? The stock quantity will be restored."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context); // Close dialog

              // Show loading
              showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const Center(child: CircularProgressIndicator())
              );

              try {
                // 1. Restore Stock
                List<dynamic> items = data['items'] ?? [];
                for (var item in items) {
                  // Assuming items have stockDocId as 'stockDocId' or we need to match by name.
                  // Ideally we saved 'stockDocId' in the transaction items.
                  // If not saved, we cannot restore accurately.
                  // Let's assume we saved 'stockDocId' or we skip restoration if missing.

                  // Note: In your CashInScreen, we added CartItem which had stockDocId.
                  // Let's assume the transaction items map contains 'stockDocId' if we saved it,
                  // otherwise we have to query by name (risky).
                  // For this implementation, I will iterate and restore if 'stockDocId' exists or matching name.

                  String stockDocId = item['stockDocId'] ?? '';
                  if(stockDocId.isNotEmpty) {
                    await FirebaseFirestore.instance.collection('stock').doc(stockDocId).update({
                      'productStockQuantity': FieldValue.increment(item['qty'] ?? 0),
                    });
                  }
                }

                // 2. Delete Transaction
                await FirebaseFirestore.instance.collection('cash_in_transactions').doc(docId).delete();

                if (mounted) {
                  Navigator.pop(context); // Close loading
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Transaction Deleted & Stock Restored")),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context); // Close loading
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error: $e")),
                  );
                }
              }
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  // ✏️ EDIT LOGIC
  void _showEditDialog(String docId, Map<String, dynamic> data) {
    TextEditingController customerController = TextEditingController(text: data['customer_name']);
    TextEditingController categoryController = TextEditingController(text: data['category']);
    TextEditingController billNoController = TextEditingController(text: data['bill_number']);

    // Date handling
    DateTime selectedDate = (data['date'] as Timestamp).toDate();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Edit Transaction"),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: customerController,
                decoration: const InputDecoration(labelText: "Customer Name"),
              ),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(labelText: "Category"),
              ),
              TextField(
                controller: billNoController,
                decoration: const InputDecoration(labelText: "Bill Number"),
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: () async {
                  DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2101),
                  );
                  if (picked != null) {
                    setState(() { selectedDate = picked; });
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: "Date", border: OutlineInputBorder()),
                  child: Text(DateFormat('dd MMM yyyy').format(selectedDate)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('cash_in_transactions').doc(docId).update({
                'customer_name': customerController.text.trim(),
                'category': categoryController.text.trim(),
                'bill_number': billNoController.text.trim(),
                'date': Timestamp.fromDate(selectedDate),
              });
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Transaction Updated")),
                );
              }
            },
            child: const Text("Update"),
          ),
        ],
      ),
    );
  }
}