import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'invoice_pdf.dart' show CompanyInfo;

class StatementPdfEntry {
  final DateTime date;
  final String reference;
  final int debitMinor;
  final int creditMinor;
  final int runningBalanceMinor;
  final bool isInvoice;
  const StatementPdfEntry({
    required this.date,
    required this.reference,
    required this.debitMinor,
    required this.creditMinor,
    required this.runningBalanceMinor,
    required this.isInvoice,
  });
}

class StatementPdfData {
  final CompanyInfo company;
  final String clientName;
  final String currency;
  final DateTime? from;
  final DateTime? to;
  final int openingBalanceMinor;
  final int totalDebitMinor;
  final int totalCreditMinor;
  final int closingBalanceMinor;
  final List<StatementPdfEntry> entries;
  const StatementPdfData({
    required this.company,
    required this.clientName,
    required this.currency,
    required this.from,
    required this.to,
    required this.openingBalanceMinor,
    required this.totalDebitMinor,
    required this.totalCreditMinor,
    required this.closingBalanceMinor,
    required this.entries,
  });
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

String _periodText(DateTime? from, DateTime? to) {
  if (from == null && to == null) return 'كل الفترة';
  if (from != null && to != null) return 'من ${_date(from)} إلى ${_date(to)}';
  if (from != null) return 'من ${_date(from)}';
  return 'حتى ${_date(to!)}';
}

Future<(pw.Font, pw.Font, pw.Font)> _loadFonts() async => (
      await PdfGoogleFonts.iBMPlexSansArabicRegular(),
      await PdfGoogleFonts.iBMPlexSansArabicMedium(),
      await PdfGoogleFonts.iBMPlexSansArabicBold(),
    );

Future<Uint8List> buildStatementPdf(StatementPdfData d) async {
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
      pw.SizedBox(height: 24),
      _openingRow(d, medium),
      pw.SizedBox(height: 10),
      _table(d, bold, medium),
      pw.SizedBox(height: 14),
      _totals(d, medium),
      pw.SizedBox(height: 10),
      _closing(d, bold),
      pw.SizedBox(height: 32),
      _footer(d.company, medium),
    ],
  ));
  return doc.save();
}

pw.Widget _header(StatementPdfData d, pw.Font bold, pw.Font medium) => pw.Row(
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
          pw.Text('كشف حساب',
              style: pw.TextStyle(
                  font: bold, fontSize: 22, color: _accent, letterSpacing: 1)),
          pw.SizedBox(height: 8),
          pw.Text(d.clientName,
              style: pw.TextStyle(font: medium, fontSize: 11, color: _dark)),
          pw.Text(_periodText(d.from, d.to),
              style: pw.TextStyle(font: medium, fontSize: 9, color: _muted)),
        ]),
      ],
    );

pw.Widget _openingRow(StatementPdfData d, pw.Font medium) => pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: pw.BoxDecoration(
          color: _zebra, borderRadius: pw.BorderRadius.circular(4)),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('الرصيد الافتتاحي',
              style: pw.TextStyle(font: medium, fontSize: 9.5, color: _muted)),
          pw.Text(_money(d.openingBalanceMinor, d.currency),
              style: pw.TextStyle(font: medium, fontSize: 9.5, color: _dark)),
        ],
      ),
    );

pw.Widget _table(StatementPdfData d, pw.Font bold, pw.Font medium) {
  final rows = <pw.TableRow>[
    pw.TableRow(decoration: pw.BoxDecoration(color: _accent), children: [
      _h('الرصيد', medium),
      _h('دائن', medium),
      _h('مدين', medium),
      _h('البيان', medium),
      _h('التاريخ', medium),
    ]),
    for (var i = 0; i < d.entries.length; i++)
      pw.TableRow(
        decoration: pw.BoxDecoration(
          color: i.isEven ? PdfColors.white : _zebra,
          border: pw.Border(bottom: pw.BorderSide(color: _line, width: 0.5)),
        ),
        children: [
          _c(_money(d.entries[i].runningBalanceMinor, d.currency)),
          _c(d.entries[i].creditMinor == 0
              ? '-'
              : _money(d.entries[i].creditMinor, d.currency)),
          _c(d.entries[i].debitMinor == 0
              ? '-'
              : _money(d.entries[i].debitMinor, d.currency)),
          _c(d.entries[i].reference),
          _c(_date(d.entries[i].date)),
        ],
      ),
  ];
  return pw.Table(columnWidths: const {
    0: pw.FlexColumnWidth(1.9),
    1: pw.FlexColumnWidth(1.8),
    2: pw.FlexColumnWidth(1.8),
    3: pw.FlexColumnWidth(2.6),
    4: pw.FlexColumnWidth(1.6),
  }, children: rows);
}

pw.Widget _h(String t, pw.Font medium) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      child: pw.Text(t,
          style: pw.TextStyle(font: medium, fontSize: 9, color: PdfColors.white)),
    );

pw.Widget _c(String t) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      child: pw.Text(t, style: pw.TextStyle(fontSize: 8.5, color: _dark)),
    );

pw.Widget _totals(StatementPdfData d, pw.Font medium) => pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Text('إجمالي المدين: ${_money(d.totalDebitMinor, d.currency)}    '
            'إجمالي الدائن: ${_money(d.totalCreditMinor, d.currency)}',
            style: pw.TextStyle(font: medium, fontSize: 9, color: _muted)),
      ],
    );

pw.Widget _closing(StatementPdfData d, pw.Font bold) => pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Container(
          width: 240,
          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: pw.BoxDecoration(
              color: _accent, borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('الرصيد الختامي',
                  style: pw.TextStyle(
                      font: bold, fontSize: 12, color: PdfColors.white)),
              pw.Text(_money(d.closingBalanceMinor, d.currency),
                  style: pw.TextStyle(
                      font: bold, fontSize: 13, color: PdfColors.white)),
            ],
          ),
        ),
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

Future<void> shareStatementPdf(Uint8List bytes, String clientName) =>
    Printing.sharePdf(bytes: bytes, filename: 'statement_$clientName.pdf');

Future<void> previewStatementPdf(Uint8List bytes) =>
    Printing.layoutPdf(onLayout: (_) async => bytes);
