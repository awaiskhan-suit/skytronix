import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:skytronix/admin/pdf_slip.dart';

// Helper class for Material Rows
class MaterialEntry {
  String? id;
  TextEditingController materialNameController = TextEditingController();
  TextEditingController materialQtyController = TextEditingController();

  MaterialEntry({this.id});
}

// ==========================================
// 🆕 FULL SCREEN ADD PAGE
// ==========================================
class AddStockItemPage extends StatefulWidget {
  const AddStockItemPage({super.key});

  @override
  State<AddStockItemPage> createState() => _AddStockItemPageState();
}

class _AddStockItemPageState extends State<AddStockItemPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController productNameController = TextEditingController();
  final TextEditingController productCategoryController = TextEditingController();
  final TextEditingController productUnitController = TextEditingController();
  final TextEditingController productSalePriceController = TextEditingController();
  final TextEditingController productPurchasePriceController = TextEditingController();
  final TextEditingController productStockController = TextEditingController();

  bool isLoading = false;
  List<MaterialEntry> materialEntries = [];

  void _addMaterialEntry() {
    setState(() {
      materialEntries.add(
        MaterialEntry(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
        ),
      );
    });
  }

  void _removeMaterialEntry(int index) {
    setState(() {
      materialEntries[index].materialNameController.dispose();
      materialEntries[index].materialQtyController.dispose();
      materialEntries.removeAt(index);
    });
  }

  Future<void> saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    List<Map<String, dynamic>> validatedMaterials = [];
    bool hasError = false;

    for (var entry in materialEntries) {
      String name = entry.materialNameController.text.trim();
      String qtyStr = entry.materialQtyController.text.trim();

      if (name.isEmpty || qtyStr.isEmpty || int.tryParse(qtyStr) == null) {
        hasError = true;
        break;
      }

      validatedMaterials.add({
        'name': name,
        'qty': int.tryParse(qtyStr) ?? 0,
      });
    }

    if (hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill all Material names and quantities correctly"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    // Get the main product stock quantity
    final int mainStockQuantity = int.tryParse(productStockController.text.trim()) ?? 0;

    try {
      // 1. Save the Main Product
      DocumentReference productRef = await FirebaseFirestore.instance.collection('stock').add({
        'productName': productNameController.text.trim(),
        'productCategory': productCategoryController.text.trim(),
        'productUnit': productUnitController.text.trim(),
        'productSalePrice': double.tryParse(productSalePriceController.text.trim()) ?? 0,
        'productPurchasePrice': double.tryParse(productPurchasePriceController.text.trim()) ?? 0,
        'productStockQuantity': mainStockQuantity,
        'rawMaterials': validatedMaterials,
        'createdAt': Timestamp.now(),
      });

      // ✅ NEW LOGIC: AUTOMATICALLY REDUCE RAW MATERIAL STOCK
      if (mainStockQuantity > 0) {
        for (var material in validatedMaterials) {
          String matName = material['name'];
          int matQtyPerUnit = material['qty']; // Qty needed for 1 unit of main product

          // Calculate total needed: (Main Stock) * (Material per unit)
          int totalDeduction = mainStockQuantity * matQtyPerUnit;

          // Find the raw material document in the 'stock' collection
          QuerySnapshot querySnapshot = await FirebaseFirestore.instance
              .collection('stock')
              .where('productName', isEqualTo: matName)
              .limit(1)
              .get();

          if (querySnapshot.docs.isNotEmpty) {
            DocumentSnapshot matDoc = querySnapshot.docs.first;
            await matDoc.reference.update({
              'productStockQuantity': FieldValue.increment(-totalDeduction)
            });
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Product Added Successfully & Stock Updated"),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }

    setState(() => isLoading = false);
  }

  @override
  void dispose() {
    productNameController.dispose();
    productCategoryController.dispose();
    productUnitController.dispose();
    productSalePriceController.dispose();
    productPurchasePriceController.dispose();
    productStockController.dispose();
    for (var entry in materialEntries) {
      entry.materialNameController.dispose();
      entry.materialQtyController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFFFF7E00);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Add New Product", style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Icon(Icons.inventory_2, size: 40, color: primaryColor),
                      ),
                      const SizedBox(height: 20),

                      _field(productNameController, "Product Name"),
                      const SizedBox(height: 15),

                      _field(productCategoryController, "Product Category"),
                      const SizedBox(height: 15),

                      _field(productUnitController, "Product Unit (e.g. kg, pcs)"),
                      const SizedBox(height: 15),

                      Row(
                        children: [
                          Expanded(child: _field(productSalePriceController, "Sale Price", keyboard: TextInputType.number)),
                          const SizedBox(width: 15),
                          Expanded(child: _field(productPurchasePriceController, "Purchase Price", keyboard: TextInputType.number)),
                        ],
                      ),
                      const SizedBox(height: 15),

                      _field(productStockController, "Stock Quantity", keyboard: TextInputType.number),

                      const SizedBox(height: 25),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Raw Materials", style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor)),
                          TextButton.icon(
                            onPressed: _addMaterialEntry,
                            icon: const Icon(Icons.add, color: Colors.green),
                            label: const Text("Add Material", style: TextStyle(color: Colors.green)),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      if (materialEntries.isEmpty)
                        const Text("No materials added yet", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))
                      else
                        Column(
                          children: List.generate(materialEntries.length, (i) => _materialRow(i, _removeMaterialEntry)),
                        ),

                      const SizedBox(height: 30),

                      ElevatedButton(
                        onPressed: isLoading ? null : saveProduct,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        child: isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text("Save Product"),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, {TextInputType? keyboard}) {
    return TextFormField(
      controller: c,
      keyboardType: keyboard,
      validator: (v) => v == null || v.isEmpty ? "Required" : null,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _materialRow(int i, Function(int) onRemove) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: materialEntries[i].materialNameController,
              decoration: const InputDecoration(labelText: "Material Name", contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 14)),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 70,
            child: TextFormField(
              controller: materialEntries[i].materialQtyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Qty", contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 14)),
            ),
          ),
          IconButton(
            onPressed: () => onRemove(i),
            icon: const Icon(Icons.delete, color: Colors.red),
          )
        ],
      ),
    );
  }
}

