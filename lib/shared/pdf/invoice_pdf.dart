import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class CompanyInfo {
  final String name;
  final Uint8List? logoBytes;
  final String? address, phone, email, bankDetails;
  const CompanyInfo({
    required this.name,
    this.logoBytes,
    this.address,
    this.phone,
    this.email,
    this.bankDetails,
  });
}

class ClientInfo {
  final String name;
  final String? contactPerson, phone, address;
  const ClientInfo({
    required this.name,
    this.contactPerson,
    this.phone,
    this.address,
  });
}

class InvoiceLine {
  final String description;
  final double quantity;
  final int unitPriceMinor;
  const InvoiceLine({
    required this.description,
    required this.quantity,
    required this.unitPriceMinor,
  });
  int get lineTotalMinor => (quantity * unitPriceMinor).round();
}

class InvoicePdfData {
  final CompanyInfo company;
  final ClientInfo client;
  final String number;
  final DateTime issueDate;
  final DateTime? dueDate;
  final String currency;
  final List<InvoiceLine> items;
  final String? notes;
  const InvoicePdfData({
    required this.company,
    required this.client,
    required this.number,
    required this.issueDate,
    this.dueDate,
    required this.currency,
    required this.items,
    this.notes,
  });
  int get totalMinor => items.fold(0, (s, e) => s + e.lineTotalMinor);
}

final _accent = PdfColor.fromHex('#1F3A5F');
final _dark = PdfColor.fromHex('#1A1A1A');
final _muted = PdfColor.fromHex('#6B7280');
final _line = PdfColor.fromHex('#E6E8EB');
final _zebra = PdfColor.fromHex('#F7F8FA');

const _symbols = {'USD': '\$', 'SAR': 'ر.س', 'YER': 'ر.ي', 'AED': 'د.إ'};

String _money(int minor, String c) {
  final neg = minor < 0;
  final v = (minor.abs() / 100).toStringAsFixed(2);
  final p = v.split('.');
  final ip = p[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  return '${neg ? '-' : ''}$ip.${p[1]} ${_symbols[c] ?? c}';
}

String _date(DateTime d) =>
    '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

Future<(pw.Font, pw.Font, pw.Font)> _loadFonts() async {
  final regData = await rootBundle.load('assets/fonts/IBMPlexSansArabic-Regular.ttf');
  final medData = await rootBundle.load('assets/fonts/IBMPlexSansArabic-Medium.ttf');
  final boldData = await rootBundle.load('assets/fonts/IBMPlexSansArabic-Bold.ttf');
  return (
    pw.Font.ttf(regData),
    pw.Font.ttf(medData),
    pw.Font.ttf(boldData),
  );
}

Future<Uint8List> buildInvoicePdf(InvoicePdfData data) async {
  final (regular, medium, bold) = await _loadFonts();
  final doc = pw.Document();
  doc.addPage(pw.MultiPage(
    pageTheme: pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 44, 40, 40),
      textDirection: pw.TextDirection.rtl,
      theme: pw.ThemeData.withFont(base: regular, bold: bold).copyWith(
          defaultTextStyle:
              pw.TextStyle(font: regular, color: _dark, fontSize: 10)),
    ),
    build: (context) => [
      _header(data, bold, medium),
      pw.SizedBox(height: 28),
      _parties(data, bold, medium),
      pw.SizedBox(height: 24),
      _itemsTable(data, bold, medium),
      pw.SizedBox(height: 18),
      _totals(data, bold),
      if (data.notes != null && data.notes!.trim().isNotEmpty) ...[
        pw.SizedBox(height: 24),
        _notes(data.notes!, medium),
      ],
      pw.SizedBox(height: 32),
      _footer(data.company, medium),
    ],
  ));
  return doc.save();
}

pw.Widget _header(InvoicePdfData d, pw.Font bold, pw.Font medium) => pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
          if (d.company.logoBytes != null) ...[
            pw.Container(
                height: 48,
                width: 48,
                child: pw.Image(pw.MemoryImage(d.company.logoBytes!))),
            pw.SizedBox(width: 12),
          ],
          pw.Text(d.company.name,
              style: pw.TextStyle(font: bold, fontSize: 16, color: _dark)),
        ]),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text('فاتورة',
              style: pw.TextStyle(
                  font: bold, fontSize: 22, color: _accent, letterSpacing: 1)),
          pw.SizedBox(height: 8),
          _metaRow('رقم الفاتورة', d.number, medium),
          _metaRow('التاريخ', _date(d.issueDate), medium),
          if (d.dueDate != null) _metaRow('الاستحقاق', _date(d.dueDate!), medium),
        ]),
      ],
    );

pw.Widget _metaRow(String l, String v, pw.Font medium) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
        pw.Text('$l: ',
            style: pw.TextStyle(font: medium, fontSize: 9, color: _muted)),
        pw.Text(v, style: pw.TextStyle(font: medium, fontSize: 9, color: _dark)),
      ]),
    );

