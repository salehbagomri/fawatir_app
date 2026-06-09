import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'invoice_pdf.dart' show CompanyInfo;

class ReceiptPdfData {
  final CompanyInfo company;
  final String receiptNumber;
  final DateTime date;
  final String receivedFrom;
  final int amountMinor;
  final String currency;
  final String? method;
  final String? invoiceNumber;
  final int? invoiceTotalMinor;
  final String? invoiceCurrency;
  final String? fxNote;
  final String? settlementNote;
  final String? notes;
  const ReceiptPdfData({
    required this.company,
    required this.receiptNumber,
    required this.date,
    required this.receivedFrom,
    required this.amountMinor,
    required this.currency,
    this.method,
    this.invoiceNumber,
    this.invoiceTotalMinor,
    this.invoiceCurrency,
    this.fxNote,
    this.settlementNote,
    this.notes,
  });
}

final _accent = PdfColor.fromHex('#1F3A5F');
final _green = PdfColor.fromHex('#1E7F4F');
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

Future<(pw.Font, pw.Font, pw.Font)> _loadFonts() async => (
      await PdfGoogleFonts.iBMPlexSansArabicRegular(),
      await PdfGoogleFonts.iBMPlexSansArabicMedium(),
      await PdfGoogleFonts.iBMPlexSansArabicBold(),
    );

Future<Uint8List> buildReceiptPdf(ReceiptPdfData d) async {
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
      _header(d, bold, medium),
      pw.SizedBox(height: 28),
      _receivedFrom(d, bold, medium),
      pw.SizedBox(height: 20),
      _amountBox(d, bold, medium),
      pw.SizedBox(height: 20),
      _details(d, medium),
      if (d.notes != null && d.notes!.trim().isNotEmpty) ...[
        pw.SizedBox(height: 22),
        _notes(d.notes!, medium),
      ],
      pw.SizedBox(height: 40),
      _signature(medium),
      pw.SizedBox(height: 24),
      _footer(d.company, medium),
    ],
  ));
  return doc.save();
}

pw.Widget _header(ReceiptPdfData d, pw.Font bold, pw.Font medium) => pw.Row(
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
          pw.Row(children: [
            pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#E8F4EE'),
                  borderRadius: pw.BorderRadius.circular(4)),
              child: pw.Text('مدفوع',
                  style:
                      pw.TextStyle(font: medium, fontSize: 8, color: _green)),
            ),
            pw.SizedBox(width: 8),
            pw.Text('سند قبض',
                style: pw.TextStyle(
                    font: bold, fontSize: 22, color: _accent, letterSpacing: 1)),
          ]),
          pw.SizedBox(height: 8),
          _metaRow('رقم السند', d.receiptNumber, medium),
          _metaRow('التاريخ', _date(d.date), medium),
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

pw.Widget _receivedFrom(ReceiptPdfData d, pw.Font bold, pw.Font medium) =>
    pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
          color: _zebra, borderRadius: pw.BorderRadius.circular(6)),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text('استلمنا من',
            style: pw.TextStyle(font: medium, fontSize: 9, color: _muted)),
        pw.SizedBox(height: 4),
        pw.Text(d.receivedFrom,
            style: pw.TextStyle(font: bold, fontSize: 12, color: _dark)),
      ]),
    );

pw.Widget _amountBox(ReceiptPdfData d, pw.Font bold, pw.Font medium) =>
    pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: pw.BoxDecoration(
          color: _accent, borderRadius: pw.BorderRadius.circular(6)),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('المبلغ المستلم',
              style: pw.TextStyle(
                  font: medium, fontSize: 11, color: PdfColors.white)),
          pw.Text(_money(d.amountMinor, d.currency),
              style: pw.TextStyle(
                  font: bold, fontSize: 18, color: PdfColors.white)),
        ],
      ),
    );

pw.Widget _details(ReceiptPdfData d, pw.Font medium) {
  final rows = <pw.Widget>[];
  void add(String label, String value, {PdfColor? vc}) {
    rows.add(pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(font: medium, fontSize: 9.5, color: _muted)),
          pw.Text(value,
              style:
                  pw.TextStyle(font: medium, fontSize: 9.5, color: vc ?? _dark)),
        ],
      ),
    ));
    rows.add(pw.Divider(color: _line, thickness: 0.5, height: 1));
  }

  if (d.invoiceNumber != null) {
    add('سداد عن فاتورة رقم', d.invoiceNumber!);
  }
  if (d.method != null) add('طريقة الدفع', d.method!);
  if (d.fxNote != null) add('معادلة العملة', d.fxNote!);
  if (d.settlementNote != null) {
    add('حالة الفاتورة', d.settlementNote!, vc: _green);
  }
  return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: rows);
}

pw.Widget _notes(String notes, pw.Font medium) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('ملاحظات',
            style: pw.TextStyle(font: medium, fontSize: 9, color: _muted)),
        pw.SizedBox(height: 3),
        pw.Text(notes, style: pw.TextStyle(fontSize: 9.5, color: _dark)),
      ],
    );

pw.Widget _signature(pw.Font medium) => pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.start,
      children: [
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
          pw.Container(width: 160, height: 0.6, color: _muted),
          pw.SizedBox(height: 4),
          pw.Text('التوقيع والختم',
              style: pw.TextStyle(font: medium, fontSize: 8.5, color: _muted)),
        ]),
      ],
    );

pw.Widget _footer(CompanyInfo c, pw.Font medium) {
  final lines = <String>[
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

Future<void> shareReceiptPdf(Uint8List bytes, String receiptNumber) =>
    Printing.sharePdf(bytes: bytes, filename: '$receiptNumber.pdf');

Future<void> previewReceiptPdf(Uint8List bytes) =>
    Printing.layoutPdf(onLayout: (_) async => bytes);
