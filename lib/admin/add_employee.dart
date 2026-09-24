import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: EmployeeModule(),
  ));
}

// ================= MAIN LIST PAGE =================
class EmployeeModule extends StatefulWidget {
  const EmployeeModule({super.key});

  @override
  State<EmployeeModule> createState() => _EmployeeModuleState();
}

class _EmployeeModuleState extends State<EmployeeModule> {
  final TextEditingController _searchController = TextEditingController();
  String searchText = "";

  Future<void> deleteEmployee(String id) async {
    try {
      await FirebaseFirestore.instance.collection('employees').doc(id).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Employee deleted successfully"),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  void confirmDelete(String id, String name) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Delete Employee?", style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text("Are you sure you want to remove $name?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                Navigator.pop(context);
                await deleteEmployee(id);
              },
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );
  }

  // ================= UPDATED WHATSAPP LOGIC =================
  // This function now tries to open the App first, then falls back to Web
  Future<void> launchWhatsApp(String phoneNo) async {
    // Remove any non-numeric characters
    String cleanPhone = phoneNo.replaceAll(RegExp(r'[^\d]'), '');

    // Convert local format (0300...) to international (92300...)
    // (Note: This logic is specific to Pakistan. Adjust '92' if you are elsewhere)
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '92' + cleanPhone.substring(1);
    }

    // Define App URL and Web URL
    final Uri appUrl = Uri.parse("whatsapp://send?phone=$cleanPhone");
    final Uri webUrl = Uri.parse("https://wa.me/$cleanPhone");

    try {
      // Try to launch the app
      if (await canLaunchUrl(appUrl)) {
        await launchUrl(appUrl, mode: LaunchMode.externalApplication);
      } else {
        // If app is not installed, launch web
        if (await canLaunchUrl(webUrl)) {
          await launchUrl(webUrl, mode: LaunchMode.externalApplication);
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Could not launch WhatsApp")),
          );
        }
      }
    } catch (e) {
      // Fallback to web if app launch fails
      if (await canLaunchUrl(webUrl)) {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not launch WhatsApp")),
        );
      }
    }
  }

  String formatDate(dynamic value) {
    if (value == null) return "-";
    if (value is Timestamp) {
      return DateFormat("dd MMM yyyy").format(value.toDate());
    }
    return value.toString();
  }

  // ================= UI COMPONENTS =================

  // 1. The Orange Dashboard Card (Shows Total Count)
  Widget _buildTotalCountCard(int count) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepOrange.shade400, Colors.orange.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.groups_rounded,
              size: 32,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Total Employees",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "$count",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 2. Helper for grid items in the card
  Widget _buildDetailItem({required IconData icon, required String label, required String value}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 4.0),
        child: Row(
          children: [
            Icon(icon, size: 14, color: Colors.grey.shade500),
            const SizedBox(width: 6),
            Flexible(
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: "$label: ",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    TextSpan(
                      text: value,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 3. The Employee Card (Showing ALL Details)
  Widget employeeCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final name = (data['name'] ?? "Unknown").toString();
    final contact = (data['contact_no'] ?? "").toString();
    final designation = (data['designation'] ?? "Staff").toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 24, left: 20, right: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Container(
                  height: 55,
                  width: 55,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade600, Colors.blue.shade400],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : "?",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        designation,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Action Buttons
                Row(
                  children: [
                    _buildCircleBtn(
                      icon: Icons.edit_outlined,
                      color: Colors.blue.shade50,
                      iconColor: Colors.blue.shade700,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EmployeeFormPage(employeeId: doc.id),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildCircleBtn(
                      icon: Icons.chat_bubble_outline,
                      color: Colors.green.shade50,
                      iconColor: Colors.green.shade700,
                      onTap: () => launchWhatsApp(contact),
                    ),
                    const SizedBox(width: 8),
                    _buildCircleBtn(
                      icon: Icons.delete_outline,
                      color: Colors.red.shade50,
                      iconColor: Colors.red.shade700,
                      onTap: () => confirmDelete(doc.id, name),
                    ),
                  ],
                )
              ],
            ),

            const Divider(height: 30, thickness: 1),

            // FULL DETAILS GRID
            const Text(
              "Personal Information",
              style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                _buildDetailItem(icon: Icons.phone_outlined, label: "Phone", value: data['contact_no'] ?? "-"),
                _buildDetailItem(icon: Icons.email_outlined, label: "Email", value: data['email'] ?? "-"),
              ],
            ),
            Row(
              children: [
                _buildDetailItem(icon: Icons.badge_outlined, label: "CNIC", value: data['cnic'] ?? "-"),
                _buildDetailItem(icon: Icons.location_city_outlined, label: "City", value: data['city'] ?? "-"),
              ],
            ),

            const SizedBox(height: 16),
            const Text(
              "Job Details",
              style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                _buildDetailItem(icon: Icons.admin_panel_settings_outlined, label: "Role", value: data['role'] ?? "-"),
                _buildDetailItem(icon: Icons.business_outlined, label: "Department", value: data['department'] ?? "-"),
              ],
            ),
            Row(
              children: [
                _buildDetailItem(icon: Icons.work_outline, label: "Designation", value: data['designation'] ?? "-"),
                _buildDetailItem(icon: Icons.calendar_today_outlined, label: "Hire Date", value: formatDate(data['hire_date'])),
              ],
            ),

            const SizedBox(height: 16),
            const Text(
              "Financial Information",
              style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                _buildDetailItem(icon: Icons.attach_money_outlined, label: "Salary", value: "${data['salary'] ?? '0'}"),
                _buildDetailItem(icon: Icons.credit_card_outlined, label: "Account No", value: data['account_no'] ?? "-"),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 4.0),
              child: Row(
                children: [
                  Icon(Icons.account_balance_outlined, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text(
                    "Bank: ${data['bank_name'] ?? '-'}",
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleBtn({
    required IconData icon,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: iconColor, size: 20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      // UPDATED APP BAR: ORANGE BACKGROUND, WHITE FOREGROUND
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
        title: const Text(
          "Employee Directory",
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 22),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('employees').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final allDocs = snapshot.data!.docs;
          final totalCount = allDocs.length;

          // Filter logic
          final filteredDocs = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = (data['name'] ?? "").toString().toLowerCase();
            final email = (data['email'] ?? "").toString().toLowerCase();
            final dept = (data['department'] ?? "").toString().toLowerCase();
            return name.contains(searchText) || email.contains(searchText) || dept.contains(searchText);
          }).toList();

          return Column(
            children: [
              // 1. Orange Dashboard Card
              _buildTotalCountCard(totalCount),

              // 2. Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        searchText = value.toLowerCase();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: "Search employees...",
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                  ),
                ),
              ),

              // 3. List View
              Expanded(
                child: filteredDocs.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 60, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text("No matching employees found", style: TextStyle(color: Colors.grey.shade500)),
                    ],
                  ),
                )
                    : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80), // Padding for FAB
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) => employeeCard(filteredDocs[index]),
                ),
              ),
            ],
          );
        },
      ),

      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 20, right: 10),
        child: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EmployeeFormPage()),
            );
          },
          backgroundColor: Colors.blue.shade700,
          elevation: 8,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text("Add New", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
      ),
    );
  }
}

