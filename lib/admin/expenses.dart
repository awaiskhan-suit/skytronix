import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  DateTime selectedDate = DateTime.now();

  final titleController = TextEditingController();
  final amountController = TextEditingController();
  final descController = TextEditingController();
  final categoryController = TextEditingController();

  @override
  void dispose() {
    titleController.dispose();
    amountController.dispose();
    descController.dispose();
    categoryController.dispose();
    super.dispose();
  }

  /// 🔹 Add Expense
  Future<void> addExpense() async {
    if (titleController.text.isEmpty || amountController.text.isEmpty) return;

    await FirebaseFirestore.instance.collection('expenses').add({
      "title": titleController.text,
      "amount": double.parse(amountController.text),
      "category": categoryController.text,
      "description": descController.text,
      "date": Timestamp.fromDate(selectedDate),
    });

    Navigator.pop(context);
    clearFields();
  }

  /// 🔹 Update Expense
  Future<void> updateExpense(String id) async {
    await FirebaseFirestore.instance.collection('expenses').doc(id).update({
      "title": titleController.text,
      "amount": double.parse(amountController.text),
      "category": categoryController.text,
      "description": descController.text,
    });

    Navigator.pop(context);
    clearFields();
  }

  /// 🔹 Delete Expense
  Future<void> deleteExpense(String id) async {
    await FirebaseFirestore.instance.collection('expenses').doc(id).delete();
  }

  /// 🔹 Clear Fields
  void clearFields() {
    titleController.clear();
    amountController.clear();
    descController.clear();
    categoryController.clear();
  }

  /// 🔹 Show Add/Edit Dialog
  void showExpenseDialog({String? id, Map<String, dynamic>? data}) {
    if (data != null) {
      titleController.text = data['title'];
      amountController.text = data['amount'].toString();
      descController.text = data['description'];
      categoryController.text = data['category'];
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(id == null ? "Add Expense" : "Edit Expense"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: "Title"),
              ),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(labelText: "Category (e.g. Rent, Food)"),
              ),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Amount"),
              ),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: "Description"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              clearFields();
            },
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              if (id == null) {
                addExpense();
              } else {
                updateExpense(id);
              }
            },
            child: const Text("Save"),
          )
        ],
      ),
    );
  }

  /// 🔹 Date Picker
  void pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() => selectedDate = picked);
    }
  }

  /// 🔹 Get Start & End of Day
  DateTime get startOfDay =>
      DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

  DateTime get endOfDay =>
      DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 23, 59);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Expenses"),
        foregroundColor: Colors.white,
        centerTitle: true,
        backgroundColor: Colors.orange.shade700,
      ),

      /// ➕ FLOAT BUTTON
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        onPressed: () => showExpenseDialog(),
        child: const Icon(Icons.add),
      ),

      body: Column(
        children: [
          /// 📅 DATE
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: pickDate,
                  icon: const Icon(Icons.calendar_today),
                  label: Text(DateFormat('dd MMM yyyy').format(selectedDate)),
                ),
              ],
            ),
          ),

          /// 📊 LIST + TOTAL
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance
                  .collection('expenses')
                  .where("date", isGreaterThanOrEqualTo: startOfDay)
                  .where("date", isLessThanOrEqualTo: endOfDay)
                  .snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var docs = snapshot.data!.docs;

                double total = 0;
                for (var doc in docs) {
                  total += doc['amount'];
                }

                return Column(
                  children: [
                    /// 💰 TOTAL
                    Container(
                      padding: const EdgeInsets.all(12),
                      color: Colors.red.shade100,
                      width: double.infinity,
                      child: Text(
                        "Total: Rs ${total.toStringAsFixed(0)}",
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),

                    /// 📋 LIST
                    Expanded(
                      child: ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          var data =
                          docs[index].data() as Map<String, dynamic>;
                          String id = docs[index].id;

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Left Side: Details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Title
                                        Text(
                                          data['title'] ?? 'No Title',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 4),

                                        // Category
                                        Text(
                                          data['category'] ?? 'General',
                                          style: TextStyle(
                                            color: Colors.orange.shade700,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),

                                        // ✅ Description (Added here)
                                        if (data['description'] != null &&
                                            data['description'].toString().isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4.0),
                                            child: Text(
                                              data['description'],
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey,
                                              ),
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),

                                  // Right Side: Amount & Actions
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      // Amount
                                      Text(
                                        "Rs ${data['amount'].toStringAsFixed(0)}",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.black,
                                        ),
                                      ),
                                      const SizedBox(height: 8),

                                      // Action Icons
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Edit
                                          InkWell(
                                            onTap: () =>
                                                showExpenseDialog(id: id, data: data),
                                            child: const Icon(Icons.edit,
                                                size: 20, color: Colors.blue),
                                          ),
                                          const SizedBox(width: 10),
                                          // Delete
                                          InkWell(
                                            onTap: () {
                                              showDialog(
                                                context: context,
                                                builder: (_) => AlertDialog(
                                                  title: const Text("Delete"),
                                                  content: const Text(
                                                      "Are you sure you want to delete?"),
                                                  actions: [
                                                    TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(context),
                                                        child: const Text("Cancel")),
                                                    ElevatedButton(
                                                      onPressed: () {
                                                        deleteExpense(id);
                                                        Navigator.pop(context);
                                                      },
                                                      child: const Text("Delete"),
                                                    )
                                                  ],
                                                ),
                                              );
                                            },
                                            child: const Icon(Icons.delete,
                                                size: 20, color: Colors.red),
                                          ),
                                        ],
                                      )
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}