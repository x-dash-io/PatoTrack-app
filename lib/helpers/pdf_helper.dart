// PdfHelper provides utilities for generating and sharing PDF reports from transaction data.

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/transaction.dart' as model;

class PdfHelper {
  // Generates and shares a PDF report for the given transactions and user, using the specified file name.
  // IMPORTANT: Only business transactions are included in the PDF for loan/investor applications.
  static Future<void> generateAndSharePdf(List<model.Transaction> transactions,
      String userName, String fileName) async {
    // Filter to only include business transactions (for loan/investor applications)
    final businessTransactions = transactions.where((t) => t.tag == 'business').toList();
    
    if (businessTransactions.isEmpty) {
      throw Exception('No business transactions found. Cannot generate business report.');
    }

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageTheme: const pw.PageTheme(
          margin: pw.EdgeInsets.all(32),
        ),
        header: (pw.Context context) => _buildHeader(userName, businessTransactions),
        build: (pw.Context context) {
          return [
            _buildBusinessInfo(businessTransactions),
            pw.SizedBox(height: 20),
            _buildTransactionTable(businessTransactions),
            pw.Divider(),
            _buildSummary(businessTransactions),
          ];
        },
      ),
    );

    // Use the provided fileName for the generated PDF instead of a hardcoded value.
    await Printing.sharePdf(bytes: await pdf.save(), filename: fileName);
  }

  static pw.Widget _buildHeader(String userName, List<model.Transaction> transactions) {
    // Determine report period from transactions
    if (transactions.isEmpty) {
      return pw.SizedBox();
    }
    
    final dates = transactions.map((t) => DateTime.parse(t.date)).toList();
    dates.sort();
    final startDate = dates.first;
    final endDate = dates.last;
    
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('BUSINESS FINANCIAL REPORT',
            style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Text('Business Owner: $userName',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text('Report Period: ${DateFormat('MMM dd, yyyy').format(startDate)} - ${DateFormat('MMM dd, yyyy').format(endDate)}',
            style: const pw.TextStyle(fontSize: 12)),
        pw.SizedBox(height: 4),
        pw.Text('Report Generated on: ${DateFormat('MMMM dd, yyyy').format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 12)),
        pw.Text('Note: This report contains ONLY business transactions',
            style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic)),
        pw.SizedBox(height: 20),
      ],
    );
  }

  static pw.Widget _buildBusinessInfo(List<model.Transaction> transactions) {
    // Calculate key business metrics
    double totalBusinessIncome = 0;
    double totalBusinessExpenses = 0;
    int incomeCount = 0;
    int expenseCount = 0;

    for (var t in transactions) {
      if (t.type == 'income') {
        totalBusinessIncome += t.amount;
        incomeCount++;
      } else {
        totalBusinessExpenses += t.amount;
        expenseCount++;
      }
    }
    
    final netProfit = totalBusinessIncome - totalBusinessExpenses;
    final profitMargin = totalBusinessIncome > 0 
        ? (netProfit / totalBusinessIncome * 100) 
        : 0.0;

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey200,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Business Overview',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Total Income Transactions:', style: const pw.TextStyle(fontSize: 11)),
                  pw.Text('$incomeCount', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Total Expense Transactions:', style: const pw.TextStyle(fontSize: 11)),
                  pw.Text('$expenseCount', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Divider(),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Gross Revenue:', style: const pw.TextStyle(fontSize: 12)),
                  pw.Text('KSh ${totalBusinessIncome.toStringAsFixed(2)}',
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.green)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Net Profit Margin:', style: const pw.TextStyle(fontSize: 12)),
                  pw.Text('${profitMargin.toStringAsFixed(1)}%',
                      style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: profitMargin >= 0 ? PdfColors.green : PdfColors.red)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTransactionTable(
      List<model.Transaction> transactions) {
    // Sort transactions by date (newest first) for better readability
    final sortedTransactions = List<model.Transaction>.from(transactions);
    sortedTransactions.sort((a, b) {
      return DateTime.parse(b.date).compareTo(DateTime.parse(a.date));
    });

    const tableHeaders = ['Date', 'Description', 'Type', 'Amount'];

    return pw.Table.fromTextArray(
      headers: tableHeaders,
      data: sortedTransactions.map((transaction) {
        final date = DateTime.parse(transaction.date);
        // Remove MPESA transaction IDs from description (format: (XXXXXXXXXX))
        String cleanDescription = transaction.description.isEmpty 
            ? '-' 
            : transaction.description.replaceAll(RegExp(r'\([A-Z0-9]{10}\)'), '').trim();
        if (cleanDescription.isEmpty) cleanDescription = '-';
        return [
          DateFormat('MMM dd, yyyy').format(date),
          cleanDescription,
          transaction.type.toUpperCase(),
          'KSh ${transaction.amount.toStringAsFixed(2)}',
        ];
      }).toList(),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
      cellStyle: const pw.TextStyle(fontSize: 10),
      cellAlignment: pw.Alignment.centerLeft,
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellPadding: const pw.EdgeInsets.all(6),
      border: pw.TableBorder.all(color: PdfColors.grey400),
    );
  }

  static pw.Widget _buildSummary(List<model.Transaction> transactions) {
    double totalIncome = 0;
    double totalExpenses = 0;

    for (var t in transactions) {
      if (t.type == 'income') {
        totalIncome += t.amount;
      } else {
        totalExpenses += t.amount;
      }
    }
    final netProfit = totalIncome - totalExpenses;
    final profitMargin = totalIncome > 0 
        ? (netProfit / totalIncome * 100) 
        : 0.0;

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey600, width: 2),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text('BUSINESS FINANCIAL SUMMARY',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Total Business Revenue:',
                  style: const pw.TextStyle(fontSize: 12)),
              pw.Text('KSh ${totalIncome.toStringAsFixed(2)}',
                  style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.green)),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Total Business Expenses:',
                  style: const pw.TextStyle(fontSize: 12)),
              pw.Text('KSh ${totalExpenses.toStringAsFixed(2)}',
                  style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.red)),
            ],
          ),
          pw.Divider(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Net Profit / Loss:',
                  style: pw.TextStyle(
                      fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Text('KSh ${netProfit.toStringAsFixed(2)}',
                  style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: netProfit >= 0 ? PdfColors.green : PdfColors.red)),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Profit Margin:',
                  style: const pw.TextStyle(fontSize: 12)),
              pw.Text('${profitMargin.toStringAsFixed(2)}%',
                  style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: profitMargin >= 0 ? PdfColors.green : PdfColors.red)),
            ],
          ),
        ],
      ),
    );
  }
}