// ================= MODERN FORM PAGE =================
class EmployeeFormPage extends StatefulWidget {
  final String? employeeId;
  const EmployeeFormPage({super.key, this.employeeId});

  @override
  State<EmployeeFormPage> createState() => _EmployeeFormPageState();
}

class _EmployeeFormPageState extends State<EmployeeFormPage> {
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;

  // Controllers
  final accountNoController = TextEditingController();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final contactController = TextEditingController();
  final cityController = TextEditingController();
  final bankNameController = TextEditingController();
  final hireDateController = TextEditingController();
  final cnicController = TextEditingController();
  final salaryController = TextEditingController();

  DateTime? selectedHireDate;

  // Dropdowns
  List<String> roles = ['Admin', 'Employee', 'Manager', 'Officer'];
  List<String> departments = [
    'HR', 'IT', 'Finance', 'Marketing', 'Operations',
    'Sales', 'Customer Support', 'R&D', 'Procurement', 'Legal'
  ];
  List<String> designations = [
    'Software Engineer', 'Accountant', 'HR Executive',
    'Sales Executive', 'Marketing Manager', 'Receptionist',
    'Clerk', 'Technician', 'Analyst', 'Consultant',
    'Project Lead', 'Intern', 'Supervisor', 'Coordinator'
  ];

  String? selectedRole;
  String? selectedDepartment;
  String? selectedDesignation;

  @override
  void initState() {
    super.initState();
    if (widget.employeeId != null) {
      _fetchEmployeeData();
    }
  }

