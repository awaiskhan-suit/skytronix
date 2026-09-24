import 'package:flutter/material.dart';
import 'package:skytronix/admin/sales.dart';
import 'package:skytronix/admin/staff.dart';
import 'package:skytronix/admin/supplier.dart';
import 'package:skytronix/admin/supplier_bill.dart';
import '../main.dart';
import 'Add_Supplier.dart';
import 'Report.dart';
import 'add_customer.dart';
import 'add_stock.dart';
import 'adding_customer.dart';
import 'cash_book.dart';
import 'cash_in.dart';
import 'expenses.dart';
import 'invoice_screen.dart';
// ✅ ADDED: Import your Sales Report Screen here


class SupplierScreen extends StatefulWidget {
  const SupplierScreen({super.key});

  @override
  State<SupplierScreen> createState() => _SupplierScreenState();
}

class _SupplierScreenState extends State<SupplierScreen> {
  int _bottomIndex = 0;

  // ✅ UPDATED: Navigation Logic for Bottom Bar
  void _onBottomTap(int index) {
    setState(() {
      _bottomIndex = index;
    });

    if (index == 0) {
      // Home: Already here, do nothing or refresh
    } else if (index == 1) {
      // 🛒 SALES: Navigate to Sales Report
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SalesReportScreen()),
      );
    } else if (index == 2) {
      // 📊 REPORTS: You can add your Report Screen here
      Navigator.push(context, MaterialPageRoute(builder: (context) => const ReportScreen()));
    } else if (index == 3) {
      // ⋮ MORE: You can add your Settings/More Screen here
      // Navigator.push(context, MaterialPageRoute(builder: (context) => MoreScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  _buildActionButtons(),
                  const SizedBox(height: 30),
                  _buildGuideCard(),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  // 🔶 HEADER (UPDATED WITH SKYTRONIX TEXT)
  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFFFF7E00),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      padding: const EdgeInsets.only(top: 40, bottom: 20, left: 15, right: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [

              _buildTab("Customer", false, onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const CustomerScreen()),
                );
              }),
              const SizedBox(width: 10),
              _buildTab("Suppliers", true,),
              const SizedBox(width: 10),
              _buildTab("Staff", false, onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const StaffScreen()),
                );
              }),
            ],
          ),
          const SizedBox(height: 15),

          // 🟢 ADDED: CENTERED SKYTRONIX TEXT
          const Align(
            alignment: Alignment.center,
            child: Text(
              "SKYTRONIX",
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Align(
            alignment: Alignment.center,
            child: Text(
              "For Invertors Businesses",
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.0,
              ),
            ),
          ),

        ],
      ),
    );
  }

  Widget _amountWidget(String title, String amount, bool isLeft) {
    return Expanded(
      child: Column(
        crossAxisAlignment: isLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            amount,
            style: const TextStyle(
                color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // 🔷 TAB
  Widget _buildTab(String text, bool isSelected, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? const Color(0xFFFF7E00) : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  // 🔷 ACTION BUTTONS (CUSTOMER)
  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CashBook(),
                ),
              );
            },
            child: _buildActionButton(
              "CASH",
              Icons.account_balance_wallet,
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const StockScreen(),
                ),
              );
            },
            child: _buildActionButton(
              "STOCK",
              Icons.inventory_2_outlined,
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SupplierBillingScreen(),
                ),
              );
            },
            child: _buildActionButton(
              "BILL",
              Icons.receipt,
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ExpenseScreen(),
                ),
              );
            },
            child: _buildActionButton(
              "EXPENSES",
              Icons.money_off,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: const Color(0xFFFF7E00).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFFFF7E00), size: 28),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54),
        ),
      ],
    );
  }

  // 🟩 GUIDE CARD (CUSTOMER VERSION)
  Widget _buildGuideCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Image.asset(
              'assets/images/ttt.png',
              height: 160,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 50),
            ),
          ),
          const SizedBox(height: 15),
          const Row(
            children: [
              Icon(Icons.person_add_alt_1, color: Color(0xFFFF7E00), size: 20),
              SizedBox(width: 15),
              Expanded(
                child: Text("Add Supplier",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
          const SizedBox(height: 5),
          const Padding(
            padding: EdgeInsets.only(left: 35),
            child: Text(
              "Add your Supplier",
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => SupplierFirebaseScreen()));
              },
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFFFF7E00),
                foregroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFFFF7E00)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text("ADD SUPPLIER",
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // 🔻 BOTTOM NAV
  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _bottomIndex,
      onTap: _onBottomTap,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: const Color(0xFFFF7E00),
      unselectedItemColor: Colors.grey,
      showUnselectedLabels: true,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(
          icon: Icon(Icons.point_of_sale),
          label: 'Sales',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Report'),
        BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'More'),
      ],
    );
  }
}