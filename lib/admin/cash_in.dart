import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'cashed_in.dart';
import 'cashed_out.dart';

class CashBook extends StatelessWidget {
  CashBook({super.key});

  final currencyFormatter = NumberFormat.currency(symbol: "Rs ", decimalDigits: 0);
  final Color kBgColor = const Color(0xFFF5F7FA);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(
        elevation: 4,
        shadowColor: Colors.orange.withOpacity(0.3),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          "Cash Book",
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // 1. Reading Cash In (Correct collection name)
        stream: FirebaseFirestore.instance.collection('cash_in').snapshots(),
        builder: (context, inSnapshot) {
          if (inSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.orange));
          }

          double totalIn = 0;
          if (inSnapshot.hasData) {
            for (var doc in inSnapshot.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              final amount = data['amount'];
              // Robust parsing: Handle both Number and String types
              if (amount is num) {
                totalIn += amount;
              } else if (amount is String) {
                totalIn += double.tryParse(amount) ?? 0;
              }
            }
          }

          return StreamBuilder<QuerySnapshot>(
            // 2. READING CASH OUT (FIXED: Changed 'cash_out' to 'cashout' to match your saving screen)
            stream: FirebaseFirestore.instance.collection('cashout').snapshots(),
            builder: (context, outSnapshot) {
              if (outSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.orange));
              }

              double totalOut = 0;
              if (outSnapshot.hasData) {
                // Debug: Print how many documents found
                print("Cash Out Docs Found: ${outSnapshot.data!.docs.length}");

                for (var doc in outSnapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final amount = data['amount'];
                  // Robust parsing
                  if (amount is num) {
                    totalOut += amount;
                  } else if (amount is String) {
                    totalOut += double.tryParse(amount) ?? 0;
                  }
                }
              }

              double totalBalance = totalIn - totalOut;

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // --- 1. MODERN SUMMARY CARDS ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: [
                          _buildModernCard(
                            "Cash In",
                            totalIn,
                            [Color(0xFF11998e), Color(0xFF38ef7d)],
                            Icons.arrow_downward,
                          ),
                          const SizedBox(width: 12),
                          _buildModernCard(
                            "Cash Out",
                            totalOut,
                            [Color(0xFFcb2d3e), Color(0xFFef473a)],
                            Icons.arrow_upward,
                          ),
                          const SizedBox(width: 12),
                          _buildModernCard(
                            "Total",
                            totalBalance,
                            [Color(0xFF2193b0), Color(0xFF6dd5ed)],
                            Icons.account_balance_wallet,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 50),

                    // --- 2. USER IMAGE SECTION ---
                    Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.2),
                                blurRadius: 25,
                                spreadRadius: 8,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              // 👇 REPLACE WITH YOUR IMAGE PATH
                              'assets/images/ttt.png',
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 120,
                                  height: 120,
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.image_not_supported, size: 40, color: Colors.grey),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          "Welcome Back",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          "Total Balance: ${currencyFormatter.format(totalBalance)}",
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 50),

                    // --- 3. MODERN ACTION BUTTONS ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        children: [
                          _buildModernActionButton(
                            context,
                            label: "Add Cash In",
                            icon: Icons.add_circle_outline,
                            gradientColors: [Color(0xFF56ab2f), Color(0xFFa8e063)],
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const CashInScreen()),
                              );
                            },
                          ),
                          const SizedBox(height: 20),
                          _buildModernActionButton(
                            context,
                            label: "Add Cash Out",
                            icon: Icons.remove_circle_outline,
                            gradientColors: [Color(0xFFeb3349), Color(0xFFf45c43)],
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const CashOutScreen()),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    if (totalIn == 0 && totalOut == 0)
                      const Text(
                        "Start by adding a transaction",
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildModernCard(String title, double amount, List<Color> colors, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: colors[0].withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white70, size: 22),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                currencyFormatter.format(amount),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernActionButton(
      BuildContext context, {
        required String label,
        required IconData icon,
        required List<Color> gradientColors,
        required VoidCallback onTap,
      }) {
    return InkWell(
      onTap: onTap,
      splashColor: Colors.white.withOpacity(0.3),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        height: 65,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradientColors),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: gradientColors[0].withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 26),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}