  Future<void> _fetchEmployeeData() async {
    setState(() => isLoading = true);
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('employees')
          .doc(widget.employeeId)
          .get();

      if (doc.exists) {
        var data = doc.data() as Map<String, dynamic>;
        setState(() {
          accountNoController.text = data['account_no']?.toString() ?? '';
          nameController.text = data['name']?.toString() ?? '';
          emailController.text = data['email']?.toString() ?? '';
          contactController.text = data['contact_no']?.toString() ?? '';
          cityController.text = data['city']?.toString() ?? '';
          bankNameController.text = data['bank_name']?.toString() ?? '';
          cnicController.text = data['cnic']?.toString() ?? '';
          salaryController.text = data['salary']?.toString() ?? '';

          selectedRole = data['role'];
          selectedDepartment = data['department'];
          selectedDesignation = data['designation'];

          if (data['hire_date'] != null) {
            selectedHireDate = (data['hire_date'] as Timestamp).toDate();
            hireDateController.text = DateFormat("dd-MM-yyyy").format(selectedHireDate!);
          }
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      initialDate: selectedHireDate ?? DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: Colors.orange.shade700), // Updated DatePicker Color to match
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        selectedHireDate = picked;
        hireDateController.text = DateFormat("dd-MM-yyyy").format(picked);
      });
    }
  }

  Future<void> saveEmployee() async {
    if (!_formKey.currentState!.validate()) return;

    if (selectedRole == null || selectedDepartment == null || selectedDesignation == null || selectedHireDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
      return;
    }

    setState(() => isLoading = true);

    try {
      Map<String, dynamic> data = {
        'account_no': accountNoController.text.trim(),
        'name': nameController.text.trim(),
        'email': emailController.text.trim(),
        'contact_no': contactController.text.trim(),
        'city': cityController.text.trim(),
        'bank_name': bankNameController.text.trim(),
        'hire_date': Timestamp.fromDate(selectedHireDate!),
        'cnic': cnicController.text.trim(),
        'salary': double.tryParse(salaryController.text.trim()) ?? 0,
        'role': selectedRole,
        'department': selectedDepartment,
        'designation': selectedDesignation,
      };

      if (widget.employeeId == null) {
        DocumentReference docRef = FirebaseFirestore.instance.collection("employees").doc();
        data['employee_id'] = docRef.id;
        data['created_at'] = Timestamp.now();
        await docRef.set(data);
      } else {
        await FirebaseFirestore.instance.collection("employees").doc(widget.employeeId).update(data);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.employeeId == null ? "Employee Added Successfully" : "Employee Updated"),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  void dispose() {
    accountNoController.dispose();
    nameController.dispose();
    emailController.dispose();
    contactController.dispose();
    cityController.dispose();
    bankNameController.dispose();
    hireDateController.dispose();
    cnicController.dispose();
    salaryController.dispose();
    super.dispose();
  }

  Widget _buildSectionHeader(String title, {required IconData icon}) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 16.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.orange.shade50, // Updated header icon background to light orange
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: Colors.orange.shade700), // Updated icon color
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool isReadOnly = false,
    VoidCallback? onTap,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        readOnly: isReadOnly,
        onTap: onTap,
        validator: validator ?? (v) => v!.isEmpty ? "Required" : null,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.grey.shade600, size: 22),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.orange.shade700, width: 2), // Updated focus color
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.red.shade400, width: 1),
          ),
          labelStyle: TextStyle(color: Colors.grey.shade600),
        ),
      ),
    );
  }

  Widget _buildModernDropdown({
    required String label,
    required List<String> items,
    required String? value,
    required Function(String?) onChanged,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: DropdownButtonFormField<String>(
        value: value,
        icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: onChanged,
        validator: (v) => v == null ? "Required" : null,
        style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.grey.shade600, size: 22),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.orange.shade700, width: 2), // Updated focus color
          ),
          labelStyle: TextStyle(color: Colors.grey.shade600),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      // UPDATED APP BAR: ORANGE BACKGROUND, WHITE FOREGROUND
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
        leading: IconButton(
          // Color handled by foregroundColor, but explicit if needed
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.employeeId == null ? "Add Employee" : "Edit Employee",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader("Personal Information", icon: Icons.person_outline_rounded),
              _buildModernField(controller: nameController, label: "Full Name", icon: Icons.badge_outlined),
              _buildModernField(
                  controller: cnicController, label: "CNIC (13 digits)", icon: Icons.credit_card_outlined, keyboardType: TextInputType.number,
                  validator: (v) => v != null && v.length == 13 ? null : "Invalid CNIC"),
              _buildModernField(
                  controller: contactController, label: "Phone Number", icon: Icons.phone_android_outlined, keyboardType: TextInputType.number,
                  validator: (v) => v != null && v.length == 11 ? null : "Invalid Phone"),
              _buildModernField(controller: emailController, label: "Email Address", icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress),
              _buildModernField(controller: cityController, label: "City", icon: Icons.location_city_outlined),

              _buildSectionHeader("Job Details", icon: Icons.work_outline_rounded),
              _buildModernDropdown(label: "Role", items: roles, value: selectedRole, onChanged: (v) => setState(() => selectedRole = v), icon: Icons.admin_panel_settings_outlined),
              _buildModernDropdown(label: "Department", items: departments, value: selectedDepartment, onChanged: (v) => setState(() => selectedDepartment = v), icon: Icons.business_outlined),
              _buildModernDropdown(label: "Designation", items: designations, value: selectedDesignation, onChanged: (v) => setState(() => selectedDesignation = v), icon: Icons.assignment_ind_outlined),
              _buildModernField(controller: hireDateController, label: "Hire Date", icon: Icons.calendar_today_outlined, isReadOnly: true, onTap: pickDate),

              _buildSectionHeader("Financial Information", icon: Icons.account_balance_wallet_outlined),
              _buildModernField(controller: bankNameController, label: "Bank Name", icon: Icons.account_balance_outlined),
              _buildModernField(controller: accountNoController, label: "Account No", icon: Icons.pin_outlined, keyboardType: TextInputType.number),
              _buildModernField(controller: salaryController, label: "Salary", icon: Icons.attach_money_outlined, keyboardType: TextInputType.number),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: isLoading ? null : saveEmployee,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700, // Updated Button Color
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text("Save Details", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}