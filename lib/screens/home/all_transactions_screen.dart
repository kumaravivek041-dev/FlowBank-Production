import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../../api/api_service.dart';

class PlaidTransaction {
  final String transactionId;
  final String name;
  final double amount;
  final String date;
  final String category;
  final String accountName;
  final bool isDebit;
  final String source; // 'plaid', 'manual', 'ocr'
  final String? manualId;

  PlaidTransaction({
    required this.transactionId,
    required this.name,
    required this.amount,
    required this.date,
    required this.category,
    required this.accountName,
    required this.isDebit,
    this.source = 'plaid',
    this.manualId,
  });

  factory PlaidTransaction.fromMap(Map<String, dynamic> map) {
    final double rawAmount = (map['amount'] as num?)?.toDouble() ?? 0.0;
    return PlaidTransaction(
      transactionId: map['transaction_id']?.toString() ?? map['id']?.toString() ?? '',
      name: map['name'] ?? map['merchant_name'] ?? 'Unknown',
      amount: rawAmount.abs(),
      date: map['date']?.toString() ?? '',
      category: _parseCategory(map['category']),
      accountName: map['account_name'] ?? map['accountName'] ?? 'My Account',
      isDebit: rawAmount > 0,
      source: 'plaid',
    );
  }

  factory PlaidTransaction.fromManual(Map<String, dynamic> map) {
    final rawDate = map['date']?.toString() ?? '';
    final dateStr = rawDate.contains('T') ? rawDate.split('T').first : rawDate;
    return PlaidTransaction(
      transactionId: 'manual_${map['_id']}',
      name: map['name']?.toString() ?? 'Transaction',
      amount: (map['amount'] as num?)?.toDouble().abs() ?? 0.0,
      date: dateStr,
      category: map['category']?.toString() ?? 'Other',
      accountName: (map['source'] == 'ocr') ? 'Receipt' : 'Manual',
      isDebit: (map['isDebit'] as bool?) ?? true,
      source: map['source']?.toString() ?? 'manual',
      manualId: map['_id']?.toString(),
    );
  }

  static String _parseCategory(dynamic cat) {
    if (cat == null) return 'Uncategorized';
    if (cat is String) return cat;
    if (cat is List && cat.isNotEmpty) return cat.last.toString();
    return 'Uncategorized';
  }
}

class AllTransactionsScreen extends StatefulWidget {
  final List<Map<String, dynamic>> rawTransactions;
  final String userName;

  const AllTransactionsScreen({
    super.key,
    required this.rawTransactions,
    required this.userName,
  });

  @override
  State<AllTransactionsScreen> createState() => _AllTransactionsScreenState();
}

class _AllTransactionsScreenState extends State<AllTransactionsScreen> {
  static const _blue = Color(0xFF1E88E5);
  static const _textDark = Color(0xFF1A1F36);
  static const _textMid = Color(0xFF475467);
  static const _textLight = Color(0xFF98A2B3);
  static const _bgGrey = Color(0xFFF5F7FA);
  static const _border = Color(0xFFE2E8F0);

  List<PlaidTransaction> _plaidTxs = [];
  List<PlaidTransaction> _manualTxs = [];
  late List<PlaidTransaction> _allTx;
  List<PlaidTransaction> _filtered = [];
  final _searchCtrl = TextEditingController();
  String _selectedFilter = 'All';
  String _selectedSort = 'Newest';
  bool _isExporting = false;
  Map<String, String> _categorizedMap = {};

  @override
  void initState() {
    super.initState();
    _plaidTxs = widget.rawTransactions.map((m) => PlaidTransaction.fromMap(m)).toList();
    _allTx = List.from(_plaidTxs);
    _applyFilters();
    _fetchCategorizations();
    _fetchManualTransactions();
  }