// ==========================================
// 🔽 MAIN STOCK SCREEN
// ==========================================
class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  final TextEditingController searchController = TextEditingController();
  String searchText = "";
  final Color primaryColor = const Color(0xFFFF7E00);

  Stream<QuerySnapshot> getProducts() {
    return FirebaseFirestore.instance.collection('stock').orderBy('productName').snapshots();
  }

  Widget stockStatus(int stock) {
    if (stock == 0) {
      return _badge("OUT OF STOCK", Colors.red.shade100, Colors.red);
    } else if (stock <= 5) {
      return _badge("LOW STOCK", Colors.orange.shade100, Colors.orange);
    } else {
      return _badge("IN STOCK", Colors.green.shade100, Colors.green);
    }
  }

  Widget _badge(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  // 🗑️ DELETE LOGIC
  Future<void> deleteProduct(String docId) async {
    await FirebaseFirestore.instance.collection('stock').doc(docId).delete();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Product Deleted"),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void showDeleteDialog(String docId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Delete Product"),
        content: const Text("Are you sure you want to delete this product?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              deleteProduct(docId);
              Navigator.pop(context);
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  bool matchSearch(String name) {
    return name.toLowerCase().contains(searchText.toLowerCase());
  }

  // 📄 PDF ACTION
  void _onPdfPressed() {
    // Placeholder for PDF generation logic
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Generating PDF Report..."),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // 📊 SUMMARY CARD WIDGET
  Widget _buildSummaryCard(int totalCount) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF7E00), Color(0xFFFF5500)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF7E00).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.inventory_2, color: primaryColor, size: 28),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Total Products",
                  style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  "$totalCount Items",
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        elevation: 0,
        // ✅ PDF ICON ADDED HERE
        leading: IconButton(
          icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
          onPressed: (){
            Navigator.push(context, MaterialPageRoute(builder: (context)=>StockReportPage()));
          },
          tooltip: 'Generate PDF',
        ),
        title: const Text("Inventory Stock", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddStockItemPage()),
          );
        },
        backgroundColor: const Color(0xFFFF7E00),
        elevation: 4,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          // 🔎 SEARCH BAR
          Container(
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))
              ],
            ),
            child: TextField(
              controller: searchController,
              onChanged: (val) => setState(() => searchText = val),
              decoration: const InputDecoration(
                hintText: "Search products...",
                prefixIcon: Icon(Icons.search, color: Colors.grey),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              ),
            ),
          ),

          // 📋 LIST WITH STREAMBUILDER
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: getProducts(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFFFF7E00)));

                final items = snapshot.data!.docs;
                final filtered = items.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return matchSearch(data['productName']);
                }).toList();

                return Column(
                  children: [
                    // ✅ SUMMARY CARD
                    _buildSummaryCard(items.length), // Shows total items in DB

                    // ✅ LIST
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text("No products found", style: TextStyle(color: Colors.grey)))
                          : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          final doc = filtered[i];
                          final data = doc.data() as Map<String, dynamic>;
                          return _buildModernCard(doc.id, data);
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          )
        ],
      ),
    );
  }

  Widget _buildModernCard(String docId, Map<String, dynamic> data) {
    List<dynamic> rawMaterials = data['rawMaterials'] ?? [];
    int stock = int.tryParse(data['productStockQuantity'].toString()) ?? 0;
    String unit = data['productUnit'] ?? '';

    bool hasMaterials = rawMaterials.isNotEmpty;

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
          // Left: Icon
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              hasMaterials ? Icons.category_outlined : Icons.inventory_2_outlined,
              color: primaryColor,
            ),
          ),
          const SizedBox(width: 15),

          // Middle: Details (Expanded)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category Badge
                Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Text(
                    data['productCategory'] ?? "General",
                    style: TextStyle(
                      color: Colors.blue.shade900,
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
                  ),
                ),

                // Name
                Text(
                  data['productName'] ?? "Unknown",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                ),

                const SizedBox(height: 4),

                // Raw Materials
                if (hasMaterials)
                  Padding(
                    padding: const EdgeInsets.only(top: 5.0),
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: rawMaterials.map((item) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "${item['name']} (${item['qty']})",
                            style: const TextStyle(fontSize: 10, color: Colors.black54),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),

          // Right: Price, Actions, Stock Status
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "Rs ${data['productSalePrice'] ?? 0}",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFFF7E00)),
              ),
              Text(
                "Pur: Rs ${data['productPurchasePrice'] ?? 0}",
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _actionIcon(Icons.edit, Colors.blue, () {
                    showDialog(
                      context: context,
                      builder: (_) => EditProductDialog(docId: docId, data: data),
                    );
                  }),
                  const SizedBox(width: 8),
                  _actionIcon(Icons.delete, Colors.red, () => showDeleteDialog(docId)),
                ],
              ),

              // ✅ STOCK STATUS BELOW EVERYTHING (In Right Column)
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "Stock Quantity: $stock",
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    "Product Unit: $unit",
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  stockStatus(stock),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionIcon(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}

