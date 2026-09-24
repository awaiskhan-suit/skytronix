import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  // Default to today
  DateTime selectedDate = DateTime.now();
  final Color primaryColor = const Color(0xFFFF7E00);
  final Color secondaryColor = const Color(0xFF2C3E50);

  // Formatters
  final currencyFormatter = NumberFormat.currency(symbol: "Rs ", decimalDigits: 0);
  final dateFormatter = DateFormat('dd MMM yyyy');
  final timeFormatter = DateFormat('hh:mm a');

  // Pick Date
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculate start and end of the selected day for Firestore query
    final startOfDay =
    DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    // Calculate start and end of the SELECTED YEAR for the Yearly Card
    final startOfYear = DateTime(selectedDate.year, 1, 1);
    final startOfNextYear = DateTime(selectedDate.year + 1, 1, 1);

    // Calculate start and end of TODAY (Actual current date) for the Today's Card
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final endOfToday = startOfToday.add(const Duration(days: 1));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text("Sales Report",
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 1. DATE SELECTOR HEADER
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: Color(0xFFFF7E00)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Date: ${dateFormatter.format(selectedDate)}",
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 5),
                TextButton.icon(
                  onPressed: () => _selectDate(context),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text("Edit"),
                  style: TextButton.styleFrom(
                      foregroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 5)),
                )
              ],
            ),
          ),
          const SizedBox(height: 10),

          // 2. SCROLLABLE CONTENT
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- SUMMARY ROW 1 (Year & Today) ---
                  Row(
                    children: [
                      Expanded(
                        child: _buildStreamSummaryCard(
                          title: "${selectedDate.year} Sales",
                          // Query for the selected year
                          stream: FirebaseFirestore.instance
                              .collection('invoices')
                              .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfYear))
                              .where('date', isLessThan: Timestamp.fromDate(startOfNextYear))
                              .snapshots(),
                          icon: Icons.calendar_view_month,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildStreamSummaryCard(
                          title: "Today's Sales",
                          // Query for actual today
                          stream: FirebaseFirestore.instance
                              .collection('invoices')
                              .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday))
                              .where('date', isLessThan: Timestamp.fromDate(endOfToday))
                              .snapshots(),
                          icon: Icons.today,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // --- SUMMARY ROW 2 (All Time Sales & Profit) ---
                  Row(
                    children: [
                      // Card 3: All Time Sales
                      Expanded(
                        child: _buildAllTimeSalesCard(),
                      ),
                      const SizedBox(width: 10),
                      // Card 4: Total Profit
                      Expanded(
                        child: _buildProfitCard(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // --- NEW ROW 3: Total Expenses ---
                  Row(
                    children: [
                      Expanded(
                        child: _buildTotalExpensesCard(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),

                  // --- SELECTED DATE TOTAL (Gradient Card) ---
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: [primaryColor, Colors.deepOrange]),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                            color: primaryColor.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 5))
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Sales on ${dateFormatter.format(selectedDate)}",
                            style: const TextStyle(color: Colors.white70, fontSize: 14)),
                        const SizedBox(height: 5),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('invoices')
                              .where('date',
                              isGreaterThanOrEqualTo:
                              Timestamp.fromDate(startOfDay))
                              .where('date',
                              isLessThan: Timestamp.fromDate(endOfDay))
                              .snapshots(),
                          builder: (context, snapshot) {
                            double dailyTotal = 0.0;
                            if (snapshot.hasData) {
                              for (var doc in snapshot.data!.docs) {
                                dailyTotal += (doc.data()
                                as Map<String, dynamic>)['totalAmount'] ??
                                    0.0;
                              }
                            }
                            return Text(
                              currencyFormatter.format(dailyTotal),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- PAYMENT METHOD BREAKDOWN (UPDATED TO ALL TIME) ---
                  const Text("Payment Methods (All Time Total)",
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54)),
                  const SizedBox(height: 10),

                  // Stream for payment methods of ALL TIME (Removed date filters)
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('invoices')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const CircularProgressIndicator();

                      // Calculate stats for ALL TIME
                      double codTotal = 0;
                      double cardTotal = 0;
                      double easypaisaTotal = 0;
                      double jazzcashTotal = 0;

                      for (var doc in snapshot.data!.docs) {
                        var data = doc.data() as Map<String, dynamic>;
                        double amount = data['totalAmount'] ?? 0.0;
                        String method =
                            data['paymentMethod']?.toLowerCase() ?? '';

                        // --- FIXED LOGIC: Check specific methods first to avoid overlap ---
                        if (method.contains('jazzcash')) {
                          jazzcashTotal += amount;
                        } else if (method.contains('easypaisa')) {
                          easypaisaTotal += amount;
                        } else if (method.contains('card')) {
                          cardTotal += amount;
                        } else if (method.contains('cash')) {
                          // This now only catches 'Cash' or 'Cash on Delivery', not 'JazzCash'
                          codTotal += amount;
                        }
                      }

                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                  child: _buildPaymentCard("Cash on Delivery",
                                      codTotal, Icons.money_off, Colors.green)),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: _buildPaymentCard("Card", cardTotal,
                                      Icons.credit_card, Colors.blue)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                  child: _buildPaymentCard("Easypaisa",
                                      easypaisaTotal, Icons.phone_android, Colors.red)),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: _buildPaymentCard("JazzCash",
                                      jazzcashTotal, Icons.mobile_friendly, Colors.purple)),
                            ],
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 25),

                  // --- SALES LIST ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Transactions for ${dateFormatter.format(selectedDate)}",
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87)),
                    ],
                  ),
                  const SizedBox(height: 10),

                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('invoices')
                        .where('date',
                        isGreaterThanOrEqualTo:
                        Timestamp.fromDate(startOfDay))
                        .where('date',
                        isLessThan: Timestamp.fromDate(endOfDay))
                        .orderBy('date', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                            child: Padding(
                                padding: EdgeInsets.all(20),
                                child: CircularProgressIndicator()));
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(
                            child: Padding(
                                padding: const EdgeInsets.all(40),
                                child: Text("No sales found on ${dateFormatter.format(selectedDate)}.")));
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: snapshot.data!.docs.length,
                        itemBuilder: (context, index) {
                          var doc = snapshot.data!.docs[index];
                          var data = doc.data() as Map<String, dynamic>;
                          return _buildSalesCard(data, doc.id);
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 80), // Bottom padding
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- NEW: Total Expenses Card ---
  Widget _buildTotalExpensesCard() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.money_off, color: Colors.red, size: 20),
              const SizedBox(width: 5),
              const Expanded(
                child: Text("Total Expenses",
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('expenses').snapshots(),
            builder: (context, snapshot) {
              double total = 0.0;
              if (snapshot.hasData) {
                for (var doc in snapshot.data!.docs) {
                  total += (doc.data() as Map<String, dynamic>)['amount'] ?? 0.0;
                }
              }
              return Text(
                currencyFormatter.format(total),
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- All Time Sales Card ---
  Widget _buildAllTimeSalesCard() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.trending_up, color: Colors.purple, size: 20),
              const SizedBox(width: 5),
              const Expanded(
                child: Text("All Time Sales",
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('invoices').snapshots(),
            builder: (context, snapshot) {
              double total = 0.0;
              if (snapshot.hasData) {
                for (var doc in snapshot.data!.docs) {
                  total += (doc.data() as Map<String, dynamic>)['totalAmount'] ?? 0.0;
                }
              }
              return Text(
                currencyFormatter.format(total),
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: Colors.purple),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- Profit Card (Sales - Expenses) ---
  Widget _buildProfitCard() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet, color: Colors.teal, size: 20),
              const SizedBox(width: 5),
              const Expanded(
                child: Text("Total Profit",
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot>(
            // Fetch All Time Sales first
            stream: FirebaseFirestore.instance.collection('invoices').snapshots(),
            builder: (context, salesSnapshot) {
              double totalSales = 0.0;
              if (salesSnapshot.hasData) {
                for (var doc in salesSnapshot.data!.docs) {
                  totalSales += (doc.data() as Map<String, dynamic>)['totalAmount'] ?? 0.0;
                }
              }

              // Nested StreamBuilder for Expenses
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('expenses').snapshots(),
                builder: (context, expenseSnapshot) {
                  double totalExpenses = 0.0;
                  if (expenseSnapshot.hasData) {
                    for (var doc in expenseSnapshot.data!.docs) {
                      totalExpenses += (doc.data() as Map<String, dynamic>)['amount'] ?? 0.0;
                    }
                  }

                  double profit = totalSales - totalExpenses;
                  // Determine color based on profit value
                  Color profitColor = profit >= 0 ? Colors.teal : Colors.red;

                  return Text(
                    currencyFormatter.format(profit),
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold, color: profitColor),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // Helper widget to build summary cards that listen to a stream
  Widget _buildStreamSummaryCard({
    required String title,
    required Stream<QuerySnapshot> stream,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 5),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot>(
            stream: stream,
            builder: (context, snapshot) {
              double total = 0.0;
              if (snapshot.hasData) {
                for (var doc in snapshot.data!.docs) {
                  total += (doc.data() as Map<String, dynamic>)['totalAmount'] ?? 0.0;
                }
              }
              return Text(
                currencyFormatter.format(total),
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: color),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(
      String title, double amount, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 5),
              Text(title,
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            currencyFormatter.format(amount),
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesCard(Map<String, dynamic> data, String docId) {
    Timestamp timestamp = data['date'] ?? Timestamp.now();
    DateTime dateTime = timestamp.toDate();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Invoice # and Date
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "#${data['invoiceNo'] ?? 'N/A'}",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Text(
                timeFormatter.format(dateTime),
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          const Divider(height: 20),

          // Customer Info
          Row(
            children: [
              const Icon(Icons.person, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  data['customerName'] ?? 'Unknown Customer',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              const Icon(Icons.phone, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                data['customerPhone'] ?? 'N/A',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),

          const SizedBox(height: 15),

          // Bottom Row: Total and Payment Method
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  data['paymentMethod'] ?? 'Cash',
                  style: TextStyle(
                      color: Colors.blue.shade800,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                currencyFormatter.format(data['totalAmount'] ?? 0.0),
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF7E00)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}