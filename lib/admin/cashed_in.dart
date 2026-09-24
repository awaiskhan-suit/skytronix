import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CashInScreen extends StatefulWidget {
  const CashInScreen({super.key});

  @override
  State<CashInScreen> createState() => _CashInScreenState();
}

class _CashInScreenState extends State<CashInScreen> {
  // Controllers
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _receivedFromController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _refNoController = TextEditingController();

  // Date State
  DateTime _selectedDate = DateTime.now();

  // Search State
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  // Payment Method State
  String? _selectedPaymentMethod;
  final List<String> _paymentMethods = ['Cash', 'Bank Transfer', 'JazzCash', 'Easypaisa', 'Cheque', 'Online'];

  // Theme
  final Color kPrimaryColor = Colors.green; // Emerald Green
  final Color kAccentColor = Colors.green;
  final Color kBgColor = const Color(0xFFF4F7F6);

  // Formatters
  final currencyFormatter = NumberFormat.currency(symbol: "Rs ", decimalDigits: 0);
  final dateFormatter = DateFormat('dd MMM yyyy');
  final timeFormatter = DateFormat('hh:mm a');

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _receivedFromController.dispose();
    _reasonController.dispose();
    _refNoController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // --- SAVE / UPDATE LOGIC ---
  Future<void> _saveCashIn(String? id) async {
    if (_amountController.text.isEmpty || _receivedFromController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter amount and receiver name")),
      );
      return;
    }

    final data = {
      "amount": double.parse(_amountController.text),
      "receivedFrom": _receivedFromController.text,
      "reason": _reasonController.text,
      "paymentMethod": _selectedPaymentMethod ?? 'Cash',
      "refNo": _refNoController.text,
      "date": Timestamp.fromDate(_selectedDate),
    };

    if (id == null) {
      // Add New
      await FirebaseFirestore.instance.collection('cash_in').add(data);
    } else {
      // Update Existing
      await FirebaseFirestore.instance.collection('cash_in').doc(id).update(data);
    }

