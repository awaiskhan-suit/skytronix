import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class CustomerFirebaseScreen extends StatefulWidget {
  const CustomerFirebaseScreen({super.key});

  @override
  State<CustomerFirebaseScreen> createState() => _CustomerFirebaseScreenState();
}

class _CustomerFirebaseScreenState extends State<CustomerFirebaseScreen> {
  TextEditingController searchController = TextEditingController();
  String searchText = "";
  final Color primaryColor = const Color(0xFFFF7E00);

  // 📡 FIREBASE STREAM
  Stream<QuerySnapshot> getCustomers() {
    return FirebaseFirestore.instance.collection('customers').orderBy('name').snapshots();
  }

  // 📲 OPEN WHATSAPP
  Future<void> openWhatsApp(String phone) async {
    String formattedPhone = phone.startsWith('0') ? '92${phone.substring(1)}' : phone;

    final Uri appUrl = Uri.parse("whatsapp://send?phone=$formattedPhone");
    final Uri webUrl = Uri.parse("https://wa.me/$formattedPhone");

    try {
      await launchUrl(appUrl, mode: LaunchMode.externalApplication);
    } catch (e) {
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    }
  }

  // ➕ ADD CUSTOMER
  void showAddDialog() {
    TextEditingController nameController = TextEditingController();
    TextEditingController phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Add Customer"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: "Name",
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: "Phone (11 digits)",
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final phone = phoneController.text.trim();

              if (name.isEmpty || phone.length != 11 || !RegExp(r'^[0-9]+$').hasMatch(phone)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Enter valid name & phone")),
                );
                return;
              }

              await FirebaseFirestore.instance.collection('customers').add({
                "name": name,
                "phone": phone,
                "timestamp": FieldValue.serverTimestamp(),
              });

              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  // ✏️ EDIT CUSTOMER
  void editCustomer(String docId, String oldName, String oldPhone) {
    TextEditingController nameController = TextEditingController(text: oldName);
    TextEditingController phoneController = TextEditingController(text: oldPhone);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Edit Customer"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: "Name",
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: "Phone (11 digits)",
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final phone = phoneController.text.trim();

              if (name.isEmpty || phone.length != 11 || !RegExp(r'^[0-9]+$').hasMatch(phone)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Enter valid name & phone")),
                );
                return;
              }

              await FirebaseFirestore.instance.collection('customers').doc(docId).update({
                "name": name,
                "phone": phone,
              });

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Customer updated")),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
            child: const Text("Update"),
          ),
        ],
      ),
    );
  }

  // 🗑️ DELETE CUSTOMER
  void deleteCustomer(String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Delete Customer"),
        content: const Text("Are you sure you want to delete this customer?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('customers').doc(docId).delete();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Customer deleted")),
              );
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  // 🔎 SEARCH LOGIC
  bool matchSearch(String name) {
    return name.toLowerCase().contains(searchText.toLowerCase());
  }

  // 📊 SUMMARY CARD
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
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: const Color(0xFFFF7E00).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.group, color: primaryColor, size: 28),
          ),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Total Customers", style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 4),
              Text("$totalCount Customers", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            ],
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
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        title: const Text("Customers List", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryColor,
        onPressed: showAddDialog,
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
      body: Column(
        children: [
          // 🔎 SEARCH BAR
          Container(
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
            ),
            child: TextField(
              controller: searchController,
              onChanged: (value) {
                setState(() {
                  searchText = value;
                });
              },
              decoration: const InputDecoration(
                hintText: "Search customers...",
                prefixIcon: Icon(Icons.search, color: Colors.grey),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              ),
            ),
          ),

          // 📋 LIST
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: getCustomers(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFFFF7E00)));

                final items = snapshot.data!.docs;
                final filtered = items.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return matchSearch(data['name'] ?? "");
                }).toList();

                return Column(
                  children: [
                    // ✅ SUMMARY CARD
                    _buildSummaryCard(items.length),

                    // ✅ CUSTOMER LIST
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text("No customers found", style: TextStyle(color: Colors.grey)))
                          : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final doc = filtered[index];
                          final data = doc.data() as Map<String, dynamic>;
                          return _buildCustomerCard(doc.id, data);
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

  // 🃏 CUSTOMER CARD DESIGN
  Widget _buildCustomerCard(String docId, Map<String, dynamic> data) {
    String name = data['name'] ?? "Unknown";
    String phone = data['phone'] ?? "";

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.person, color: Color(0xFFFF7E00)),
          ),
          const SizedBox(width: 15),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 4),
                Text(
                  phone,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ),

          // ✅ ICONS IN ROW FORM
          const SizedBox(width: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // WhatsApp (Real Icon)
              _actionIcon(FontAwesomeIcons.whatsapp, Colors.green, () {
                if (phone.isNotEmpty) openWhatsApp(phone);
              }),
              const SizedBox(width: 8),
              // Edit
              _actionIcon(Icons.edit, Colors.blue, () {
                editCustomer(docId, name, phone);
              }),
              const SizedBox(width: 8),
              // Delete
              _actionIcon(Icons.delete, Colors.red, () {
                deleteCustomer(docId);
              }),
            ],
          ),
        ],
      ),
    );
  }

  // ✅ UPDATED ACTION ICON TO HANDLE FAICONS AND ICONS
  Widget _actionIcon(dynamic icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        // Check if icon is FontAwesome or Standard Material Icon
        child: icon is FaIconData
            ? FaIcon(icon, color: color, size: 18)
            : Icon(icon, color: color, size: 18),
      ),
    );
  }
}
