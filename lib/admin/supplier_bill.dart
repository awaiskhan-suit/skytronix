import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart'; // Import for Date formatting

class SupplierBillingScreen extends StatefulWidget {
  const SupplierBillingScreen({super.key});

  @override
  State<SupplierBillingScreen> createState() => _SupplierBillingScreenState();
}

class _SupplierBillingScreenState extends State<SupplierBillingScreen> {
  // Form & Data State
  final TextEditingController _productController = TextEditingController();
  List<Map<String, dynamic>> _cartItems = []; // { 'name': String, 'quantity': int }
  List<QueryDocumentSnapshot> _suppliers = [];
  QueryDocumentSnapshot? _selectedSupplier;
  String _paymentMethod = 'Cash'; // Default

  // Loading State
  bool _isLoadingSuppliers = false;
  bool _isGeneratingPdf = false;

  @override
  void initState() {
    super.initState();
    _fetchSuppliers();
  }

  // ================= FIREBASE LOGIC =================
  Future<void> _fetchSuppliers() async {
    setState(() => _isLoadingSuppliers = true);
    try {
      final snapshot = await FirebaseFirestore.instance.collection('supplier').orderBy('name').get();
      if (mounted) {
        setState(() {
          _suppliers = snapshot.docs;
          _isLoadingSuppliers = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadingSuppliers = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error loading suppliers: $e")));
      }
    }
  }

  // NEW: SAVE BILL TO FIREBASE
  Future<void> _saveBillToFirebase(String supplierName, String supplierPhone) async {
    try {
      await FirebaseFirestore.instance.collection('supplier_bills').add({
        'supplier_name': supplierName,
        'supplier_phone': supplierPhone,
        'products': _cartItems,
        'payment_method': _paymentMethod,
        'created_at': FieldValue.serverTimestamp(),
        'total_items': _cartItems.length,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error saving to database: $e")));
      }
    }
  }

  void _addItem() {
    String name = _productController.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _cartItems.add({
        'name': name,
        'quantity': 1,
      });
      _productController.clear();
    });
  }

  void _editItem(int index) {
    final item = _cartItems[index];
    TextEditingController nameEditController = TextEditingController(text: item['name']);
    TextEditingController qtyEditController = TextEditingController(text: item['quantity'].toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Product"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameEditController,
              decoration: const InputDecoration(labelText: "Product Name"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: qtyEditController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Quantity"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameEditController.text.isNotEmpty && qtyEditController.text.isNotEmpty) {
                setState(() {
                  _cartItems[index]['name'] = nameEditController.text.trim();
                  _cartItems[index]['quantity'] = int.parse(qtyEditController.text.trim());
                });
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700),
            child: const Text("Update"),
          ),
        ],
      ),
    );
  }

  void _deleteItem(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Product"),
        content: const Text("Are you sure you want to delete this product?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _cartItems.removeAt(index);
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  // ================= PDF GENERATION LOGIC =================

  Future<void> _generateAndSharePdf() async {
    if (_selectedSupplier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a supplier first")),
      );
      return;
    }
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please add products to the bill")),
      );
      return;
    }

    setState(() => _isGeneratingPdf = true);

    // Extract data
    final supplierData = _selectedSupplier!.data() as Map<String, dynamic>;
    final supplierName = supplierData['name'] ?? "Unknown";
    final supplierPhone = supplierData['phone'] ?? "N/A";

    // 1. Save to Firebase
    await _saveBillToFirebase(supplierName, supplierPhone);

    try {
      final pdf = pw.Document();

      // Load Logo Image (Failsafe)
      pw.ImageProvider? logoImage;
      try {
        final logoData = await rootBundle.load('assets/images/sky.png');
        final logoBytes = logoData.buffer.asUint8List();
        logoImage = pw.MemoryImage(logoBytes);
      } catch (e) {
        print("Logo not found, skipping image: $e");
      }

      // Format Date and Time
      final now = DateTime.now();
      final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(now);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // ================= HEADER =================
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Left: Logo
                    if (logoImage != null)
                      pw.ClipOval(
                        child: pw.Image(
                          logoImage!,
                          width: 60,
                          height: 60,
                          fit: pw.BoxFit.cover,
                        ),
                      )
                    else
                      pw.Container(
                        width: 60,
                        height: 60,
                        decoration: pw.BoxDecoration(
                          color: PdfColors.orange100,
                          shape: pw.BoxShape.circle,
                        ),
                        child: pw.Center(
                          child: pw.Text("Logo", style: pw.TextStyle(color: PdfColors.orange800, fontSize: 10)),
                        ),
                      ),

                    // Center: SKYTRONIX
                    pw.Expanded(
                      child: pw.Column(
                        children: [
                          pw.Text(
                            "SKYTRONIX",
                            style: pw.TextStyle(
                              fontSize: 24,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.black,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            "Fida Avenue, Multan",
                            style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
                            textAlign: pw.TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    // Right: Date and Time
                    pw.Container(
                      width: 120,
                      alignment: pw.Alignment.topRight,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            formattedDate,
                            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                pw.SizedBox(height: 30),

                // ================= TABLE 1: SUPPLIER INFO =================
                pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    children: [
                      _buildInfoRow("Supplier Name:", supplierName),
                      pw.Divider(color: PdfColors.grey300),
                      _buildInfoRow("Contact Number:", supplierPhone),
                    ],
                  ),
                ),

                pw.SizedBox(height: 30),

                // ================= TABLE 2: PRODUCTS =================
                pw.Text(
                  "Bill Details",
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),

                // MANUAL TABLE CONSTRUCTION
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey400, width: 1),
                  columnWidths: const {
                    0: pw.FlexColumnWidth(1), // S.No
                    1: pw.FlexColumnWidth(4), // Product Name
                    2: pw.FlexColumnWidth(2), // Quantity
                  },
                  children: [
                    // Header Row
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.orange700),
                      children: [
                        pw.Center(
                          child: pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text('S.No', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
                          ),
                        ),
                        pw.Center(
                          child: pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text('Product Name', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
                          ),
                        ),
                        pw.Center(
                          child: pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text('Quantity', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                    // Data Rows
                    ...List.generate(_cartItems.length, (index) {
                      final item = _cartItems[index];
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Center(child: pw.Text('${index + 1}')),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text(item['name']),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Center(child: pw.Text('${item['quantity']}')),
                          ),
                        ],
                      );
                    }),
                  ],
                ),

                pw.Spacer(),

                pw.Divider(),
                pw.SizedBox(height: 10),

                // Footer Info
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Payment Method: $_paymentMethod", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text("Generated by App", style: pw.TextStyle(color: PdfColors.grey)),
                  ],
                ),
              ],
            );
          },
        ),
      );

      // Convert to bytes and share
      final bytes = await pdf.save();
      final directory = await Directory.systemTemp.createTemp();
      final file = File('${directory.path}/supplier_bill_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles([XFile(file.path)], text: 'Bill for Supplier $supplierName');

      setState(() => _isGeneratingPdf = false);

    } catch (e) {
      setState(() => _isGeneratingPdf = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error generating PDF: $e")));
      }
    }
  }

  pw.Widget _buildInfoRow(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: pw.Row(
        children: [
          pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
          pw.SizedBox(width: 10),
          pw.Text(value, style: pw.TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  // ================= UI BUILD =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFFF7E00),
        foregroundColor: Colors.white,
        title: const Text("Supplier Billing", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      // FIXED: Wrapped body in SingleChildScrollView to prevent overflow
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Important for ScrollView
            children: [
              // 1. Supplier Selection
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Select Supplier", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    _isLoadingSuppliers
                        ? const Center(child: Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator()))
                        : DropdownButtonFormField<QueryDocumentSnapshot>(
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                      hint: const Text("Choose Supplier..."),
                      value: _selectedSupplier,
                      items: _suppliers.map((doc) {
                        return DropdownMenuItem(
                          value: doc,
                          child: Text(doc['name']),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedSupplier = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // 2. Add Product
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _productController,
                        decoration: InputDecoration(
                          labelText: "Product Name",
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _addItem,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: const CircleBorder(), padding: const EdgeInsets.all(12)),
                      child: const Icon(Icons.add, color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // 3. Product List
              // FIXED: Removed Expanded, used fixed height Container
              Container(
                height: 300, // Fixed height to prevent overflow when keyboard opens
                color: const Color(0xFFF5F6FA), // Matches background
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _cartItems.isEmpty
                    ? const Center(child: Text("No products added yet."))
                    : ListView.builder(
                  itemCount: _cartItems.length,
                  itemBuilder: (context, index) {
                    final item = _cartItems[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: Text(
                          "${index + 1}",
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        title: Text(
                          item['name'],
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text("Quantity"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Qty Controls
                            Container(
                              decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                              child: Row(
                                children: [
                                  IconButton(
                                    iconSize: 20,
                                    icon: const Icon(Icons.remove, color: Colors.orange),
                                    onPressed: () {
                                      setState(() {
                                        int newQty = item['quantity'] - 1;
                                        if (newQty > 0) item['quantity'] = newQty;
                                      });
                                    },
                                  ),
                                  Text(
                                    "${item['quantity']}",
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  IconButton(
                                    iconSize: 20,
                                    icon: const Icon(Icons.add, color: Colors.orange),
                                    onPressed: () {
                                      setState(() {
                                        item['quantity']++;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Edit Icon
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _editItem(index),
                            ),
                            // Delete Icon
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteItem(index),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // 4. Payment Method Selection (UPDATED TO DROPDOWN)
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Payment Method", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _paymentMethod,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                        DropdownMenuItem(value: 'EasyPaisa', child: Text('EasyPaisa')),
                        DropdownMenuItem(value: 'JazzCash', child: Text('JazzCash')),
                        DropdownMenuItem(value: 'Card', child: Text('Card')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _paymentMethod = value!;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // 5. Share Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isGeneratingPdf ? null : _generateAndSharePdf,
                    icon: _isGeneratingPdf
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.share),
                    label: Text(_isGeneratingPdf ? "Processing..." : "Share Bill"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}