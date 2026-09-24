import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:skytronix/admin/show_invoices.dart';

// ==========================================
// 🧾 DATA MODEL FOR INVOICE ITEMS
// ==========================================
class InvoiceItem {
  final String productId;
  final String productName;
  double price;
  int quantity;
  double get netPrice => price * quantity;

  InvoiceItem({
    required this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
  });
}

// ==========================================
// 📱 BILL SCREEN
// ==========================================
class BillScreen extends StatefulWidget {
  const BillScreen({super.key});

  @override
  State<BillScreen> createState() => _BillScreenState();
}

class _BillScreenState extends State<BillScreen> {
  // Form State
  Map<String, dynamic>? selectedCustomer;
  List<InvoiceItem> invoiceItems = [];
  String paymentMethod = "Cash on Delivery";
  final Color primaryColor = const Color(0xFFFF7E00);

  // Controllers
  final TextEditingController customerSearchController = TextEditingController();
  final TextEditingController productSearchController = TextEditingController();

  // Cache for Stock
  List<QueryDocumentSnapshot> stockCache = [];

  @override
  void initState() {
    super.initState();
    _fetchStockForCache();
  }

  // Fetch all stock once to make selection faster
  Future<void> _fetchStockForCache() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('stock').get();
      if (mounted) {
        setState(() {
          stockCache = snapshot.docs;
        });
      }
    } catch (e) {
      print("Error fetching stock: $e");
    }
  }

  // ➕ ADD PRODUCT TO INVOICE
  void addProductToInvoice(QueryDocumentSnapshot productDoc) {
    final data = productDoc.data() as Map<String, dynamic>;
    final String id = productDoc.id;

    // Safety check for name and price
    final String name = data['productName']?.toString() ?? "Unknown Product";
    final double price = double.tryParse(data['productSalePrice']?.toString() ?? '0.0') ?? 0.0;

    // Check if already exists
    int existingIndex = invoiceItems.indexWhere((item) => item.productId == id);

    if (existingIndex != -1) {
      setState(() {
        invoiceItems[existingIndex].quantity++;
      });
    } else {
      setState(() {
        invoiceItems.add(InvoiceItem(
          productId: id,
          productName: name,
          price: price,
          quantity: 1,
        ));
      });
    }
    Navigator.pop(context); // Close selection dialog
  }

  // 🧮 CALCULATE TOTAL
  double get grandTotal {
    return invoiceItems.fold(0.0, (sum, item) => sum + item.netPrice);
  }

  // 💾 SAVE TO FIRESTORE & DEDUCT STOCK
  Future<void> _saveInvoiceToFirestore(String invoiceNo) async {
    try {
      // 1. Prepare items list for Firestore
      List<Map<String, dynamic>> itemsList = invoiceItems.map((item) {
        return {
          'productId': item.productId, // Saving ID is important for tracking
          'productName': item.productName,
          'price': item.price,
          'quantity': item.quantity,
          'netPrice': item.netPrice,
        };
      }).toList();

      // 2. Save the Invoice Document
      await FirebaseFirestore.instance.collection('invoices').add({
        'invoiceNo': invoiceNo,
        'date': DateTime.now(),
        'customerName': selectedCustomer!['name'],
        'customerPhone': selectedCustomer!['phone'],
        'paymentMethod': paymentMethod,
        'totalAmount': grandTotal,
        'items': itemsList,
      });

      // 3. 🔻 NEW: DEDUCT STOCK FROM INVENTORY
      // We loop through every item in the invoice and reduce the quantity in the 'stock' collection
      for (var item in invoiceItems) {
        await FirebaseFirestore.instance
            .collection('stock')
            .doc(item.productId) // Use the specific ID to target the correct document
            .update({
          'productStockQuantity': FieldValue.increment(-item.quantity)
        });
      }

      // 4. 🔄 REFRESH LOCAL CACHE
      // We refresh the cache so that if the user opens the product dialog again,
      // they see the updated stock numbers immediately.
      _fetchStockForCache();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Invoice saved & Inventory updated"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print("Error saving invoice: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  // 🖨️ PDF GENERATION & SHARE
  Future<void> generateAndSharePdf() async {
    if (selectedCustomer == null || invoiceItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a customer and add products")),
      );
      return;
    }

    // 1. Generate Invoice Number
    final invoiceNo = "INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}";

    // 2. Save to Firebase First (This now also deducts stock)
    await _saveInvoiceToFirestore(invoiceNo);

    final pdf = pw.Document();

    // Safe Logo Loading
    pw.ImageProvider? logoImage;
    try {
      final logoData = await rootBundle.load('assets/images/sky.png');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (e) {
      print("Logo not found or error loading logo: $e");
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header Row
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Left: Logo
                  if (logoImage != null)
                    pw.Container(
                        width: 120, height: 120, child: pw.Image(logoImage))
                  else
                    pw.SizedBox(width: 120, height: 120),

                  // Center: Org Name & Address
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      mainAxisAlignment: pw.MainAxisAlignment.start,
                      children: [
                        pw.Text("SKYTRONIX",
                            style: pw.TextStyle(
                                fontSize: 28, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 5),
                        pw.Text("Fida Avenue, Multan",
                            style: const pw.TextStyle(fontSize: 14)),
                      ],
                    ),
                  ),

                  // Right: Date & Invoice #
                  pw.Container(
                    alignment: pw.Alignment.topRight,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text("Date: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}"),
                        pw.SizedBox(height: 5),
                        pw.Text("Invoice No:$invoiceNo"),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Divider(),

              // Customer Info
              pw.SizedBox(height: 10),
              pw.Text("Bill To:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 5),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("Name: ${selectedCustomer!['name'] ?? 'N/A'}"),
                          pw.Text("Phone: ${selectedCustomer!['phone'] ?? 'N/A'}"),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Products Table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400),
                columnWidths: {
                  0: const pw.FixedColumnWidth(30), // S.No
                  1: const pw.FlexColumnWidth(2),   // Name
                  2: const pw.FlexColumnWidth(1),   // Qty
                  3: const pw.FlexColumnWidth(1),   // Price
                  4: const pw.FlexColumnWidth(1),   // Total
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.orange100),
                    children: [
                      _cell("S.No", bold: true),
                      _cell("Product Name", bold: true),
                      _cell("Qty", bold: true),
                      _cell("Price", bold: true),
                      _cell("Net Price", bold: true),
                    ],
                  ),
                  ...List.generate(invoiceItems.length, (index) {
                    final item = invoiceItems[index];
                    return pw.TableRow(
                      children: [
                        _cell("${index + 1}"),
                        _cell(item.productName),
                        _cell("${item.quantity}"),
                        _cell("Rs ${item.price.toStringAsFixed(0)}"),
                        _cell("Rs ${item.netPrice.toStringAsFixed(0)}"),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 20),

              // Total & Payment
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Payment Method: $paymentMethod"),
                  pw.Text(
                    "Total: Rs ${grandTotal.toStringAsFixed(0)}",
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.orange800,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 40),
              pw.Center(
                child: pw.Text("Thank you for your business!",
                    style: pw.TextStyle(fontStyle: pw.FontStyle.italic)),
              ),
            ],
          );
        },
      ),
    );

    // Share PDF
    final output = await getTemporaryDirectory();
    final file = File("${output.path}/invoice_${DateTime.now().millisecondsSinceEpoch}.pdf");
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles([XFile(file.path)], text: 'Invoice from Skytronix');
  }

  pw.Widget _cell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontSize: 12,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        // ✅ ADDED: Show Invoice Icon on the Left
        leading: IconButton(
          icon: const Icon(Icons.receipt_long, color: Colors.white),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const InvoiceListScreen()),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Navigating to Invoice History...")),
            );
          },
          tooltip: 'Invoice History',
        ),
        title: const Text("Create Invoice"),
        centerTitle: true,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSectionTitle("Customer Details"),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => _showCustomerSelectionDialog(),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: primaryColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person, color: Color(0xFFFF7E00)),
                          const SizedBox(width: 15),
                          Expanded(
                            child: selectedCustomer == null
                                ? const Text("Tap to Select Customer",
                                style: TextStyle(color: Colors.grey))
                                : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(selectedCustomer!['name'] ?? "Unknown",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                                Text(selectedCustomer!['phone'] ?? "No Phone",
                                    style: const TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildSectionTitle("Invoice Items"),
                  const SizedBox(height: 10),
                  if (invoiceItems.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                          color: Colors.white, borderRadius: BorderRadius.circular(12)),
                      child: const Center(
                          child: Text("No products added yet",
                              style: TextStyle(color: Colors.grey))),
                    )
                  else
                    Column(
                      children: List.generate(invoiceItems.length, (index) {
                        return _buildInvoiceItemCard(index);
                      }),
                    ),
                  const SizedBox(height: 15),
                  ElevatedButton.icon(
                    onPressed: () => _showProductSelectionDialog(),
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text("Add Product"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: primaryColor,
                      side: BorderSide(color: primaryColor),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildSectionTitle("Payment Method"),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: paymentMethod,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(value: "Cash on Delivery", child: Text("Cash on Delivery")),
                          DropdownMenuItem(value: "Card", child: Text("Card Payment")),
                          DropdownMenuItem(value: "Easypaisa", child: Text("Easypaisa")),
                          DropdownMenuItem(value: "JazzCash", child: Text("JazzCash")),
                        ],
                        onChanged: (val) {
                          setState(() => paymentMethod = val!);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Total Amount:",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text("Rs ${grandTotal.toStringAsFixed(0)}",
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFF7E00))),
                  ],
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: generateAndSharePdf,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text("Save & Share Invoice", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54));
  }

  Widget _buildInvoiceItemCard(int index) {
    final item = invoiceItems[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5)],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(item.productName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
              Text("Rs ${item.netPrice.toStringAsFixed(0)}",
                  style: const TextStyle(
                      color: Color(0xFFFF7E00),
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    IconButton(
                        iconSize: 18,
                        onPressed: () {
                          setState(() {
                            if (item.quantity > 1) {
                              item.quantity--;
                            } else {
                              invoiceItems.removeAt(index);
                            }
                          });
                        },
                        icon: const Icon(Icons.remove)),
                    Text("${item.quantity}",
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    IconButton(
                        iconSize: 18,
                        onPressed: () {
                          setState(() => item.quantity++);
                        },
                        icon: const Icon(Icons.add)),
                  ],
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                onPressed: () => _showEditItemDialog(index),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text("Remove Item?"),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text("Cancel")),
                        TextButton(
                            onPressed: () {
                              setState(() => invoiceItems.removeAt(index));
                              Navigator.pop(ctx);
                            },
                            child: const Text("Delete", style: TextStyle(color: Colors.red)))
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditItemDialog(int index) {
    final item = invoiceItems[index];
    TextEditingController priceCtrl = TextEditingController(text: item.price.toString());
    TextEditingController qtyCtrl = TextEditingController(text: item.quantity.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Item"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Unit Price"),
            ),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Quantity"),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              setState(() {
                item.price = double.tryParse(priceCtrl.text) ?? item.price;
                item.quantity = int.tryParse(qtyCtrl.text) ?? item.quantity;
              });
              Navigator.pop(context);
            },
            child: const Text("Update"),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 🔍 MODERN CUSTOMER SELECTION DIALOG
  // ==========================================
  void _showCustomerSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) {
        String searchQuery = "";
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text("Select Customer", style: TextStyle(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        onChanged: (val) => setDialogState(() => searchQuery = val),
                        decoration: const InputDecoration(
                          hintText: "Search name...",
                          border: InputBorder.none,
                          prefixIcon: Icon(Icons.search, color: Colors.grey),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    SizedBox(
                      height: 220,
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('customers').orderBy('name').snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                          final customers = snapshot.data!.docs;
                          final filtered = customers.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final name = (data['name'] ?? "").toLowerCase();
                            return name.contains(searchQuery.toLowerCase());
                          }).toList();
                          if (filtered.isEmpty) return const Center(child: Text("No customers found", style: TextStyle(color: Colors.grey)));
                          return ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final data = filtered[index].data() as Map<String, dynamic>;
                              return _buildCustomerCard(data);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCustomerCard(Map<String, dynamic> data) {
    String name = data['name'] ?? "Unknown";
    String phone = data['phone'] ?? "No Phone";
    return InkWell(
      onTap: () {
        setState(() => selectedCustomer = data);
        Navigator.pop(context);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4)],
        ),
        child: Row(
          children: [
            Container(
              width: 45, height: 45,
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.person, color: Color(0xFFFF7E00)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(phone, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 🔍 MODERN PRODUCT SELECTION DIALOG
  // ==========================================
  void _showProductSelectionDialog() {
    if (stockCache.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No products found in stock.")),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (context) {
        String searchQuery = "";
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text("Add Product", style: TextStyle(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        onChanged: (val) => setDialogState(() => searchQuery = val),
                        decoration: const InputDecoration(
                          hintText: "Search product...",
                          border: InputBorder.none,
                          prefixIcon: Icon(Icons.search, color: Colors.grey),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    SizedBox(
                      height: 220,
                      child: ListView.builder(
                        itemCount: stockCache.length,
                        itemBuilder: (context, index) {
                          final doc = stockCache[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final String pName = data['productName']?.toString() ?? "Unnamed Product";
                          final String pStock = data['productStockQuantity']?.toString() ?? '0';
                          final String pPrice = data['productSalePrice']?.toString() ?? '0';
                          if (searchQuery.isNotEmpty && !pName.toLowerCase().contains(searchQuery.toLowerCase())) {
                            return const SizedBox.shrink();
                          }
                          return _buildProductCard(doc, data, pName, pStock, pPrice);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProductCard(QueryDocumentSnapshot doc, Map<String, dynamic> data, String name, String stock, String price) {
    return InkWell(
      onTap: () => addProductToInvoice(doc),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4)],
        ),
        child: Row(
          children: [
            Container(
              width: 45, height: 45,
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.inventory_2, color: Color(0xFFFF7E00)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text("Stock: $stock", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(width: 10),
                      Text("Rs $price", style: const TextStyle(color: Color(0xFFFF7E00), fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.add_circle_outline, size: 24, color: Color(0xFFFF7E00)),
          ],
        ),
      ),
    );
  }
}