  Future<void> _fetchCategorizations() async {
    try {
      final res = await ApiService.get('/api/categorize/my-categorizations', context);
      if (res.statusCode == 200 && mounted) {
        final List data = jsonDecode(res.body);
        setState(() {
          _categorizedMap = {
            for (final r in data)
              r['transactionId'].toString(): (r['categoryRefName']?.toString().isNotEmpty == true
                  ? r['categoryRefName'].toString()
                  : r['categorizedTo'] == 'goal' ? 'Goal' : 'Group'),
          };
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchManualTransactions() async {
    try {
      final res = await ApiService.get('/api/manual-transactions', context);
      if (res.statusCode == 200 && mounted) {
        final List data = jsonDecode(res.body);
        _manualTxs = data.map<PlaidTransaction>((m) => PlaidTransaction.fromManual(m)).toList();
        _allTx = [..._plaidTxs, ..._manualTxs];
        _applyFilters();
      }
    } catch (_) {}
  }

  void _showAddTxSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddTransactionSheet(onAdded: () => _fetchManualTransactions()),
    );
  }

  void _showCategorizeSheet(PlaidTransaction tx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CategorizationSheet(
        tx: tx,
        onSuccess: (transactionId, refName) {
          if (mounted) setState(() => _categorizedMap[transactionId] = refName);
        },
      ),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _applyFilters() {
    List<PlaidTransaction> result = List.from(_allTx);

    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      result = result
          .where((t) =>
              t.name.toLowerCase().contains(q) ||
              t.category.toLowerCase().contains(q))
          .toList();
    }

    if (_selectedFilter == 'Debit') result = result.where((t) => t.isDebit).toList();
    if (_selectedFilter == 'Credit') result = result.where((t) => !t.isDebit).toList();

    switch (_selectedSort) {
      case 'Newest': result.sort((a, b) => b.date.compareTo(a.date)); break;
      case 'Oldest': result.sort((a, b) => a.date.compareTo(b.date)); break;
      case 'Highest': result.sort((a, b) => b.amount.compareTo(a.amount)); break;
      case 'Lowest': result.sort((a, b) => a.amount.compareTo(b.amount)); break;
    }

    setState(() => _filtered = result);
  }

  double get _totalDebit => _filtered.where((t) => t.isDebit).fold(0, (s, t) => s + t.amount);
  double get _totalCredit => _filtered.where((t) => !t.isDebit).fold(0, (s, t) => s + t.amount);

  Map<String, List<PlaidTransaction>> get _grouped {
    final Map<String, List<PlaidTransaction>> map = {};
    for (final tx in _filtered) {
      map.putIfAbsent(_groupLabel(tx.date), () => []).add(tx);
    }
    return map;
  }

  String _groupLabel(String raw) {
    try {
      final dt = DateTime.parse(raw);
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) return 'Today';
      final y = now.subtract(const Duration(days: 1));
      if (dt.year == y.year && dt.month == y.month && dt.day == y.day) return 'Yesterday';
      return DateFormat('MMMM d, yyyy').format(dt);
    } catch (_) { return raw; }
  }

  String _shortDate(String raw) {
    try { return DateFormat('MMM d').format(DateTime.parse(raw)); }
    catch (_) { return raw; }
  }

  Future<void> _exportXlsx() async {
    setState(() => _isExporting = true);
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Transactions'];
      final headers = ['Date', 'Name', 'Category', 'Account', 'Type', 'Amount'];
      for (int i = 0; i < headers.length; i++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = TextCellValue(headers[i]);
        cell.cellStyle = CellStyle(bold: true);
      }
      for (int i = 0; i < _filtered.length; i++) {
        final tx = _filtered[i];
        final r = i + 1;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r)).value = TextCellValue(tx.date);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r)).value = TextCellValue(tx.name);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r)).value = TextCellValue(tx.category);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: r)).value = TextCellValue(tx.accountName);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: r)).value = TextCellValue(tx.isDebit ? 'Debit' : 'Credit');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: r)).value = DoubleCellValue(tx.amount);
      }
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/transactions_${DateTime.now().millisecondsSinceEpoch}.xlsx');
      final bytes = excel.encode();
      if (bytes != null) { await file.writeAsBytes(bytes); await OpenFile.open(file.path); }
    } catch (e) { _snack('Export failed: $e'); }
    finally { setState(() => _isExporting = false); }
  }

  Future<void> _exportPdf() async {
    setState(() => _isExporting = true);
    try {
      final pdf = pw.Document();
      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('Transaction History', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.Text('${widget.userName}  ·  ${DateFormat('MMM d, yyyy').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 6),
        ]),
        build: (ctx) => [
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(1.2), 1: const pw.FlexColumnWidth(2.5),
              2: const pw.FlexColumnWidth(1.8), 3: const pw.FlexColumnWidth(1.2),
              4: const pw.FlexColumnWidth(1.2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blue800),
                children: ['Date', 'Name', 'Category', 'Type', 'Amount'].map((h) =>
                  pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: pw.Text(h, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9)))).toList(),
              ),
              ..._filtered.asMap().entries.map((e) {
                final tx = e.value;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: e.key.isEven ? PdfColors.white : PdfColors.grey50),
                  children: [tx.date, tx.name, tx.category, tx.isDebit ? 'Debit' : 'Credit', '\$${tx.amount.toStringAsFixed(2)}'].map((v) =>
                    pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      child: pw.Text(v, style: const pw.TextStyle(fontSize: 8)))).toList(),
                );
              }),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(6)),
            child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('Total: ${_filtered.length} transactions', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
              pw.Text('Spent: \$${_totalDebit.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9)),
              pw.Text('Received: \$${_totalCredit.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9)),
            ]),
          ),
        ],
      ));
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/transactions_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());
      await OpenFile.open(file.path);
    } catch (e) { _snack('Export failed: $e'); }
    finally { setState(() => _isExporting = false); }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  void _showExportSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(4)))),
          const SizedBox(height: 20),
          const Text('Export Transactions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _textDark)),
          const SizedBox(height: 4),
          Text('${_filtered.length} transactions will be exported', style: const TextStyle(fontSize: 13, color: _textLight)),
          const SizedBox(height: 18),
          _exportOption(icon: Icons.table_chart_rounded, color: const Color(0xFF1D6F42),
            label: 'Export as Excel (.xlsx)', sub: 'Open in Excel, Google Sheets, Numbers',
            onTap: () { Navigator.pop(context); _exportXlsx(); }),
          const SizedBox(height: 10),
          _exportOption(icon: Icons.picture_as_pdf_rounded, color: const Color(0xFFE53935),
            label: 'Export as PDF', sub: 'Formatted table, ready to print or share',
            onTap: () { Navigator.pop(context); _exportPdf(); }),
        ]),
      ),
    );
  }

  Widget _exportOption({required IconData icon, required Color color, required String label, required String sub, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: color.withOpacity(0.06), 
        borderRadius: BorderRadius.circular(14), 
        border: Border.all(color: color.withOpacity(0.2))),

        child: Row(children: [
          Container(width: 42, height: 42, 
          decoration: BoxDecoration(color: color, 
          borderRadius: BorderRadius.circular(12)), 
          child: Icon(icon, color: Colors.white, size: 20)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
            Text(sub, style: const TextStyle(fontSize: 12, color: _textLight)),
          ])),
          Icon(Icons.arrow_forward_ios_rounded, size: 13, color: color),
        ]),
      ),
    );
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Sort by', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _textDark)),
          const SizedBox(height: 14),
          ...['Newest', 'Oldest', 'Highest', 'Lowest'].map((opt) {
            final sel = _selectedSort == opt;
            return GestureDetector(
              onTap: () { setState(() => _selectedSort = opt); _applyFilters(); Navigator.pop(context); },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(color: sel ? _blue.withOpacity(0.07) : _bgGrey, borderRadius: BorderRadius.circular(12), border: Border.all(color: sel ? _blue : Colors.transparent)),
                child: Row(children: [
                  Expanded(child: Text(opt, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: sel ? _blue : _textDark))),
                  if (sel) const Icon(Icons.check_rounded, color: _blue, size: 18),
                ]),
              ),
            );
          }),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _grouped;
    final keys = grouped.keys.toList();

    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTxSheet,
        backgroundColor: const Color(0xFF217BFF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
      ),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.only(left: 16),
            width: 38, height: 38,
            decoration: BoxDecoration(color: _bgGrey, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: _textDark),
          ),
        ),
        title: const Text('Transactions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _textDark)),
        actions: [
          _isExporting
              ? const Padding(padding: EdgeInsets.only(right: 16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _blue)))
              : GestureDetector(
                  onTap: _showExportSheet,
                  child: Container(
                    margin: const EdgeInsets.only(right: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(color: _blue, borderRadius: BorderRadius.circular(10)),
                    child: const Row(children: [
                      Icon(Icons.download_rounded, size: 15, color: Colors.white),
                      SizedBox(width: 5),
                      Text('Export', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                    ]),
                  ),
                ),
        ],
      ),
      body: Column(children: [
        // Summary bar
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: _bgGrey, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            _stat('Transactions', '${_filtered.length}', _textMid),
            Container(width: 1, height: 28, color: _border),
            _stat('Spent', '\$${_totalDebit.toStringAsFixed(0)}', Colors.red.shade600),
            Container(width: 1, height: 28, color: _border),
            _stat('Received', '\$${_totalCredit.toStringAsFixed(0)}', _blue),
          ]),
        ),

        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (_) => _applyFilters(),
            decoration: InputDecoration(
              hintText: 'Search transactions…',
              hintStyle: const TextStyle(color: _textLight, fontSize: 14),
              filled: true, fillColor: _bgGrey,
              prefixIcon: const Icon(Icons.search_rounded, color: _textLight, size: 20),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? GestureDetector(onTap: () { _searchCtrl.clear(); _applyFilters(); }, child: const Icon(Icons.close_rounded, color: _textLight, size: 18))
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            ),
          ),
        ),

        // Filter + Sort chips
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Row(children: [
            ...([('All', Icons.list_rounded), ('Debit', Icons.arrow_upward_rounded), ('Credit', Icons.arrow_downward_rounded)].map((f) {
              final active = _selectedFilter == f.$1;
              return GestureDetector(
                onTap: () { setState(() => _selectedFilter = f.$1); _applyFilters(); },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: active ? _blue : _bgGrey, borderRadius: BorderRadius.circular(20), border: Border.all(color: active ? _blue : _border)),
                  child: Row(children: [
                    Icon(f.$2, size: 13, color: active ? Colors.white : _textMid),
                    const SizedBox(width: 4),
                    Text(f.$1, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: active ? Colors.white : _textMid)),
                  ]),
                ),
              );
            })),
            const Spacer(),
            GestureDetector(
              onTap: _showSortSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: _bgGrey, borderRadius: BorderRadius.circular(20), border: Border.all(color: _border)),
                child: Row(children: [
                  const Icon(Icons.sort_rounded, size: 14, color: _textMid),
                  const SizedBox(width: 4),
                  Text(_selectedSort, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _textMid)),
                ]),
              ),
            ),
          ]),
        ),

        const SizedBox(height: 12),
        const Divider(height: 1, color: Color(0xFFF0F2F5)),

        // List
        Expanded(
          child: _filtered.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(width: 64, height: 64, decoration: BoxDecoration(color: _bgGrey, borderRadius: BorderRadius.circular(20)), child: const Icon(Icons.receipt_long_rounded, color: _textLight, size: 30)),
                  const SizedBox(height: 16),
                  const Text('No transactions found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _textDark)),
                  const SizedBox(height: 6),
                  const Text('Try adjusting your filters', style: TextStyle(fontSize: 13, color: _textLight)),
                ]))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: keys.length,
                  itemBuilder: (_, i) {
                    final key = keys[i];
                    final txs = grouped[key]!;
                    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8, top: 4),
                        child: Text(key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _textLight, letterSpacing: 0.5)),
                      ),
                      ...txs.map((tx) => _TxTile(
                        tx: tx,
                        shortDate: _shortDate(tx.date),
                        categorizedIn: _categorizedMap[tx.transactionId],
                        onCategorize: () => _showCategorizeSheet(tx),
                      )),
                      const SizedBox(height: 8),
                    ]);
                  },
                ),
        ),
      ]),
    );
  }

  Widget _stat(String label, String value, Color color) => Expanded(child: Column(children: [
    Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
    const SizedBox(height: 2),
    Text(label, style: const TextStyle(fontSize: 11, color: _textLight)),
  ]));
}

