import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;

class StockReportPage extends StatefulWidget {
  const StockReportPage({super.key});

  @override
  State<StockReportPage> createState() => _StockReportPageState();
}

class _StockReportPageState extends State<StockReportPage> {
  final Color primaryColor = const Color(0xFFFF7E00);

  List<dynamic> items = [];

  // ================= FIREBASE =================
  Stream<QuerySnapshot> getProducts() {
    return FirebaseFirestore.instance
        .collection('stock')
        .orderBy('productName')
        .snapshots();
  }

  // ================= STATUS =================
  String getStatus(int stock) {
    if (stock == 0) return "OUT";
    if (stock <= 5) return "LOW";
    return "OK";
  }

  PdfColor getStatusColor(int stock) {
    if (stock == 0) return PdfColors.red;
    if (stock <= 5) return PdfColors.orange;
    return PdfColors.green;
  }

  // ================= PDF =================
  Future<void> generateAndSharePDF(List<dynamic> docs) async {
    final pdf = pw.Document();

    final logoBytes =
    (await rootBundle.load('assets/images/sky.png'))
        .buffer
        .asUint8List();

    final logo = pw.MemoryImage(logoBytes);

    DateTime now = DateTime.now();
    double totalValue = 0;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [

              // ================= HEADER (LOGO LEFT + CENTER TITLE) =================
              pw.Stack(
                alignment: pw.Alignment.center,
                children: [

                  // LOGO LEFT
                  pw.Row(
                    children: [
                      pw.Image(logo, width: 80, height: 80),
                    ],
                  ),

                  // CENTER TEXT
                  pw.Center(
                    child: pw.Text(
                      "SKYTRONIX",
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 10),

              // ================= TITLE =================
              pw.Center(
                child: pw.Text(
                  "STOCK REPORT",
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),

              pw.Center(
                child: pw.Text(
                  "Date: ${now.toString().split(' ')[0]}   Time: ${now.hour}:${now.minute.toString().padLeft(2, '0')}",
                ),
              ),

              pw.SizedBox(height: 15),

              // ================= TABLE =================
              pw.Table(
                border: pw.TableBorder.all(),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1),
                  1: const pw.FlexColumnWidth(4),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FlexColumnWidth(2),
                  4: const pw.FlexColumnWidth(2),
                },
                children: [

                  // HEADER
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.orange,
                    ),
                    children: [
                      _cell("S.No", true),
                      _cell("Product", true),
                      _cell("Price", true),
                      _cell("Stock", true),
                      _cell("Status", true),
                    ],
                  ),

                  // DATA ROWS
                  ...List.generate(docs.length, (index) {
                    final data =
                    docs[index].data() as Map<String, dynamic>;

                    int stock = int.tryParse(
                        data['productStockQuantity'].toString()) ??
                        0;

                    double price = double.tryParse(
                        data['productSalePrice'].toString()) ??
                        0;

                    totalValue += price * stock;

                    String status = getStatus(stock);
                    PdfColor color = getStatusColor(stock);

                    return pw.TableRow(
                      children: [
                        _cell("${index + 1}", false),
                        _cell(data['productName'] ?? "", false),
                        _cell("Rs $price", false),
                        _cell("$stock", false),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            status,
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),

              pw.SizedBox(height: 15),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: "stock_report.pdf",
    );
  }

  // ================= CELL =================
  pw.Widget _cell(String text, bool isHeader) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight:
          isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.white : PdfColors.black,
        ),
      ),
    );
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Stock Report"),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: getProducts(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          items = snapshot.data!.docs;

          return Column(
            children: [

              // HEADER
              Container(
                color: primaryColor,
                padding: const EdgeInsets.all(10),
                child: const Row(
                  children: [
                    Expanded(
                        flex: 4,
                        child: Text("Product",
                            style: TextStyle(color: Colors.white))),
                    Expanded(
                        flex: 2,
                        child: Text("Stock",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white))),
                    Expanded(
                        flex: 2,
                        child: Text("Price",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white))),
                    Expanded(
                        flex: 2,
                        child: Text("Status",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white))),
                  ],
                ),
              ),

              // LIST
              Expanded(
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final data =
                    items[index].data() as Map<String, dynamic>;

                    int stock = int.tryParse(
                        data['productStockQuantity'].toString()) ??
                        0;

                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom:
                          BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                              flex: 4,
                              child: Text(data['productName'] ?? "")),
                          Expanded(
                              flex: 2,
                              child: Text("$stock",
                                  textAlign: TextAlign.center)),
                          Expanded(
                              flex: 2,
                              child: Text(
                                  "Rs ${data['productSalePrice']}",
                                  textAlign: TextAlign.center)),
                          Expanded(
                            flex: 2,
                            child: Center(
                              child: stockStatusBadge(stock),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),

      // ================= PDF BUTTON =================
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (items.isEmpty) return;
          generateAndSharePDF(items);
        },
        backgroundColor: Colors.green,
        icon: const Icon(Icons.picture_as_pdf),
        label: const Text("Share PDF"),
      ),
    );
  }

  // ================= STATUS BADGE =================
  Widget stockStatusBadge(int stock) {
    if (stock == 0) return _badge("OUT", Colors.red);
    if (stock <= 5) return _badge("LOW", Colors.orange);
    return _badge("OK", Colors.green);
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}