// ==========================================
// ✏️ EDIT DIALOG WITH RAW MATERIALS SUPPORT
// ==========================================
class EditProductDialog extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;

  const EditProductDialog({super.key, required this.docId, required this.data});

  @override
  State<EditProductDialog> createState() => _EditProductDialogState();
}

class _EditProductDialogState extends State<EditProductDialog> {
  late TextEditingController nameController;
  late TextEditingController categoryController;
  late TextEditingController unitController;
  late TextEditingController salePriceController;
  late TextEditingController purchasePriceController;
  late TextEditingController stockController;

  bool isLoading = false;
  List<MaterialEntry> materialEntries = [];

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.data['productName']);
    categoryController = TextEditingController(text: widget.data['productCategory']);
    unitController = TextEditingController(text: widget.data['productUnit']);
    salePriceController = TextEditingController(text: widget.data['productSalePrice'].toString());
    purchasePriceController = TextEditingController(text: widget.data['productPurchasePrice'].toString());
    stockController = TextEditingController(text: widget.data['productStockQuantity'].toString());

    // Load existing materials
    List<dynamic> raw = widget.data['rawMaterials'] ?? [];
    for (var mat in raw) {
      materialEntries.add(
        MaterialEntry(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
        )..materialNameController.text = mat['name'] ?? ''
          ..materialQtyController.text = mat['qty']?.toString() ?? '0',
      );
    }
  }

  void _addMaterialEntry() {
    setState(() {
      materialEntries.add(MaterialEntry(id: DateTime.now().millisecondsSinceEpoch.toString()));
    });
  }

  void _removeMaterialEntry(int index) {
    setState(() {
      materialEntries[index].materialNameController.dispose();
      materialEntries[index].materialQtyController.dispose();
      materialEntries.removeAt(index);
    });
  }

  Future<void> updateProduct() async {
    // Validation
    if (nameController.text.isEmpty) return;

    List<Map<String, dynamic>> validatedMaterials = [];
    for (var entry in materialEntries) {
      String name = entry.materialNameController.text.trim();
      String qtyStr = entry.materialQtyController.text.trim();
      if (name.isNotEmpty && qtyStr.isNotEmpty) {
        validatedMaterials.add({
          'name': name,
          'qty': int.tryParse(qtyStr) ?? 0,
        });
      }
    }

    setState(() => isLoading = true);

    // Get old vs new stock for material adjustment
    final oldMainStock = int.tryParse(widget.data['productStockQuantity'].toString()) ?? 0;
    final newMainStock = int.tryParse(stockController.text) ?? 0;

    try {
      await FirebaseFirestore.instance.collection('stock').doc(widget.docId).update({
        "productName": nameController.text.trim(),
        "productCategory": categoryController.text.trim(),
        "productUnit": unitController.text.trim(),
        "productSalePrice": double.tryParse(salePriceController.text) ?? 0,
        "productPurchasePrice": double.tryParse(purchasePriceController.text) ?? 0,
        "productStockQuantity": newMainStock,
        "rawMaterials": validatedMaterials,
      });

      // ✅ NEW LOGIC: ADJUST RAW MATERIALS BASED ON CHANGE
      if (oldMainStock != newMainStock) {
        // Loop through validated materials (new list)
        for (var item in validatedMaterials) {
          String matName = item['name'];
          int matQtyPerUnit = item['qty'];

          // Find material in DB
          QuerySnapshot querySnapshot = await FirebaseFirestore.instance
              .collection('stock')
              .where('productName', isEqualTo: matName)
              .limit(1)
              .get();

          if (querySnapshot.docs.isNotEmpty) {
            DocumentSnapshot matDoc = querySnapshot.docs.first;

            // Logic: We are updating the main product stock.
            // We should adjust raw material stock based on the DIFFERENCE.
            // If we increase stock, deduct more material. If we decrease, add back material.
            int difference = newMainStock - oldMainStock;
            int totalDeduction = difference * matQtyPerUnit;

            if (totalDeduction != 0) {
              await matDoc.reference.update({
                'productStockQuantity': FieldValue.increment(-totalDeduction)
              });
            }
          }
        }
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
    setState(() => isLoading = false);
  }

  @override
  void dispose() {
    nameController.dispose();
    categoryController.dispose();
    unitController.dispose();
    salePriceController.dispose();
    purchasePriceController.dispose();
    stockController.dispose();
    for (var entry in materialEntries) {
      entry.materialNameController.dispose();
      entry.materialQtyController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text("Edit Product", style: TextStyle(fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: "Product Name")),
              TextField(controller: categoryController, decoration: const InputDecoration(labelText: "Product Category")),
              TextField(controller: unitController, decoration: const InputDecoration(labelText: "Product Unit")),
              TextField(controller: salePriceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Sale Price")),
              TextField(controller: purchasePriceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Purchase Price")),
              TextField(controller: stockController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Stock Quantity")),

              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 10),

              // Raw Materials Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Raw Materials", style: TextStyle(fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    onPressed: _addMaterialEntry,
                    icon: const Icon(Icons.add, color: Colors.green, size: 18),
                    label: const Text("Add", style: TextStyle(color: Colors.green)),
                  ),
                ],
              ),
              const SizedBox(height: 5),

              if (materialEntries.isEmpty)
                const Text("No materials", style: TextStyle(color: Colors.grey, fontSize: 12))
              else
                Column(
                  children: List.generate(materialEntries.length, (i) => _materialRow(i, _removeMaterialEntry)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(
          onPressed: isLoading ? null : updateProduct,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF7E00)),
          child: isLoading ? const SizedBox(width: 20,height: 20,child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text("Update"),
        )
      ],
    );
  }

  Widget _materialRow(int i, Function(int) onRemove) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: materialEntries[i].materialNameController,
              decoration: const InputDecoration(labelText: "Name", isDense: true),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: TextField(
              controller: materialEntries[i].materialQtyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Qty", isDense: true),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => onRemove(i),
            icon: const Icon(Icons.delete, color: Colors.red, size: 20),
          )
        ],
      ),
    );
  }
}