class _TxTile extends StatelessWidget {
  final PlaidTransaction tx;
  final String shortDate;
  final String? categorizedIn;
  final VoidCallback onCategorize;

  const _TxTile({
    required this.tx,
    required this.shortDate,
    required this.categorizedIn,
    required this.onCategorize,
  });

  Color get _accent => tx.isDebit ? const Color(0xFFE53935) : const Color(0xFF1E88E5);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tx.isDebit ? const Color(0xFFFFF5F5) : const Color(0xFFF5FAFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tx.isDebit ? const Color(0xFFFFD2D2) : const Color(0xFFD7E8FF), width: 1.2),
      ),
      child: Row(children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(shape: BoxShape.circle, color: _accent.withOpacity(0.15)),
          alignment: Alignment.center,
          child: Text(tx.name.length >= 2 ? tx.name.substring(0, 2).toUpperCase() : tx.name.toUpperCase(),
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: _accent)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tx.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _accent)),
          const SizedBox(height: 3),
          if (tx.isDebit || tx.category != 'Uncategorized')
            Text(
              tx.isDebit && categorizedIn != null && tx.category == 'Uncategorized'
                  ? 'Categorized in $categorizedIn'
                  : tx.category,
              style: TextStyle(fontSize: 12, color: _accent.withOpacity(0.7), fontWeight: FontWeight.w500),
            ),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${tx.isDebit ? '-' : '+'}\$${tx.amount.toStringAsFixed(2)}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _accent)),
          const SizedBox(height: 4),
          if (tx.isDebit)
            tx.source != 'plaid'
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: tx.source == 'ocr' ? const Color(0xFFF0FDF4) : const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: tx.source == 'ocr' ? const Color(0xFFBBF7D0) : const Color(0xFFFED7AA)),
                    ),
                    child: Text(
                      tx.source == 'ocr' ? 'Receipt' : 'Manual',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: tx.source == 'ocr' ? const Color(0xFF15803D) : const Color(0xFFEA580C),
                      ),
                    ),
                  )
                : categorizedIn != null
                    ? Text('Categorized', style: TextStyle(fontSize: 12, fontFamily: 'Manrope', fontWeight: FontWeight.w500, color: _accent))
                    : GestureDetector(
                        onTap: onCategorize,
                        child: const Text(
                          'Categorize +',
                          style: TextStyle(fontSize: 12, fontFamily: 'Manrope', fontWeight: FontWeight.w600, color: Color(0xFF667085)),
                        ),
                      ),
          const SizedBox(height: 4),
          Text(shortDate, style: const TextStyle(fontSize: 11, color: Color(0xFF98A2B3))),
        ]),
      ]),
    );
  }
}

