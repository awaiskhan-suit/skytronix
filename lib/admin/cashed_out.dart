import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CashOutScreen extends StatefulWidget {
  const CashOutScreen({super.key});

  @override
  State<CashOutScreen> createState() => _CashOutScreenState();
}

class _CashOutScreenState extends State<CashOutScreen> {
  // Controllers
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _paidToController = TextEditingController(); // Changed from ReceivedFrom
  final TextEditingController _expenseTypeController = TextEditingController(); // Changed from Reason
  final TextEditingController _descriptionController = TextEditingController(); // New Field
  final TextEditingController _refNoController = TextEditingController();

  // Date State
  DateTime _selectedDate = DateTime.now();

  // Search State
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  // Payment Method State
  String? _selectedPaymentMethod;
  final List<String> _paymentMethods = ['Cash', 'Bank Transfer', 'JazzCash', 'Easypaisa', 'Cheque', 'Online'];

  // Theme (Changed to Red for Expense)
  final Color kPrimaryColor = Colors.red; // Red for Cash Out
  final Color kAccentColor = Colors.redAccent;
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
    _paidToController.dispose();
    _expenseTypeController.dispose();
    _descriptionController.dispose();
    _refNoController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // --- SAVE / UPDATE LOGIC ---
  Future<void> _saveCashOut(String? id) async {
    if (_amountController.text.isEmpty || _paidToController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter amount and paid to name")),
      );
      return;
    }

    final data = {
      "amount": double.parse(_amountController.text),
      "paidTo": _paidToController.text, // Mapped to paidTo
      "expenseType": _expenseTypeController.text, // Mapped to expenseType
      "description": _descriptionController.text, // New field
      "paymentMethod": _selectedPaymentMethod ?? 'Cash',
      "refNo": _refNoController.text,
      "date": Timestamp.fromDate(_selectedDate),
    };

    if (id == null) {
      // Add New
      await FirebaseFirestore.instance.collection('cashout').add(data);
    } else {
      // Update Existing
      await FirebaseFirestore.instance.collection('cashout').doc(id).update(data);
    }

    Navigator.pop(context);
    _clearFields();
  }

  void _clearFields() {
    _amountController.clear();
    _paidToController.clear();
    _expenseTypeController.clear();
    _descriptionController.clear();
    _refNoController.clear();
    _selectedPaymentMethod = null;
    _selectedDate = DateTime.now();
  }

  void _populateFields(Map<String, dynamic> data) {
    _amountController.text = (data['amount'] ?? 0).toString();
    _paidToController.text = data['paidTo'] ?? '';
    _expenseTypeController.text = data['expenseType'] ?? '';
    _descriptionController.text = data['description'] ?? '';
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
            title: Text(id == null ? "Add Cash Out" : "Edit Cash Out", style: const TextStyle(fontWeight: FontWeight.bold)),
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

                  // Paid To (Changed from Received From)
                  TextField(
                    controller: _paidToController,
                    decoration: const InputDecoration(
                      labelText: "Paid To",
                      hintText: "Person / Vendor Name",
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // Amount Paid
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Amount Paid",
                      prefixIcon: Icon(Icons.money_off),
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
                      hintText: "Invoice # / Receipt No",
                      prefixIcon: Icon(Icons.numbers),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // Expense Type
                  TextField(
                    controller: _expenseTypeController,
                    decoration: const InputDecoration(
                      labelText: "Expense Type",
                      hintText: "e.g. Rent, Food, Utility",
                      prefixIcon: Icon(Icons.category),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // Description Detail (New Field)
                  TextField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: "Description Detail",
                      hintText: "Additional details...",
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
                onPressed: () => _saveCashOut(id),
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
        title: const Text("Cash Out", style: TextStyle(fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // --- TOTAL EXPENSE CARD ---
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
                  "Total Expenses",
                  style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('cashout').snapshots(),
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
                hintText: "Search by Name, Type or Ref #...",
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
                  .collection('cashout')
                  .orderBy('date', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.red));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.money_off_csred_outlined, size: 60, color: Colors.grey.shade300),
                        const SizedBox(height: 10),
                        Text("No expense records found", style: TextStyle(color: Colors.grey.shade500)),
                      ],
                    ),
                  );
                }

                // Filter Logic (Updated for new fields)
                final allDocs = snapshot.data!.docs;
                final filteredDocs = allDocs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  final name = (data['paidTo'] ?? '').toString().toLowerCase();
                  final type = (data['expenseType'] ?? '').toString().toLowerCase();
                  final desc = (data['description'] ?? '').toString().toLowerCase();
                  final refNo = (data['refNo'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery) || type.contains(_searchQuery) || desc.contains(_searchQuery) || refNo.contains(_searchQuery);
                }).toList();

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    var doc = filteredDocs[index];
                    var data = doc.data() as Map<String, dynamic>;
                    return _buildCashOutCard(data, doc.id);
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
        icon: const Icon(Icons.remove, color: Colors.white), // Changed icon to minus/remove
        label: const Text("Add Expense", style: TextStyle(color: Colors.white)),
      ),
    );
  }

  // --- WIDGET: CASH OUT CARD ---
  Widget _buildCashOutCard(Map<String, dynamic> data, String docId) {
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
                          content: const Text("Are you sure you want to delete this expense entry?"),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                            TextButton(
                              onPressed: () async {
                                await FirebaseFirestore.instance.collection('cashout').doc(docId).delete();
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

          // Row 2: Paid To
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_outline, size: 16, color: Colors.red), // Red Icon
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Paid To", style: TextStyle(fontSize: 11, color: Colors.grey)),
                    Text(
                      data['paidTo'] ?? 'Unknown',
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
                        style: const TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w600),
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

          // Row 4: Expense Type & Description
          Row(
            children: [
              const SizedBox(width: 44),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Expense Type
                    Text(
                      data['expenseType'] ?? 'General Expense',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                    ),
                    // Description
                    if (data['description'] != null && data['description'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: Text(
                          data['description'],
                          style: const TextStyle(fontSize: 12, color: Colors.black54, fontStyle: FontStyle.italic),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          // Row 5: Amount
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Amount Paid", style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w600)),
                Text(
                  "- ${currencyFormatter.format(data['amount'] ?? 0.0)}", // Added minus sign
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