    Navigator.pop(context);
    _clearFields();
  }

  void _clearFields() {
    _amountController.clear();
    _receivedFromController.clear();
    _reasonController.clear();
    _refNoController.clear();
    _selectedPaymentMethod = null;
    _selectedDate = DateTime.now();
  }

  void _populateFields(Map<String, dynamic> data) {
    _amountController.text = (data['amount'] ?? 0).toString();
    _receivedFromController.text = data['receivedFrom'] ?? '';
    _reasonController.text = data['reason'] ?? '';
    _refNoController.text = data['refNo'] ?? '';
    _selectedPaymentMethod = data['paymentMethod'];
    _selectedDate = (data['date'] as Timestamp).toDate();
  }

  void _showAddDialog({String? id, Map<String, dynamic>? data}) {
    // Populate fields if editing, otherwise clear
    if (data != null) {
      _populateFields(data);
    } else {
      _clearFields();
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(id == null ? "Add Cash In" : "Edit Cash In", style: const TextStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Date Picker
                  InkWell(
                    onTap: () async {
                      DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() => _selectedDate = picked);
                        setDialogState(() => _selectedDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                          const SizedBox(width: 10),
                          Text(dateFormatter.format(_selectedDate)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // Received From
                  TextField(
                    controller: _receivedFromController,
                    decoration: const InputDecoration(
                      labelText: "Received From",
                      hintText: "Person / Customer Name",
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // Amount Received
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Amount Received",
                      prefixIcon: Icon(Icons.money),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // Payment Method Dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedPaymentMethod,
                    decoration: const InputDecoration(
                      labelText: "Payment Method",
                      prefixIcon: Icon(Icons.payment),
                      border: OutlineInputBorder(),
                    ),
                    items: _paymentMethods.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() => _selectedPaymentMethod = newValue);
                      setDialogState(() => _selectedPaymentMethod = newValue);
                    },
                  ),
                  const SizedBox(height: 15),

                  // Reference Number
                  TextField(
                    controller: _refNoController,
                    decoration: const InputDecoration(
                      labelText: "Reference Number",
                      hintText: "TRX ID / Cheque No",
                      prefixIcon: Icon(Icons.numbers),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // Reason
                  TextField(
                    controller: _reasonController,
                    decoration: const InputDecoration(
                      labelText: "Reason",
                      hintText: "Kis liye aayi (Purpose)",
                      prefixIcon: Icon(Icons.description),
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () => _saveCashIn(id), // Pass ID to check update vs add
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text("Save", style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: kPrimaryColor,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text("Cash In", style: TextStyle(fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // --- TOTAL INCOME CARD ---
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [kPrimaryColor, kAccentColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: kPrimaryColor.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Total Income",
                  style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('cash_in').snapshots(),
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
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // --- SEARCH BAR ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search by Name, Reason or Ref #...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // --- LIST VIEW ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('cash_in')
                  .orderBy('date', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.orange));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.savings_outlined, size: 60, color: Colors.grey.shade300),
                        const SizedBox(height: 10),
                        Text("No cash records found", style: TextStyle(color: Colors.grey.shade500)),
                      ],
                    ),
                  );
                }

                // Filter Logic
                final allDocs = snapshot.data!.docs;
                final filteredDocs = allDocs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  final name = (data['receivedFrom'] ?? '').toString().toLowerCase();
                  final reason = (data['reason'] ?? '').toString().toLowerCase();
                  final refNo = (data['refNo'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery) || reason.contains(_searchQuery) || refNo.contains(_searchQuery);
                }).toList();

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    var doc = filteredDocs[index];
                    var data = doc.data() as Map<String, dynamic>;
                    return _buildCashInCard(data, doc.id);
                  },
                );
              },
            ),
          ),
        ],
      ),

      // --- FLOATING ACTION BUTTON ---
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(),
        backgroundColor: kPrimaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Add Cash", style: TextStyle(color: Colors.white)),
      ),
    );
  }

  // --- WIDGET: CASH IN CARD ---
  Widget _buildCashInCard(Map<String, dynamic> data, String docId) {
    Timestamp ts = data['date'] ?? Timestamp.now();
    DateTime dt = ts.toDate();

    final String paymentMethod = data['paymentMethod'] ?? 'Cash';
    final String refNo = data['refNo'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Date and Actions (Edit & Delete)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                  const SizedBox(width: 5),
                  Text(dateFormatter.format(dt), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              Row(
                children: [
                  // --- EDIT BUTTON ---
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                    onPressed: () => _showAddDialog(id: docId, data: data),
                  ),
                  // --- DELETE BUTTON ---
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text("Delete Record?"),
                          content: const Text("Are you sure you want to delete this cash entry?"),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                            TextButton(
                              onPressed: () async {
                                await FirebaseFirestore.instance.collection('cash_in').doc(docId).delete();
                                if(mounted) Navigator.pop(ctx);
                              },
                              child: const Text("Delete", style: TextStyle(color: Colors.red)),
                            )
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 10),

          // Row 2: Received From
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person, size: 16, color: Colors.orange),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Received From", style: TextStyle(fontSize: 11, color: Colors.grey)),
                    Text(
                      data['receivedFrom'] ?? 'Unknown',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Row 3: Payment Method & Ref No
          Row(
            children: [
              const SizedBox(width: 44), // Alignment with icon above
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 5,
                  children: [
                    // Payment Method Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: kPrimaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: kPrimaryColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        paymentMethod,
                        style: const TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w600),
                      ),
                    ),
                    // Reference Number
                    if (refNo.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.receipt_long, size: 12, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            "Ref: $refNo",
                            style: const TextStyle(fontSize: 11, color: Colors.black54),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Row 4: Reason
          Row(
            children: [
              const SizedBox(width: 44),
              Expanded(
                child: Text(
                  data['reason'] ?? 'No reason provided',
                  style: const TextStyle(fontSize: 13, color: Colors.black54, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          // Row 5: Amount
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Amount Received", style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600)),
                Text(
                  currencyFormatter.format(data['amount'] ?? 0.0),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
