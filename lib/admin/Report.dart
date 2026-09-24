import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
// PDF Imports
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
// Added these imports for loading images
import 'package:flutter/services.dart' show rootBundle;
import 'dart:typed_data';
import 'dart:io';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  // Date Range State
  DateTimeRange? _selectedDateRange;

  // Search State
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  // Theme & Format
  final Color kPrimaryColor = const Color(0xFF1A237E);
  final Color kAccentColor = const Color(0xFFFF6F00);
  final currencyFormatter = NumberFormat.currency(symbol: "Rs ", decimalDigits: 0);
  final dateFormatter = DateFormat('dd MMM yyyy');
  final dayFormatter = DateFormat('E'); // Mon, Tue, etc.

  // Colors for Pie Chart (Distinct colors for every day)
  final List<Color> chartColors = [
    const Color(0xFF26A69A), // Teal
    const Color(0xFFEF5350), // Red
    const Color(0xFF42A5F5), // Blue
    const Color(0xFFFFA726), // Orange
    const Color(0xFFAB47BC), // Purple
    const Color(0xFF66BB6A), // Green
    const Color(0xFF8D6E63), // Brown
  ];

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _selectedDateRange = DateTimeRange(
      start: DateTime(today.year, today.month, today.day),
      end: DateTime(today.year, today.month, today.day, 23, 59, 59),
    );

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _selectedDateRange,
      saveText: 'Done',
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedDateRange = DateTimeRange(
          start: DateTime(picked.start.year, picked.start.month, picked.start.day),
          end: DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59),
        );
      });
    }
  }

  // --- GENERATE PDF (UPDATED WITH LOGO) ---
  Future<void> _generateAndSharePDF(List<QueryDocumentSnapshot> docs) async {
    final pdf = pw.Document();

    // Define PDF Theme
    final baseFont = await PdfGoogleFonts.nunitoRegular();
    final boldFont = await PdfGoogleFonts.nunitoBold();

    // --- LOAD LOGO IMAGE ---
    // Make sure you have 'assets/logo.png' defined in pubspec.yaml
    final ByteData logoData = await rootBundle.load('assets/images/sky.png');
    final Uint8List logoBytes = logoData.buffer.asUint8List();
    final pw.ImageProvider logoImage = pw.MemoryImage(logoBytes);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // --- HEADER ROW ---
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  // 1. LOGO (Top Left) - Circular Avatar
                  pw.Container(
                    width: 60,
                    height: 60,
                    child: pw.ClipRRect(
                      horizontalRadius: 30,
                      verticalRadius: 30,
                      child: pw.Image(
                        logoImage,
                        fit: pw.BoxFit.cover,
                      ),
                    ),
                  ),

                  // 2. Organization Name (Top Center)
                  pw.Expanded(
                    child: pw.Center(
                      child: pw.Column(
                        children: [
                          pw.Text(
                            "SKYTRONIX",
                            style: pw.TextStyle(
                              fontSize: 24,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blue900,
                              font: boldFont,
                            ),
                          ),
                          pw.SizedBox(height: 5),
                          pw.Text(
                            "Sales Report",
                            style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700, font: baseFont),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Spacer to balance the row
                  pw.SizedBox(width: 60),
                ],
              ),

              pw.SizedBox(height: 30),

              // --- TABLE ---
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 1),
                columnWidths: {
                  0: const pw.FixedColumnWidth(60),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FixedColumnWidth(80),
                  3: const pw.FlexColumnWidth(1.5),
                  4: const pw.FixedColumnWidth(70),
                  5: const pw.FixedColumnWidth(70),
                },
                children: [
                  // Table Header
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColors.blue100),
                    children: [
                      _buildTableCell("Invoice No", isHeader: true, font: boldFont),
                      _buildTableCell("Customer Name", isHeader: true, font: boldFont),
                      _buildTableCell("Phone", isHeader: true, font: boldFont),
                      _buildTableCell("Payment Method", isHeader: true, font: boldFont),
                      _buildTableCell("Date", isHeader: true, font: boldFont),
                      _buildTableCell("Total", isHeader: true, font: boldFont),
                    ],
                  ),
                  // Table Rows
                  ...docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final Timestamp ts = data['date'] as Timestamp? ?? Timestamp.now();
                    return pw.TableRow(
                      children: [
                        _buildTableCell(data['invoiceNo']?.toString() ?? '', font: baseFont),
                        _buildTableCell(data['customerName']?.toString() ?? '', font: baseFont),
                        _buildTableCell(data['customerPhone']?.toString() ?? '', font: baseFont),
                        _buildTableCell(data['paymentMethod']?.toString() ?? '', font: baseFont),
                        _buildTableCell(dateFormatter.format(ts.toDate()), font: baseFont),
                        _buildTableCell(currencyFormatter.format(data['totalAmount']), font: boldFont, alignRight: true),
                      ],
                    );
                  }).toList(),
                ],
              ),
            ],
          );
        },
      ),
    );

    // Save and Share
    final output = await getTemporaryDirectory();
    final file = File("${output.path}/sales_report.pdf");
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles([XFile(file.path)], text: 'Sales Report PDF');
  }

  // Helper for PDF Table Cell
  pw.Widget _buildTableCell(String text, {required pw.Font font, bool isHeader = false, bool alignRight = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      alignment: alignRight ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 12 : 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          font: font,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedDateRange == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final start = _selectedDateRange!.start;
    final end = _selectedDateRange!.end;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text("Weekly Report",),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: CustomScrollView(
        slivers: [
          // --- HEADER: DATE RANGE ---
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: InkWell(
                onTap: _pickDateRange,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kPrimaryColor.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.date_range, color: Colors.orange),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Report Period", style: TextStyle(fontSize: 12, color: Colors.grey)),
                              Text(
                                "${dateFormatter.format(start)} - ${dateFormatter.format(end)}",
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Icon(Icons.edit, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // --- STATS ROW ---
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      title: "Today Sales",
                      stream: FirebaseFirestore.instance
                          .collection('invoices')
                          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
                          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
                          .snapshots(),
                      icon: Icons.attach_money,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildWeekSalesCard(end),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // --- PIE CHART: 7 DAYS DISTRIBUTION ---
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                ),
                child: Column(
                  children: [
                    const Text("Last 7 Days Distribution (%)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 220,
                      child: _buildDailyPieChart(end),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // --- SEARCH BAR ---
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: "Search Customer or Invoice #",
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                ),
              ),
            ),
          ),

          // --- LIST ---
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('invoices')
                .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
                .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
                .orderBy('date', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const SliverFillRemaining(child: Center(child: Text("No records found.")));
              }

              final allDocs = snapshot.data!.docs;
              final filteredDocs = allDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final name = (data['customerName'] ?? '').toString().toLowerCase();
                final invoice = (data['invoiceNo'] ?? '').toString().toLowerCase();
                return name.contains(_searchQuery) || invoice.contains(_searchQuery);
              }).toList();

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    var doc = filteredDocs[index];
                    var data = doc.data() as Map<String, dynamic>;
                    return _buildTransactionTile(data);
                  },
                  childCount: filteredDocs.length,
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),

      // Export Button
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _triggerExport(start, end),
        backgroundColor: const Color(0xFF1A237E),
        icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
        label: const Text("Export PDF", style: TextStyle(color: Colors.white)),
      ),
    );
  }

  void _triggerExport(DateTime start, DateTime end) async {
    final snap = await FirebaseFirestore.instance
        .collection('invoices')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();

    if(snap.docs.isNotEmpty) {
      _generateAndSharePDF(snap.docs);
    } else {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No data to export")));
    }
  }

  // --- WEEK SALES CARD ---
  Widget _buildWeekSalesCard(DateTime endDate) {
    DateTime weekStart = endDate.subtract(const Duration(days: 6));

    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.calendar_view_week, color: Colors.purple),
              const Text("Week Sales", style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 5),
              StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('invoices')
                      .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
                      .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
                      .snapshots(),
                  builder: (context, snap) {
                    double total = 0;
                    if(snap.hasData) {
                      for(var doc in snap.data!.docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        total += (data['totalAmount'] ?? 0.0);
                      }
                    }
                    return Text(
                        currencyFormatter.format(total),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.purple)
                    );
                  }
              )
            ]
        )
    );
  }

  // --- WIDGET: PIE CHART LOGIC ---
  Widget _buildDailyPieChart(DateTime endDate) {
    DateTime startDate = endDate.subtract(const Duration(days: 6));

    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('invoices')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        Map<String, double> dailyData = {};
        double totalSales = 0;

        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final Timestamp ts = data['date'] as Timestamp? ?? Timestamp.now();
          final String dayLabel = dayFormatter.format(ts.toDate());
          final double amount = (data['totalAmount'] ?? 0.0);

          dailyData[dayLabel] = (dailyData[dayLabel] ?? 0.0) + amount;
          totalSales += amount;
        }

        if (totalSales == 0) return const Center(child: Text("No sales in the last 7 days"));

        int colorIndex = 0;
        List<String> dayKeys = dailyData.keys.toList();

        return Row(
          children: [
            Expanded(
              flex: 3,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: dailyData.entries.map((entry) {
                    final double value = entry.value;
                    final double percent = (value / totalSales) * 100;
                    final Color color = chartColors[colorIndex % chartColors.length];
                    colorIndex++;

                    return PieChartSectionData(
                      color: color,
                      value: value,
                      title: '${percent.toStringAsFixed(0)}%',
                      radius: 50,
                      titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    );
                  }).toList(),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: dailyData.entries.map((entry) {
                  final double percent = (entry.value / totalSales) * 100;
                  final idx = dayKeys.indexOf(entry.key);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: chartColors[idx % chartColors.length],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text("${entry.key}", style: const TextStyle(fontSize: 12)),
                        ),
                        Text("${percent.toStringAsFixed(0)}%", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            )
          ],
        );
      },
    );
  }

  // Helper: Stat Card
  Widget _buildStatCard({required String title, required Stream<QuerySnapshot> stream, required IconData icon, required Color color}) {
    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 5),
              StreamBuilder<QuerySnapshot>(
                  stream: stream,
                  builder: (context, snap) {
                    double total = 0;
                    if(snap.hasData) {
                      for(var doc in snap.data!.docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        total += (data['totalAmount'] ?? 0.0);
                      }
                    }
                    return Text(
                        currencyFormatter.format(total),
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)
                    );
                  }
              )
            ]
        )
    );
  }

  // Helper: Transaction List Tile
  Widget _buildTransactionTile(Map<String, dynamic> data) {
    final Timestamp ts = data['date'] as Timestamp? ?? Timestamp.now();
    final DateTime dt = ts.toDate();
    return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.receipt_long, size: 20)),
            title: Text(data['customerName'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("#${data['invoiceNo']} • ${dateFormatter.format(dt)}", style: const TextStyle(fontSize: 12)),
            trailing: Text(
                currencyFormatter.format(data['totalAmount']),
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)
            )
        )
    );
  }
}