pw.Widget _parties(InvoicePdfData d, pw.Font bold, pw.Font medium) =>
    pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(14),
        decoration: pw.BoxDecoration(
            color: _zebra, borderRadius: pw.BorderRadius.circular(6)),
        child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('فاتورة إلى',
                  style: pw.TextStyle(font: medium, fontSize: 9, color: _muted)),
              pw.SizedBox(height: 4),
              pw.Text(d.client.name,
                  style: pw.TextStyle(font: bold, fontSize: 12, color: _dark)),
              if (d.client.contactPerson != null)
                pw.Text(d.client.contactPerson!,
                    style: pw.TextStyle(fontSize: 9, color: _muted)),
              if (d.client.address != null)
                pw.Text(d.client.address!,
                    style: pw.TextStyle(fontSize: 9, color: _muted)),
              if (d.client.phone != null)
                pw.Text(d.client.phone!,
                    style: pw.TextStyle(fontSize: 9, color: _muted)),
            ]),
      ),
    );

pw.Widget _itemsTable(InvoicePdfData d, pw.Font bold, pw.Font medium) {
  // Column order: index 0 = leftmost → index 3 = rightmost (RTL visual)
  // Visual RTL order (right→left): الوصف، الكمية، سعر الوحدة، الإجمالي
  final rows = <pw.TableRow>[
    pw.TableRow(decoration: pw.BoxDecoration(color: _accent), children: [
      _headCell('الإجمالي', medium, pw.TextAlign.left),
      _headCell('سعر الوحدة', medium, pw.TextAlign.center),
      _headCell('الكمية', medium, pw.TextAlign.center),
      _headCell('الوصف', medium, pw.TextAlign.right),
    ]),
    for (var i = 0; i < d.items.length; i++)
      pw.TableRow(
        decoration: pw.BoxDecoration(
          color: i.isEven ? PdfColors.white : _zebra,
          border: pw.Border(bottom: pw.BorderSide(color: _line, width: 0.5)),
        ),
        children: [
          _bodyCell(_money(d.items[i].lineTotalMinor, d.currency), pw.TextAlign.left,
              bold: bold),
          _bodyCell(_money(d.items[i].unitPriceMinor, d.currency), pw.TextAlign.center),
          _bodyCell(_qty(d.items[i].quantity), pw.TextAlign.center),
          _bodyCell(d.items[i].description, pw.TextAlign.right),
        ],
      ),
  ];
  return pw.Table(columnWidths: const {
    0: pw.FlexColumnWidth(1.6),
    1: pw.FlexColumnWidth(1.6),
    2: pw.FlexColumnWidth(1),
    3: pw.FlexColumnWidth(5.2),
  }, children: rows);
}

String _qty(double q) =>
    q == q.roundToDouble() ? q.toInt().toString() : q.toString();

pw.Widget _headCell(String t, pw.Font medium, pw.TextAlign a) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: pw.Text(t,
          textAlign: a,
          style: pw.TextStyle(font: medium, fontSize: 9.5, color: PdfColors.white)),
    );

pw.Widget _bodyCell(String t, pw.TextAlign a, {pw.Font? bold}) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      child: pw.Text(t,
          textAlign: a, style: pw.TextStyle(font: bold, fontSize: 9.5, color: _dark)),
    );

pw.Widget _totals(InvoicePdfData d, pw.Font bold) => pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Container(
          width: 220,
          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: pw.BoxDecoration(
              color: _accent, borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('الإجمالي',
                  style: pw.TextStyle(
                      font: bold, fontSize: 12, color: PdfColors.white)),
              pw.Text(_money(d.totalMinor, d.currency),
                  style: pw.TextStyle(
                      font: bold, fontSize: 13, color: PdfColors.white)),
            ],
          ),
        ),
      ],
    );

pw.Widget _notes(String notes, pw.Font medium) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('ملاحظات',
            style: pw.TextStyle(font: medium, fontSize: 9, color: _muted)),
        pw.SizedBox(height: 3),
        pw.Text(notes, style: pw.TextStyle(fontSize: 9.5, color: _dark)),
      ],
    );

pw.Widget _footer(CompanyInfo c, pw.Font medium) {
  final lines = <String>[
    if (c.bankDetails != null) c.bankDetails!,
    [
      if (c.phone != null) c.phone!,
      if (c.email != null) c.email!,
      if (c.address != null) c.address!,
    ].join('  •  '),
  ].where((e) => e.trim().isNotEmpty).toList();
  return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
    pw.Divider(color: _line, thickness: 0.5),
    pw.SizedBox(height: 6),
    for (final l in lines)
      pw.Text(l,
          style: pw.TextStyle(font: medium, fontSize: 8.5, color: _muted)),
  ]);
}

Future<void> shareInvoicePdf(Uint8List bytes, String invoiceNumber) =>
    Printing.sharePdf(bytes: bytes, filename: '$invoiceNumber.pdf');

Future<void> previewInvoicePdf(Uint8List bytes) =>
    Printing.layoutPdf(onLayout: (_) async => bytes);