// ─── Categorize Bottom Sheet ──────────────────────────────────────────────────

class CategorizationSheet extends StatefulWidget {
  final PlaidTransaction tx;
  final void Function(String transactionId, String categoryRefName) onSuccess;

  const CategorizationSheet({super.key, required this.tx, required this.onSuccess});

  @override
  State<CategorizationSheet> createState() => _CategorizationSheetState();
}

class _CategorizationSheetState extends State<CategorizationSheet> {
  static const _blue   = Color(0xFF1E88E5);
  static const _purple = Color(0xFF7C3AED);
  static const _textDark  = Color(0xFF1A1F36);
  static const _textLight = Color(0xFF98A2B3);
  static const _bgGrey    = Color(0xFFF5F7FA);
  static const _border    = Color(0xFFE2E8F0);

  int _step = 0;
  String? _type;
  List<Map<String, dynamic>> _items = [];
  String? _selectedId;
  String? _selectedName;
  bool _loading = false;
  bool _submitting = false;
  Uint8List? _proofImageBytes;
  final _imagePicker = ImagePicker();

  bool get _requiresVerification {
    if (_selectedId == null || _type != 'collaboration') return false;
    final item = _items.firstWhere((i) => i['id'] == _selectedId, orElse: () => {});
    return (item['requireVerification'] as bool?) ?? false;
  }

