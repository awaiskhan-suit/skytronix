import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class InvoiceListScreen extends StatefulWidget {
  const InvoiceListScreen({super.key});

  @override
  State<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen> {
  // Theme Color to match the app
  final Color primaryColor = const Color(0xFFFF7E00);

  // Search Logic
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- LOGIC: DELETE INVOICE ---
  Future<void> _deleteInvoice(String docId, String customerName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Invoice?"),
        content: Text("Are you sure you want to delete the invoice for $customerName?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('invoices')
            .doc(docId)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Invoice deleted successfully")),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error deleting invoice: $e")),
          );
        }
      }
    }
  }

  // --- LOGIC: WHATSAPP ---
  Future<void> openWhatsApp(String phone) async {
    // Remove non-numeric characters
    phone = phone.replaceAll(RegExp(r'[^\d]'), '');

    if (phone.startsWith('0')) {
      phone = '92${phone.substring(1)}';
    } else if (!phone.startsWith('92')) {
      phone = '92$phone';
    }

    final Uri whatsappUrl = Uri.parse("whatsapp://send?phone=$phone");
    final Uri webUrl = Uri.parse("https://wa.me/$phone");

    try {
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl);
      } else {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open WhatsApp")),
      );
    }
  }

  // --- HELPER: FORMAT DATE (Handles Firestore Timestamps) ---
  String _formatDate(dynamic dateData) {
    try {
      DateTime dt;
      if (dateData is Timestamp) {
        dt = dateData.toDate();
      } else if (dateData is DateTime) {
        dt = dateData;
      } else {
        return dateData.toString();
      }
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (e) {
      return "Invalid Date";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Invoices History"),
        backgroundColor: primaryColor, // Changed to Orange to match App Theme
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          // --- SEARCH BAR ---
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: "Search by customer name or invoice #...",
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    vertical: 15, horizontal: 20),
              ),
            ),
          ),

          // --- INVOICE LIST ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('invoices')
                  .orderBy('date', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFFF7E00)));
                }

                if (snapshot.hasError) {
                  return const Center(child: Text("Error loading invoices"));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No invoices found"));
                }

                final invoices = snapshot.data!.docs;

                // FILTER LOGIC
                final filteredInvoices = invoices.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['customerName'] ?? '').toString().toLowerCase();
                  final invNo = (data['invoiceNo'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery) || invNo.contains(_searchQuery);
                }).toList();

                if (filteredInvoices.isEmpty) {
                  return const Center(child: Text("No matching invoices found"));
                }

                // ✅ CHANGED: Return a Column to hold the Card and the List
                return Column(
                  children: [
                    // 📊 SUMMARY CARD (New)
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, 5))
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.receipt_long, color: primaryColor, size: 28),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Total Invoices", style: TextStyle(color: Colors.grey, fontSize: 12)),
                                const SizedBox(height: 4),
                                Text("${filteredInvoices.length} Records", style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 📋 LIST
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                        itemCount: filteredInvoices.length,
                        itemBuilder: (context, index) {
                          final doc = filteredInvoices[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final docId = doc.id;

                          // ✅ UPDATED FIELDS to match BillScreen
                          final invNo = data['invoiceNo'] ?? 'N/A';
                          final customerName = data['customerName'] ?? 'Unknown';
                          final phone = data['customerPhone'] ?? '';
                          // ✅ FIXED: Uses 'totalAmount' instead of 'total'
                          final total = (data['totalAmount'] ?? 0.0).toDouble();
                          final paymentMethod = data['paymentMethod'] ?? 'Cash';
                          final dateStr = _formatDate(data['date']);

                          return Card(
                            elevation: 3,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Row: Invoice # & Name | Date
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              invNo,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              customerName,
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: primaryColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          dateStr,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: primaryColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // Row: Phone & Payment
                                  Row(
                                    children: [
                                      const Icon(Icons.phone, size: 16, color: Colors.grey),
                                      const SizedBox(width: 5),
                                      Text(
                                        phone.isEmpty ? "No Phone" : phone,
                                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                                      ),
                                      const Spacer(),
                                      const Icon(Icons.payment, size: 16, color: Colors.grey),
                                      const SizedBox(width: 5),
                                      Text(
                                        paymentMethod,
                                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                                      ),
                                    ],
                                  ),

                                  const Divider(height: 20),

                                  // Row: Total & Actions
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "Total: Rs ${total.toStringAsFixed(0)}",
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: primaryColor, // Orange Total
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          // WhatsApp
                                          IconButton(
                                            icon: const FaIcon(
                                              FontAwesomeIcons.whatsapp,
                                              color: Colors.green,
                                            ),
                                            onPressed: () => openWhatsApp(phone),
                                          ),

                                          // Delete
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline,
                                                color: Colors.red),
                                            tooltip: "Delete Invoice",
                                            onPressed: () =>
                                                _deleteInvoice(docId, customerName),
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