  Future<void> _pickImage() async {
    final XFile? file = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (mounted) setState(() => _proofImageBytes = bytes);
  }

  Future<String?> _uploadToCloudinary(Uint8List bytes) async {
    final uri = Uri.parse('https://api.cloudinary.com/v1_1/dzuc4aors/image/upload');
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = 'verification_unsigned'
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: 'verification.jpg'));
    final response = await request.send();
    if (response.statusCode == 200) {
      final data = jsonDecode(await response.stream.bytesToString());
      return data['secure_url'] as String?;
    }
    return null;
  }

  Future<void> _pickType(String type) async {
    setState(() { _type = type; _loading = true; _step = 1; _items = []; _selectedId = null; _proofImageBytes = null; });
    try {
      if (type == 'goal') {
        await _fetchGoals();
      } else {
        await _fetchDashboards();
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchGoals() async {
    final res = await ApiService.get('/api/goals/my-goals', context);
    if (res.statusCode == 200 && mounted) {
      final List data = jsonDecode(res.body);
      setState(() {
        _items = data.map<Map<String, dynamic>>((g) => {
          'id': g['_id'].toString(),
          'name': g['goalName']?.toString() ?? 'Goal',
          'sub': 'PKR ${(g['amount'] ?? 0)} target · ${g['goalType'] == 'savings' ? 'Savings' : 'Limit'}',
        }).toList();
      });
    }
  }

  Future<void> _fetchDashboards() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final email = prefs.getString('userEmail') ?? '';
    if (email.isEmpty) return;

    // ignore: use_build_context_synchronously
    final membersRes = await ApiService.get('/api/collab/dashboard-members?userId=$email', context);
    if (!mounted || membersRes.statusCode != 200) return;

    final List membersData = jsonDecode(membersRes.body);
    final ids = membersData.map((m) => m['dashboardId'].toString()).toList();
    if (ids.isEmpty) { setState(() => _items = []); return; }

    // ignore: use_build_context_synchronously
    final dashRes = await ApiService.post('/api/collab/dashboards-by-ids', {'ids': ids}, context);
    if (dashRes.statusCode == 200 && mounted) {
      final List data = jsonDecode(dashRes.body);
      setState(() {
        _items = data.map<Map<String, dynamic>>((d) => {
          'id': d['_id'].toString(),
          'name': d['name']?.toString() ?? 'Group',
          'sub': d['type']?.toString() ?? 'Shared Group',
          'requireVerification': (d['settings']?['requireVerification'] as bool?) ?? false,
        }).toList();
      });
    }
  }

  Future<void> _submit() async {
    if (_selectedId == null) return;
    if (_requiresVerification && _proofImageBytes == null) return;
    setState(() => _submitting = true);
    try {
      String? imageUrl;
      if (_requiresVerification && _proofImageBytes != null) {
        imageUrl = await _uploadToCloudinary(_proofImageBytes!);
        if (imageUrl == null) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image upload failed. Please try again.')),
          );
          setState(() => _submitting = false);
          return;
        }
      }

      final body = <String, dynamic>{
        'transactionId': widget.tx.transactionId,
        'categorizedTo': _type,
        'categoryRefId': _selectedId,
        'categoryRefName': _selectedName,
        'amount': widget.tx.amount,
        'transactionName': widget.tx.name,
        if (imageUrl != null) 'verificationImage': imageUrl,
      };

      // ignore: use_build_context_synchronously
      final res = await ApiService.post('/api/categorize', body, context);

      if (res.statusCode == 201 || res.statusCode == 409) {
        widget.onSuccess(widget.tx.transactionId, _selectedName ?? '');
        if (mounted) Navigator.pop(context);
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to categorize. Try again.')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(4)))),
          const SizedBox(height: 16),
          _step == 0 ? _buildTypeStep() : _buildPickStep(),
        ],
      ),
    );
  }

  Widget _buildTypeStep() {
    final accent = widget.tx.isDebit ? const Color(0xFFE53935) : _blue;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Categorize Transaction', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _textDark)),
      const SizedBox(height: 4),
      Text(
        '${widget.tx.name}  ·  ${widget.tx.isDebit ? '-' : '+'}\$${widget.tx.amount.toStringAsFixed(2)}',
        style: TextStyle(fontSize: 13, color: accent, fontWeight: FontWeight.w500),
      ),
      const SizedBox(height: 20),
      _typeCard(
        icon: Icons.savings_rounded,
        color: _blue,
        title: 'Budget Goal',
        sub: 'Apply to a spending limit or savings target',
        onTap: () => _pickType('goal'),
      ),
      const SizedBox(height: 10),
      _typeCard(
        icon: Icons.group_rounded,
        color: _purple,
        title: 'Collaboration Group',
        sub: 'Add as an entry in a shared group',
        onTap: () => _pickType('collaboration'),
      ),
    ]);
  }

  Widget _typeCard({required IconData icon, required Color color, required String title, required String sub, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color)),
            const SizedBox(height: 2),
            Text(sub, style: const TextStyle(fontSize: 12, color: _textLight)),
          ])),
          Icon(Icons.arrow_forward_ios_rounded, size: 13, color: color.withOpacity(0.6)),
        ]),
      ),
    );
  }

  Widget _buildPickStep() {
    final color = _type == 'goal' ? _blue : _purple;
    final title = _type == 'goal' ? 'Select Goal' : 'Select Group';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [
          GestureDetector(
            onTap: () => setState(() { _step = 0; _items = []; _selectedId = null; _proofImageBytes = null; }),
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: _bgGrey, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: _textDark),
            ),
          ),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _textDark)),
        ]),
        const SizedBox(height: 16),
        if (_loading)
          const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 28), child: CircularProgressIndicator(strokeWidth: 2)))
        else if (_items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(child: Text('No items found', style: TextStyle(color: _textLight, fontSize: 14))),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _items.length,
              itemBuilder: (_, i) {
                final item = _items[i];
                final sel = _selectedId == item['id'];
                return GestureDetector(
                  onTap: () => setState(() { _selectedId = item['id'] as String; _selectedName = item['name'] as String; _proofImageBytes = null; }),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: sel ? color.withOpacity(0.06) : _bgGrey,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: sel ? color : Colors.transparent, width: 1.5),
                    ),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(item['name'] as String, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: sel ? color : _textDark)),
                        const SizedBox(height: 2),
                        Text(item['sub'] as String, style: const TextStyle(fontSize: 12, color: _textLight)),
                      ])),
                      if (sel) Icon(Icons.check_circle_rounded, color: color, size: 20),
                    ]),
                  ),
                );
              },
            ),
          ),
        if (_selectedId != null && _requiresVerification) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _proofImageBytes != null ? _purple.withOpacity(0.05) : _bgGrey,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _proofImageBytes != null ? _purple : _border,
                  width: _proofImageBytes != null ? 1.5 : 1,
                ),
              ),
              child: _proofImageBytes != null
                  ? Row(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(_proofImageBytes!, width: 48, height: 48, fit: BoxFit.cover),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Receipt attached', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _purple)),
                        const Text('Tap to change', style: TextStyle(fontSize: 12, color: _textLight)),
                      ])),
                      Icon(Icons.check_circle_rounded, color: _purple, size: 20),
                    ])
                  : Row(children: [
                      const Icon(Icons.receipt_long_rounded, color: _textLight, size: 20),
                      const SizedBox(width: 12),
                      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Attach proof of payment', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textDark)),
                        Text('This group requires a receipt or screenshot', style: TextStyle(fontSize: 12, color: _textLight)),
                      ])),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: _textLight),
                    ]),
            ),
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _selectedId == null || _submitting || (_requiresVerification && _proofImageBytes == null) ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              disabledBackgroundColor: color.withOpacity(0.35),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _submitting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Confirm', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ),
      ],
    );
  }
}

// ─── Add Transaction Sheet ────────────────────────────────────────────────────

class _AddTransactionSheet extends StatefulWidget {
  final VoidCallback onAdded;
  const _AddTransactionSheet({required this.onAdded});

  @override
  State<_AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<_AddTransactionSheet> {
  static const _blue      = Color(0xFF1E88E5);
  static const _green     = Color(0xFF16A34A);
  static const _textDark  = Color(0xFF1A1F36);
  static const _textLight = Color(0xFF98A2B3);
  static const _bgGrey    = Color(0xFFF5F7FA);
  static const _border    = Color(0xFFE2E8F0);

  static const _categories = [
    'Food & Drink', 'Shopping', 'Transport', 'Healthcare',
    'Entertainment', 'Utilities', 'Travel', 'Education', 'Other',
  ];

  // 0=choice, 1=manual form, 2=ocr source, 3=ocr loading, 4=ocr review
  int _step = 0;
  String _txSource = 'manual';

  final _nameCtrl   = TextEditingController();
  final _amountCtrl = TextEditingController();
  DateTime _date     = DateTime.now();
  String _category   = 'Other';
  bool _isDebit      = true;
  bool _saving       = false;
  String? _ocrError;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndScan(ImageSource source) async {
    setState(() { _step = 3; _ocrError = null; });
    try {
      final XFile? file = await ImagePicker().pickImage(
        source: source, maxWidth: 1024, maxHeight: 1024, imageQuality: 60,
      );
      if (!mounted) return;
      if (file == null) { setState(() => _step = 2); return; }

      final bytes = await file.readAsBytes();
      final b64 = base64Encode(bytes);

      // ignore: use_build_context_synchronously
      final res = await ApiService.post(
        '/api/manual-transactions/scan',
        {'imageBase64': b64, 'mimeType': 'image/jpeg'},
        context,
      );
      if (!mounted) return;

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        _nameCtrl.text   = data['name']?.toString() ?? '';
        _amountCtrl.text = (data['amount'] as num?)?.toStringAsFixed(2) ?? '';
        _category = _categories.contains(data['category']) ? data['category'] as String : 'Other';
        _isDebit  = (data['isDebit'] as bool?) ?? true;
        if (data['date'] != null) {
          try { _date = DateTime.parse(data['date'] as String); } catch (_) {}
        }
        _txSource = 'ocr';
      } else {
        _ocrError = 'Could not read receipt — please review and fill in the details.';
        _txSource = 'ocr';
      }
      setState(() => _step = 4);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ocrError = 'Scan failed — please fill in the details manually.';
        _txSource = 'ocr';
        _step = 4;
      });
    }
  }

  Future<void> _save() async {
    final name   = _nameCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (name.isEmpty || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid name and amount.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      // ignore: use_build_context_synchronously
      final res = await ApiService.post('/api/manual-transactions', {
        'name':     name,
        'amount':   amount,
        'date':     _date.toIso8601String().split('T').first,
        'category': _category,
        'isDebit':  _isDebit,
        'source':   _txSource,
      }, context);

      if (res.statusCode == 201 && mounted) {
        Navigator.pop(context);
        widget.onAdded();
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save. Please try again.')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: _blue)),
        child: child!,
      ),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(4)))),
          const SizedBox(height: 16),
          _buildStep(),
        ],
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0: return _buildChoiceStep();
      case 1: return _buildFormStep(isOcr: false);
      case 2: return _buildOcrSourceStep();
      case 3: return _buildLoadingStep();
      case 4: return _buildFormStep(isOcr: true);
      default: return _buildChoiceStep();
    }
  }

  Widget _buildChoiceStep() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Add Transaction', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _textDark)),
      const SizedBox(height: 4),
      const Text('Choose how you want to add it', style: TextStyle(fontSize: 13, color: _textLight)),
      const SizedBox(height: 20),
      _choiceCard(
        icon: Icons.edit_note_rounded,
        color: _blue,
        title: 'Enter Manually',
        sub: 'Type in the transaction details',
        onTap: () => setState(() { _txSource = 'manual'; _step = 1; }),
      ),
      const SizedBox(height: 12),
      _choiceCard(
        icon: Icons.document_scanner_rounded,
        color: _green,
        title: 'Scan Receipt',
        sub: 'Use your camera or gallery to extract details',
        onTap: () => setState(() => _step = 2),
      ),
    ]);
  }

  Widget _buildOcrSourceStep() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _backRow('Scan Receipt'),
      const SizedBox(height: 4),
      const Padding(
        padding: EdgeInsets.only(left: 46),
        child: Text('Select your image source', style: TextStyle(fontSize: 13, color: _textLight)),
      ),
      const SizedBox(height: 20),
      _choiceCard(
        icon: Icons.camera_alt_rounded,
        color: const Color(0xFF7C3AED),
        title: 'Take a Photo',
        sub: 'Open camera to photograph the receipt',
        onTap: () => _pickAndScan(ImageSource.camera),
      ),
      const SizedBox(height: 12),
      _choiceCard(
        icon: Icons.photo_library_rounded,
        color: const Color(0xFF0F766E),
        title: 'Choose from Gallery',
        sub: 'Pick an existing receipt photo',
        onTap: () => _pickAndScan(ImageSource.gallery),
      ),
    ]);
  }

  Widget _buildLoadingStep() {
    return SizedBox(
      height: 180,
      child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const SizedBox(width: 44, height: 44, child: CircularProgressIndicator(strokeWidth: 3, color: _green)),
        const SizedBox(height: 20),
        const Text('Reading your receipt…', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _textDark)),
        const SizedBox(height: 6),
        const Text('This may take a few seconds', style: TextStyle(fontSize: 13, color: _textLight)),
      ])),
    );
  }

  Widget _buildFormStep({required bool isOcr}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        GestureDetector(
          onTap: () => setState(() => _step = isOcr ? 2 : 0),
          child: Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: _bgGrey, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: _textDark),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(isOcr ? 'Review & Save' : 'Add Transaction',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _textDark)),
          Text(isOcr ? 'Check the details and correct if needed' : 'Fill in the transaction details',
            style: const TextStyle(fontSize: 12, color: _textLight)),
        ])),
      ]),

      if (isOcr && _ocrError != null) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(children: [
            Icon(Icons.warning_amber_rounded, size: 18, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            Expanded(child: Text(_ocrError!, style: TextStyle(fontSize: 12, color: Colors.orange.shade800))),
          ]),
        ),
      ],

      const SizedBox(height: 16),

      // Expense / Income toggle
      Row(children: [
        Expanded(child: GestureDetector(
          onTap: () => setState(() => _isDebit = true),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: _isDebit ? const Color(0xFFFFF5F5) : _bgGrey,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _isDebit ? const Color(0xFFFFD2D2) : _border),
            ),
            child: Center(child: Text('Expense', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: _isDebit ? const Color(0xFFE53935) : _textLight))),
          ),
        )),
        const SizedBox(width: 10),
        Expanded(child: GestureDetector(
          onTap: () => setState(() => _isDebit = false),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: !_isDebit ? const Color(0xFFF5FAFF) : _bgGrey,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: !_isDebit ? const Color(0xFFD7E8FF) : _border),
            ),
            child: Center(child: Text('Income', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: !_isDebit ? _blue : _textLight))),
          ),
        )),
      ]),

      const SizedBox(height: 14),

      _fieldLabel('Description'),
      const SizedBox(height: 6),
      _textField(_nameCtrl, 'e.g. Grocery store, Netflix…'),

      const SizedBox(height: 12),

      _fieldLabel('Amount'),
      const SizedBox(height: 6),
      _textField(_amountCtrl, '0.00', isNumber: true, prefix: '\$'),

      const SizedBox(height: 12),

      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _fieldLabel('Date'),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(color: _bgGrey, borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
              child: Row(children: [
                const Icon(Icons.calendar_today_rounded, size: 15, color: _textLight),
                const SizedBox(width: 8),
                Text(DateFormat('MMM d, yyyy').format(_date),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _textDark)),
              ]),
            ),
          ),
        ])),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _fieldLabel('Category'),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(color: _bgGrey, borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
            child: DropdownButton<String>(
              value: _category,
              isExpanded: true,
              underline: const SizedBox(),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: _textLight),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _textDark),
              onChanged: (v) { if (v != null) setState(() => _category = v); },
              items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            ),
          ),
        ])),
      ]),

      const SizedBox(height: 20),

      SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: isOcr ? _green : _blue,
            disabledBackgroundColor: (isOcr ? _green : _blue).withOpacity(0.4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: _saving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(isOcr ? 'Save Receipt' : 'Save Transaction',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
      ),
    ]);
  }

  Widget _backRow(String title) {
    return Row(children: [
      GestureDetector(
        onTap: () => setState(() => _step = 0),
        child: Container(
          width: 34, height: 34,
          decoration: BoxDecoration(color: _bgGrey, borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: _textDark),
        ),
      ),
      const SizedBox(width: 12),
      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _textDark)),
    ]);
  }

  Widget _choiceCard({required IconData icon, required Color color, required String title, required String sub, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(children: [
          Container(width: 46, height: 46, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: Colors.white, size: 22)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color)),
            const SizedBox(height: 2),
            Text(sub, style: const TextStyle(fontSize: 12, color: _textLight)),
          ])),
          Icon(Icons.arrow_forward_ios_rounded, size: 13, color: color.withOpacity(0.6)),
        ]),
      ),
    );
  }

  Widget _fieldLabel(String label) =>
      Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textDark));

  Widget _textField(TextEditingController ctrl, String hint, {bool isNumber = false, String? prefix}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _textLight, fontSize: 14),
        prefixText: prefix,
        prefixStyle: const TextStyle(fontSize: 14, color: _textDark, fontWeight: FontWeight.w500),
        filled: true,
        fillColor: _bgGrey,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      ),
    );
  }
}