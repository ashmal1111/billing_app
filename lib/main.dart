import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'admin_income_dashboard.dart';
import 'app_storage.dart';
import 'invoice_templates.dart';
import 'login_dialog.dart';
import 'security_service.dart';
import 'supabase_service.dart';

void main() {
  runApp(const BillingApp());
}

class BillingApp extends StatefulWidget {
  const BillingApp({super.key});

  @override
  State<BillingApp> createState() => _BillingAppState();
}

class _BillingAppState extends State<BillingApp> {
  final AppStorage _storage = createAppStorage();
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final data = await _storage.readText('settings.json');
      if (data == null) return;
      final settings = json.decode(data);
      if (settings is Map && settings['darkMode'] != null && mounted) {
        setState(() {
          _isDarkMode = settings['darkMode'] == true;
        });
      }
    } catch (_) {
      // Ignore errors when loading theme on startup
    }
  }

  void _updateTheme(bool isDark) {
    setState(() {
      _isDarkMode = isDark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Billing App Pro',
      debugShowCheckedModeBanner: false,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.indigo, brightness: Brightness.dark),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
        ),
      ),
      home: BillingHomePage(
        isDarkMode: _isDarkMode,
        onThemeChanged: _updateTheme,
      ),
    );
  }
}

class BillingHomePage extends StatefulWidget {
  final bool? isDarkMode;
  final ValueChanged<bool>? onThemeChanged;

  const BillingHomePage({
    super.key,
    this.isDarkMode,
    this.onThemeChanged,
  });

  @override
  State<BillingHomePage> createState() => _BillingHomePageState();
}

class _BillingHomePageState extends State<BillingHomePage> {
  final AppStorage _storage = createAppStorage();
  Timer? _dueInvoiceTimer;
  late bool _isDarkMode;

  final TextEditingController _clientNameController = TextEditingController();
  final TextEditingController _clientEmailController = TextEditingController();
  final TextEditingController _clientPhoneController = TextEditingController();
  final TextEditingController _clientAddressController =
      TextEditingController();
  final TextEditingController _clientGstController = TextEditingController();

  List<Map<String, String>> _savedClients = [];

  String _emailError = '';
  String _phoneError = '';

  final TextEditingController _invoiceNumberController =
      TextEditingController();
  final TextEditingController _invoiceDateController = TextEditingController();
  final TextEditingController _dueDateController = TextEditingController();

  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _itemPriceController = TextEditingController();
  final TextEditingController _itemQtyController = TextEditingController();

  final TextEditingController _notesController = TextEditingController();

  final List<Map<String, dynamic>> _items = [];
  double _taxRate = 18.0;
  int _selectedIndex = 0;
  final String _currency = '₹';
  InvoiceTemplate _selectedTemplate = InvoiceTemplate.modern;
  String _selectedPaymentMethod = 'UPI';
  String _invoiceStatus = 'pending';

  double _discountPercent = 0.0;
  String _companyName = 'Your Business Name';
  String _companyAddress = '123 Business Street, City - 123456';
  String _companyPhone = '';
  String _companyEmail = 'contact@yourbusiness.com';
  String _companyWhatsApp = '';

  String _searchQuery = '';
  String _filterStatus = 'all';

  bool _isRecurring = false;
  final String _recurringType = 'monthly';
  DateTime? _recurringEndDate;

  final List<Map<String, dynamic>> _notifications = [];
  List<Map<String, dynamic>> _savedInvoices = [];

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.isDarkMode ?? false;
    _setDefaultDates();
    _setDefaultInvoiceNumber();
    _loadInitialData();
    _loadSavedClients();
    _loadSettings();
    SupabaseService.instance.init().then((_) {
      if (mounted) setState(() {});
    });

    _dueInvoiceTimer = Timer.periodic(const Duration(hours: 24), (timer) {
      _checkDueInvoices();
    });
  }

  @override
  void didUpdateWidget(covariant BillingHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isDarkMode != null && widget.isDarkMode != _isDarkMode) {
      _isDarkMode = widget.isDarkMode!;
    }
  }

  @override
  void dispose() {
    _dueInvoiceTimer?.cancel();
    _clientNameController.dispose();
    _clientEmailController.dispose();
    _clientPhoneController.dispose();
    _clientAddressController.dispose();
    _clientGstController.dispose();
    _invoiceNumberController.dispose();
    _invoiceDateController.dispose();
    _dueDateController.dispose();
    _itemNameController.dispose();
    _itemPriceController.dispose();
    _itemQtyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await _loadSavedInvoices();
    if (!mounted) return;
    _checkDueInvoices();
  }

  void _loadSettings() async {
    try {
      final data = await _storage.readText('settings.json');
      if (data == null) return;

      final settings = json.decode(data);
      if (!mounted) return;
      setState(() {
        _isDarkMode = settings['darkMode'] ?? false;
        _companyName = settings['companyName'] ?? _companyName;
        _companyAddress = settings['companyAddress'] ?? _companyAddress;
        _companyPhone = settings['companyPhone'] ?? _companyPhone;
        _companyEmail = settings['companyEmail'] ?? _companyEmail;
        _companyWhatsApp = settings['companyWhatsApp'] ?? _companyWhatsApp;
      });
      widget.onThemeChanged?.call(_isDarkMode);
    } catch (_) {
      // Ignore settings loading errors on initial read
    }
  }

  void _saveSettings() async {
    final settings = {
      'darkMode': _isDarkMode,
      'companyName': _companyName,
      'companyAddress': _companyAddress,
      'companyPhone': _companyPhone,
      'companyEmail': _companyEmail,
      'companyWhatsApp': _companyWhatsApp,
    };
    try {
      await _storage.writeText('settings.json', json.encode(settings));
    } catch (_) {
      // Ignore settings saving errors
    }
    widget.onThemeChanged?.call(_isDarkMode);
  }

  void _checkDueInvoices() {
    final now = DateTime.now();
    for (var invoice in _savedInvoices) {
      if (invoice['status'] == 'pending') {
        try {
          final dueDate = DateFormat('dd/MM/yyyy').parse(invoice['dueDate']);
          if (dueDate.isBefore(now)) {
            invoice['status'] = 'overdue';
            _addNotification(
              title: 'Invoice Overdue',
              message:
                  'Invoice ${invoice['invoiceNumber']} for ${invoice['clientName']} is overdue',
              type: 'warning',
            );
          }
        } catch (_) {
          // Ignore date parsing errors on corrupted invoice data
        }
      }
    }
    _saveInvoicesToStorage();
  }

  void _addNotification(
      {required String title, required String message, required String type}) {
    setState(() {
      _notifications.insert(0, {
        'title': title,
        'message': message,
        'type': type,
        'time': DateTime.now().toString(),
        'read': false,
      });
    });
    _saveNotifications();
  }

  void _saveNotifications() async {
    try {
      await _storage.writeText(
          'notifications.json', json.encode(_notifications));
    } catch (_) {
      // Ignore notification saving errors
    }
  }

  void _loadSavedClients() async {
    try {
      final data = await _storage.readText('clients.json');
      if (data == null) return;

      final clients = (json.decode(data) as List)
          .map((client) => Map<String, String>.from(client as Map))
          .toList();
      if (!mounted) return;
      setState(() {
        _savedClients = clients;
      });
    } catch (_) {
      // Ignore client loading errors
    }
  }

  void _saveCurrentClient() {
    if (_clientNameController.text.isEmpty) {
      _showSnackBar('Please enter client name first', Colors.orange);
      return;
    }

    setState(() {
      _savedClients.add({
        'name': _clientNameController.text,
        'email': _clientEmailController.text,
        'phone': _clientPhoneController.text,
        'address': _clientAddressController.text,
        'gst': _clientGstController.text,
      });
    });

    _saveClientsToStorage();
    _showSnackBar('Client saved for quick access', Colors.green);
  }

  void _saveClientsToStorage() async {
    try {
      await _storage.writeText('clients.json', json.encode(_savedClients));
    } catch (_) {
      // Ignore client saving errors
    }
  }

  void _selectSavedClient(Map<String, String> client) {
    setState(() {
      _clientNameController.text = client['name'] ?? '';
      _clientEmailController.text = client['email'] ?? '';
      _clientPhoneController.text = client['phone'] ?? '';
      _clientAddressController.text = client['address'] ?? '';
      _clientGstController.text = client['gst'] ?? '';
    });
  }

  void _setDefaultDates() {
    final now = DateTime.now();
    _invoiceDateController.text = DateFormat('dd/MM/yyyy').format(now);
    final dueDate = DateTime(now.year, now.month, now.day + 7);
    _dueDateController.text = DateFormat('dd/MM/yyyy').format(dueDate);
  }

  void _setDefaultInvoiceNumber() {
    final now = DateTime.now();
    _invoiceNumberController.text =
        "INV-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.hour}${now.minute}${now.second}";
  }

  bool _isValidEmail(String email) {
    if (email.isEmpty) return true;
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  bool _isValidPhone(String phone) {
    if (phone.isEmpty) return true;
    final phoneRegex = RegExp(r'^[0-9]{10}$');
    return phoneRegex.hasMatch(phone);
  }

  void _validateEmail(String email) {
    setState(() {
      if (email.isNotEmpty && !_isValidEmail(email)) {
        _emailError = 'Enter a valid email address';
      } else {
        _emailError = '';
      }
    });
  }

  void _validatePhone(String phone) {
    setState(() {
      if (phone.isNotEmpty && !_isValidPhone(phone)) {
        _phoneError = 'Enter a valid 10-digit phone number';
      } else {
        _phoneError = '';
      }
    });
  }

  double get _subtotal {
    double total = 0;
    for (var item in _items) {
      total += (item['price'] * item['quantity']);
    }
    return total;
  }

  double get _taxAmount {
    return _subtotal * (_taxRate / 100);
  }

  double get _discountAmount {
    return _subtotal * (_discountPercent / 100);
  }

  double get _total {
    double total = _subtotal + _taxAmount - _discountAmount;
    return total > 0 ? total : 0;
  }

  void _addItem() {
    final itemName = _itemNameController.text.trim();
    if (itemName.isEmpty) {
      _showSnackBar('Please enter item name', Colors.orange);
      return;
    }
    final price = double.tryParse(_itemPriceController.text.trim());
    if (price == null || price < 0) {
      _showSnackBar('Please enter a valid price', Colors.orange);
      return;
    }
    final qty = int.tryParse(_itemQtyController.text.trim()) ?? 1;
    if (qty <= 0) {
      _showSnackBar('Quantity must be at least 1', Colors.orange);
      return;
    }

    setState(() {
      _items.add({
        'name': itemName,
        'price': price,
        'quantity': qty,
      });
      _itemNameController.clear();
      _itemPriceController.clear();
      _itemQtyController.clear();
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  void _resetForm() {
    setState(() {
      _clientNameController.clear();
      _clientEmailController.clear();
      _clientPhoneController.clear();
      _clientAddressController.clear();
      _clientGstController.clear();
      _items.clear();
      _notesController.clear();
      _discountPercent = 0.0;
      _emailError = '';
      _phoneError = '';
      _invoiceStatus = 'pending';
      _isRecurring = false;
    });
    _setDefaultInvoiceNumber();
    _showSnackBar('Form cleared', Colors.blue);
  }

  Future<void> _saveInvoiceToStorage() async {
    final clientName = SecurityValidator.sanitizeText(
        _clientNameController.text,
        maxLength: 100);
    if (clientName.isEmpty) {
      _showSnackBar('Please enter client name', Colors.red);
      return;
    }

    final email = _clientEmailController.text.trim();
    if (email.isNotEmpty && !SecurityValidator.isValidEmail(email)) {
      _showSnackBar('Please enter a valid email address (e.g. name@domain.com)',
          Colors.red);
      return;
    }

    final gst = _clientGstController.text.trim();
    if (gst.isNotEmpty && !SecurityValidator.isValidGst(gst)) {
      _showSnackBar(
          'Please enter a valid 15-character GSTIN or leave blank', Colors.red);
      return;
    }

    if (_items.isEmpty) {
      _showSnackBar('Please add at least one item', Colors.red);
      return;
    }

    final rawInvoice = {
      'invoiceNumber': _invoiceNumberController.text,
      'clientName': clientName,
      'clientEmail': email,
      'clientPhone': _clientPhoneController.text,
      'clientAddress': _clientAddressController.text,
      'clientGst': gst,
      'date': _invoiceDateController.text,
      'dueDate': _dueDateController.text,
      'items': _items,
      'subtotal': _subtotal,
      'taxRate': _taxRate,
      'taxAmount': _taxAmount,
      'discountPercent': _discountPercent,
      'discountAmount': _discountAmount,
      'total': _total,
      'template': _selectedTemplate.id,
      'notes': _notesController.text,
      'paymentMethod': _selectedPaymentMethod,
      'status': _invoiceStatus,
      'isRecurring': _isRecurring,
      'recurringType': _recurringType,
      'recurringEndDate': _recurringEndDate?.toIso8601String(),
      'savedAt': DateTime.now().toIso8601String(),
    };

    final invoice = SecurityValidator.sanitizeInvoice(rawInvoice);

    setState(() {
      _savedInvoices.insert(0, invoice);
    });

    await _saveInvoicesToStorage();
    SupabaseService.instance.syncInvoiceToCloud(invoice);

    _addNotification(
      title: 'Invoice Created',
      message:
          'Invoice ${invoice['invoiceNumber']} created for ${invoice['clientName']}',
      type: 'success',
    );

    _showSnackBar('Invoice saved securely!', Colors.green);
  }

  Future<void> _saveInvoicesToStorage() async {
    try {
      await _storage.writeText('invoices.json', json.encode(_savedInvoices));
    } catch (_) {
      // Ignore invoice saving errors
    }
  }

  Future<void> _loadSavedInvoices() async {
    try {
      final data = await _storage.readText('invoices.json');
      if (data == null) return;

      final invoices = (json.decode(data) as List)
          .map((invoice) => Map<String, dynamic>.from(invoice as Map))
          .toList();
      if (!mounted) return;
      setState(() {
        _savedInvoices = invoices;
      });
    } catch (_) {
      // Ignore invoice loading errors
    }
  }

  List<Map<String, dynamic>> get _filteredInvoices {
    var filtered = _savedInvoices;

    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((inv) =>
              inv['clientName']
                  .toString()
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ||
              inv['invoiceNumber']
                  .toString()
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()))
          .toList();
    }

    if (_filterStatus != 'all') {
      filtered =
          filtered.where((inv) => inv['status'] == _filterStatus).toList();
    }

    return filtered;
  }

  double get _totalRevenue {
    return _savedInvoices.fold(0.0, (sum, inv) {
      return sum + ((inv['total'] as num?)?.toDouble() ?? 0.0);
    });
  }

  int get _paidInvoicesCount {
    return _savedInvoices.where((inv) => inv['status'] == 'paid').length;
  }

  int get _pendingInvoicesCount {
    return _savedInvoices.where((inv) => inv['status'] == 'pending').length;
  }

  int get _overdueInvoicesCount {
    return _savedInvoices.where((inv) => inv['status'] == 'overdue').length;
  }

  Future<void> _exportToCSV() async {
    if (_savedInvoices.isEmpty) {
      _showSnackBar('No invoices to export', Colors.orange);
      return;
    }

    String csv =
        'Invoice #,Client Name,Date,Due Date,Subtotal,Tax,Total,Status,Payment Method\n';
    for (var inv in _savedInvoices) {
      csv +=
          '"${inv['invoiceNumber']}","${inv['clientName']}","${inv['date']}","${inv['dueDate']}",${inv['subtotal']},${inv['taxAmount']},${inv['total']},"${inv['status']}","${inv['paymentMethod']}"\n';
    }

    try {
      final fileName =
          'invoices_export_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      final export = await _storage.exportText(
        fileName,
        csv,
        mimeType: 'text/csv;charset=utf-8',
      );

      if (mounted) {
        _showExportDialog('Export Successful', export);
      }
    } catch (e) {
      _showSnackBar('Error exporting: $e', Colors.red);
    }
  }

  Future<void> _exportToJSON() async {
    if (_savedInvoices.isEmpty) {
      _showSnackBar('No invoices to export', Colors.orange);
      return;
    }

    try {
      final fileName =
          'invoices_backup_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.json';
      final export = await _storage.exportText(
        fileName,
        json.encode(_savedInvoices),
        mimeType: 'application/json;charset=utf-8',
      );

      if (mounted) {
        _showExportDialog('Backup Created', export);
      }
    } catch (e) {
      _showSnackBar('Error backing up: $e', Colors.red);
    }
  }

  void _showExportDialog(String title, ExportResult export) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('File saved: ${export.fileName}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Location:\n${export.location}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy Path'),
            onPressed: () {
              Clipboard.setData(
                  ClipboardData(text: export.sharePath ?? export.location));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('File path copied to clipboard!'),
                    backgroundColor: Colors.indigo),
              );
            },
          ),
          if (export.canShareFile && export.sharePath != null)
            TextButton.icon(
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Open / Share'),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await Share.shareXFiles([XFile(export.sharePath!)]);
                } catch (_) {
                  try {
                    final fileUri = Uri.file(export.sharePath!);
                    await launchUrl(fileUri);
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('File ready at: ${export.sharePath}'),
                        backgroundColor: Colors.indigo,
                      ),
                    );
                  }
                }
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              },
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _shareInvoice(Map<String, dynamic> invoice) async {
    final invoiceText = _generateInvoiceText(invoice);
    await Share.share(invoiceText,
        subject: 'Invoice ${invoice['invoiceNumber']}');
  }

  String _generateInvoiceText(Map<String, dynamic> invoice) {
    final buffer = StringBuffer();
    buffer.writeln('=' * 50);
    buffer.writeln('INVOICE: ${invoice['invoiceNumber']}');
    buffer.writeln('=' * 50);
    buffer.writeln('Date: ${invoice['date']}');
    if (invoice['dueDate'] != null &&
        invoice['dueDate'].toString().trim().isNotEmpty) {
      buffer.writeln('Due Date: ${invoice['dueDate']}');
    }
    buffer.writeln('Company: $_companyName');
    if (_companyWhatsApp.isNotEmpty) {
      buffer.writeln('WhatsApp / Helpline: +91 $_companyWhatsApp');
    }
    buffer.writeln('Client: ${invoice['clientName']}');
    if (invoice['clientPhone'] != null &&
        invoice['clientPhone'].toString().trim().isNotEmpty) {
      buffer.writeln('Client Phone: ${invoice['clientPhone']}');
    }
    buffer.writeln('-' * 50);
    buffer.writeln('ITEMS:');
    final items = (invoice['items'] as List?) ?? [];
    for (var item in items) {
      final name = item['name'] ?? 'Item';
      final num price = item['price'] is num
          ? (item['price'] as num)
          : (num.tryParse(item['price']?.toString() ?? '') ?? 0);
      final num qty = item['quantity'] is num
          ? (item['quantity'] as num)
          : (num.tryParse(item['quantity']?.toString() ?? '') ?? 1);
      final total = price * qty;
      buffer.writeln('• $name (x$qty) — $_currency${total.toStringAsFixed(2)}');
    }
    buffer.writeln('-' * 50);
    if (invoice['subtotal'] != null) {
      buffer.writeln('Subtotal: $_currency${invoice['subtotal']}');
    }
    if (invoice['taxAmount'] != null) {
      buffer.writeln('Tax: $_currency${invoice['taxAmount']}');
    }
    buffer.writeln('TOTAL AMOUNT: $_currency${invoice['total']}');
    buffer.writeln('Payment Method: ${invoice['paymentMethod'] ?? "UPI"}');
    buffer.writeln(
        'Status: ${(invoice['status'] ?? "pending").toString().toUpperCase()}');
    buffer.writeln('=' * 50);
    if (_companyWhatsApp.isNotEmpty) {
      buffer.writeln('Download & Inquiries on WhatsApp:');
      buffer.writeln(
          'https://wa.me/91$_companyWhatsApp?text=Download%20Invoice%20${invoice['invoiceNumber']}');
      buffer.writeln('=' * 50);
    }
    return buffer.toString();
  }

  Future<void> _downloadInvoice(Map<String, dynamic> invoice) async {
    final invoiceNumber = invoice['invoiceNumber'] ?? 'INV-001';
    final safeFileName = 'Invoice_$invoiceNumber.txt';
    final content = _generateInvoiceText(invoice);

    try {
      final export = await _storage.exportText(
        safeFileName,
        content,
        mimeType: 'text/plain',
      );
      if (mounted) {
        _showExportDialog('Invoice Downloaded', export);
      }
    } catch (e) {
      _showSnackBar('Download error: $e', Colors.red);
    }
  }

  String _formatWhatsAppInvoice(Map<String, dynamic> invoice) {
    final buffer = StringBuffer();
    buffer.writeln('🧾 *INVOICE: ${invoice['invoiceNumber']}*');
    buffer.writeln('📅 *Date:* ${invoice['date']}');
    if (invoice['dueDate'] != null &&
        invoice['dueDate'].toString().trim().isNotEmpty) {
      buffer.writeln('⏰ *Due Date:* ${invoice['dueDate']}');
    }
    buffer.writeln('🏢 *Billed From:* $_companyName');
    buffer.writeln('📲 *WhatsApp Helpline:* +91 $_companyWhatsApp');
    buffer.writeln('👤 *Billed To:* ${invoice['clientName']}');
    buffer.writeln('--------------------------------');
    buffer.writeln('*Items:*');
    final items = (invoice['items'] as List?) ?? [];
    for (var item in items) {
      final name = item['name'] ?? 'Item';
      final num price = item['price'] is num
          ? (item['price'] as num)
          : (num.tryParse(item['price']?.toString() ?? '') ?? 0);
      final num qty = item['quantity'] is num
          ? (item['quantity'] as num)
          : (num.tryParse(item['quantity']?.toString() ?? '') ?? 1);
      final total = price * qty;
      buffer.writeln('• $name (x$qty) — $_currency${total.toStringAsFixed(2)}');
    }
    buffer.writeln('--------------------------------');
    if (invoice['subtotal'] != null) {
      buffer.writeln('Subtotal: $_currency${invoice['subtotal']}');
    }
    final taxAmount = invoice['taxAmount'] is num
        ? (invoice['taxAmount'] as num)
        : (num.tryParse(invoice['taxAmount']?.toString() ?? '') ?? 0);
    if (taxAmount > 0) {
      buffer.writeln('Tax: $_currency$taxAmount');
    }
    buffer.writeln('💰 *Total Amount:* $_currency${invoice['total']}');
    if (invoice['paymentMethod'] != null) {
      buffer.writeln('💳 *Payment Method:* ${invoice['paymentMethod']}');
    }
    buffer.writeln(
        '📌 *Status:* ${(invoice['status'] ?? 'pending').toString().toUpperCase()}');
    if (invoice['notes'] != null &&
        invoice['notes'].toString().trim().isNotEmpty) {
      buffer.writeln('\n💬 *Note:* ${invoice['notes']}');
    }
    if (_companyWhatsApp.isNotEmpty) {
      buffer.writeln('\n📥 *Download Invoice / Bill:*');
      buffer.writeln(
          'https://wa.me/91$_companyWhatsApp?text=Hi%2C%20I%20want%20to%20download%20invoice%20${invoice['invoiceNumber']}');
    }
    buffer.writeln('\nThank you for your business! 🙏');
    return buffer.toString();
  }

  String _formatWhatsAppReminder(Map<String, dynamic> invoice) {
    final buffer = StringBuffer();
    buffer.writeln('⚠️ *PAYMENT REMINDER*');
    buffer.writeln('Hello ${invoice['clientName']},');
    buffer.writeln(
        'This is a gentle reminder regarding payment for invoice *#${invoice['invoiceNumber']}* for *$_currency${invoice['total']}*.');
    if (invoice['dueDate'] != null &&
        invoice['dueDate'].toString().trim().isNotEmpty) {
      buffer.writeln('📅 *Due Date:* ${invoice['dueDate']}');
    }
    buffer.writeln(
        'Status: *${(invoice['status'] ?? 'pending').toString().toUpperCase()}*');
    buffer.writeln('\nPlease arrange payment at your earliest convenience.');
    if (_companyWhatsApp.isNotEmpty) {
      buffer.writeln('\nDownload & Support on WhatsApp: +91 $_companyWhatsApp');
      buffer.writeln(
          'https://wa.me/91$_companyWhatsApp?text=Payment%20Invoice%20${invoice['invoiceNumber']}');
    }
    buffer.writeln('\nThank you,\n*$_companyName*');
    return buffer.toString();
  }

  Future<void> _launchWhatsApp({
    required String rawPhone,
    required String message,
  }) async {
    String cleanDigits = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanDigits.length == 10) {
      cleanDigits = '91$cleanDigits';
    }

    if (cleanDigits.isNotEmpty &&
        (cleanDigits.length < 7 || cleanDigits.length > 15)) {
      _showSnackBar('Invalid phone number for WhatsApp (expected 7-15 digits)',
          Colors.red);
      return;
    }

    final encodedMessage = Uri.encodeComponent(message);
    final Uri url;
    if (cleanDigits.isNotEmpty) {
      url = Uri.parse('https://wa.me/$cleanDigits?text=$encodedMessage');
    } else {
      url = Uri.parse('https://wa.me/?text=$encodedMessage');
    }

    try {
      final launched =
          await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!launched) {
        _showSnackBar('Could not launch WhatsApp', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error opening WhatsApp: $e', Colors.red);
    }
  }

  void _shareViaWhatsApp({
    required String phone,
    required String message,
    Map<String, dynamic>? invoice,
  }) {
    if (phone.trim().isEmpty) {
      _showWhatsAppPhoneDialog(message, invoice);
    } else {
      _launchWhatsApp(rawPhone: phone, message: message);
    }
  }

  void _showWhatsAppPhoneDialog(String message,
      [Map<String, dynamic>? invoice]) {
    final phoneCtrl = TextEditingController(
      text: invoice?['clientPhone']?.toString() ?? '',
    );

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.chat, color: Color(0xFF25D366)),
            SizedBox(width: 8),
            Text('WhatsApp & Download'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_companyWhatsApp.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF25D366).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified,
                          color: Color(0xFF25D366), size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Business WhatsApp Connected',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            Text(
                              '+91 $_companyWhatsApp',
                              style: const TextStyle(
                                color: Color(0xFF075E54),
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Quick Actions:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.send),
                    label: Text('Send to WhatsApp (+91 $_companyWhatsApp)'),
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      _launchWhatsApp(
                          rawPhone: _companyWhatsApp, message: message);
                    },
                  ),
                ),
              ],
              if (invoice != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.teal,
                      side: const BorderSide(color: Colors.teal),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.file_download),
                    label: const Text('Download Invoice & Send'),
                    onPressed: () async {
                      Navigator.pop(dialogContext);
                      await _downloadInvoice(invoice);
                      _launchWhatsApp(
                          rawPhone: _companyWhatsApp, message: message);
                    },
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Divider(),
              const Text(
                'Or send to client number:',
                style: TextStyle(fontSize: 12, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  hintText: 'e.g. 9876543210',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _launchWhatsApp(rawPhone: '', message: message);
            },
            child: const Text('Open WhatsApp'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final val = phoneCtrl.text.trim();
              Navigator.pop(dialogContext);
              _launchWhatsApp(rawPhone: val, message: message);
            },
            child: const Text('Send to Client'),
          ),
        ],
      ),
    );
  }

  void _sendCurrentInvoiceViaWhatsApp() {
    final invoiceData = {
      'invoiceNumber': _invoiceNumberController.text.isEmpty
          ? 'INV-001'
          : _invoiceNumberController.text,
      'clientName': _clientNameController.text.isEmpty
          ? 'Valued Client'
          : _clientNameController.text,
      'clientPhone': _clientPhoneController.text,
      'date': _invoiceDateController.text,
      'dueDate': _dueDateController.text,
      'items': _items,
      'subtotal': _subtotal.toStringAsFixed(2),
      'taxAmount': _taxAmount.toStringAsFixed(2),
      'total': _total.toStringAsFixed(2),
      'paymentMethod': _selectedPaymentMethod,
      'status': _invoiceStatus,
      'notes': _notesController.text,
    };
    final msg = _formatWhatsAppInvoice(invoiceData);
    _showWhatsAppPhoneDialog(msg, invoiceData);
  }

  void _viewSavedInvoiceTemplate(Map<String, dynamic> invoice) {
    final template = InvoiceTemplate.fromId(invoice['template'] as String?);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          children: [
            AppBar(
              title: Text('${template.name} - ${invoice['invoiceNumber']}'),
              backgroundColor: template.accentColor,
              foregroundColor: Colors.white,
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: InvoiceTemplateView(
                  template: template,
                  invoiceNumber: (invoice['invoiceNumber'] ?? '').toString(),
                  date: (invoice['date'] ?? '').toString(),
                  dueDate: (invoice['dueDate'] ?? '').toString(),
                  clientName: (invoice['clientName'] ?? '').toString(),
                  clientEmail: (invoice['clientEmail'] ?? '').toString(),
                  clientPhone: (invoice['clientPhone'] ?? '').toString(),
                  clientAddress: (invoice['clientAddress'] ?? '').toString(),
                  clientGst: (invoice['clientGst'] ?? '').toString(),
                  companyName: _companyName,
                  companyAddress: _companyAddress,
                  companyPhone: _companyPhone,
                  companyEmail: _companyEmail,
                  items:
                      List<Map<String, dynamic>>.from(invoice['items'] ?? []),
                  subtotal: (invoice['subtotal'] as num?)?.toDouble() ?? 0.0,
                  taxRate: (invoice['taxRate'] as num?)?.toDouble() ?? 18.0,
                  taxAmount: (invoice['taxAmount'] as num?)?.toDouble() ?? 0.0,
                  discountPercent:
                      (invoice['discountPercent'] as num?)?.toDouble() ?? 0.0,
                  discountAmount:
                      (invoice['discountAmount'] as num?)?.toDouble() ?? 0.0,
                  total: (invoice['total'] as num?)?.toDouble() ?? 0.0,
                  currency: _currency,
                  status: (invoice['status'] ?? 'pending').toString(),
                  paymentMethod: (invoice['paymentMethod'] ?? 'UPI').toString(),
                  notes: (invoice['notes'] ?? '').toString(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendPaymentReminder(Map<String, dynamic> invoice) {
    _addNotification(
      title: 'Payment Reminder Sent',
      message:
          'Reminder sent to ${invoice['clientName']} for invoice ${invoice['invoiceNumber']}',
      type: 'info',
    );
    _showSnackBar('Payment reminder sent!', Colors.green);
  }

  void _markAsPaid(Map<String, dynamic> invoice, int index) {
    setState(() {
      _savedInvoices[index]['status'] = 'paid';
    });
    _saveInvoicesToStorage();
    _addNotification(
      title: 'Payment Received',
      message:
          'Payment received for invoice ${invoice['invoiceNumber']} from ${invoice['clientName']}',
      type: 'success',
    );
    _showSnackBar('Invoice marked as paid!', Colors.green);
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'paid':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'overdue':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildDashboard(),
          _buildInvoiceForm(),
          _buildInvoicePreview(),
          _buildSavedInvoices(),
          AdminIncomeDashboard(
            invoices: _savedInvoices,
            currency: _currency,
            onRefresh: () => setState(() {}),
          ),
          _buildNotifications(),
          _buildSettings(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, -5)),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.indigo,
          unselectedItemColor: Colors.grey,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Home'),
            BottomNavigationBarItem(
                icon: Icon(Icons.edit_note), label: 'Create'),
            BottomNavigationBarItem(
                icon: Icon(Icons.preview), label: 'Preview'),
            BottomNavigationBarItem(
                icon: Icon(Icons.history), label: 'History'),
            BottomNavigationBarItem(
                icon: Icon(Icons.query_stats), label: 'Income'),
            BottomNavigationBarItem(
                icon: Icon(Icons.notifications), label: 'Alerts'),
            BottomNavigationBarItem(
                icon: Icon(Icons.settings), label: 'Settings'),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    final session = SupabaseService.instance.currentSession;
    final isAdmin = SupabaseService.instance.isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ActionChip(
              avatar: Icon(
                isAdmin ? Icons.admin_panel_settings : Icons.person,
                size: 16,
                color: isAdmin ? Colors.amber : Colors.white70,
              ),
              label: Text(
                session?.role.displayName ?? 'Login',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor:
                  isAdmin ? Colors.indigo.shade900 : Colors.indigo.shade700,
              side: BorderSide(color: Colors.white.withAlpha(80)),
              onPressed: () => LoginDialog.show(
                context,
                onSessionChanged: () => setState(() {}),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(_isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () {
              setState(() => _isDarkMode = !_isDarkMode);
              _saveSettings();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
          await _loadSavedInvoices();
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(children: [
                Expanded(
                    child: _buildStatCard(
                        'Total Revenue',
                        '$_currency${_totalRevenue.toStringAsFixed(0)}',
                        Icons.currency_rupee,
                        Colors.green,
                        onTap: () => setState(() => _selectedIndex = 4))),
                const SizedBox(width: 12),
                Expanded(
                    child: _buildStatCard(
                        'Total Invoices',
                        _savedInvoices.length.toString(),
                        Icons.receipt,
                        Colors.blue)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: _buildStatCard('Paid', _paidInvoicesCount.toString(),
                        Icons.check_circle, Colors.green)),
                const SizedBox(width: 12),
                Expanded(
                    child: _buildStatCard(
                        'Pending',
                        _pendingInvoicesCount.toString(),
                        Icons.pending,
                        Colors.orange)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: _buildStatCard(
                        'Overdue',
                        _overdueInvoicesCount.toString(),
                        Icons.warning,
                        Colors.red)),
                const SizedBox(width: 12),
                Expanded(
                    child: _buildStatCard(
                        'Alerts',
                        _notifications
                            .where((n) => n['read'] == false)
                            .length
                            .toString(),
                        Icons.notifications,
                        Colors.purple)),
              ]),
              const SizedBox(height: 24),
              const Text('Quick Actions',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: _buildActionButton(
                        'New Invoice', Icons.add, Colors.indigo, () {
                  setState(() {
                    _resetForm();
                    _selectedIndex = 1;
                  });
                })),
                const SizedBox(width: 12),
                Expanded(
                    child: _buildActionButton('Export CSV', Icons.download,
                        Colors.green, _exportToCSV)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: _buildActionButton(
                        'Backup', Icons.backup, Colors.orange, _exportToJSON)),
                const SizedBox(width: 12),
                Expanded(
                    child: _buildActionButton('Saved Clients', Icons.people,
                        Colors.purple, _showSavedClientsDialog)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: _buildActionButton('Income Stats', Icons.query_stats,
                        Colors.teal, () => setState(() => _selectedIndex = 4))),
                const SizedBox(width: 12),
                Expanded(
                    child: _buildActionButton(
                        'User Session',
                        Icons.account_circle,
                        Colors.deepPurple,
                        () => LoginDialog.show(context,
                            onSessionChanged: () => setState(() {})))),
              ]),
              const SizedBox(height: 24),
              const Text('Recent Invoices',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (_savedInvoices.isEmpty)
                const Center(child: Text('No invoices yet'))
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount:
                      _savedInvoices.length > 5 ? 5 : _savedInvoices.length,
                  itemBuilder: (context, index) {
                    final inv = _savedInvoices[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                            backgroundColor: _getStatusColor(inv['status']),
                            child: Text('${index + 1}')),
                        title: Text(inv['invoiceNumber']),
                        subtitle: Text(inv['clientName']),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('$_currency${inv['total']}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                    color: _getStatusColor(inv['status']),
                                    borderRadius: BorderRadius.circular(12)),
                                child: Text(inv['status'],
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 10))),
                          ],
                        ),
                        onTap: () => _showInvoiceDetails(
                            inv, _savedInvoices.indexOf(inv)),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color,
      {VoidCallback? onTap}) {
    final content = Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 8),
          Text(value,
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Text(title,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          if (onTap != null) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Analytics',
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(Icons.arrow_forward_ios, size: 9, color: color),
              ],
            ),
          ],
        ],
      ),
    );

    return Card(
      elevation: 4,
      child: onTap != null
          ? InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: content,
            )
          : content,
    );
  }

  Widget _buildActionButton(
      String title, IconData icon, Color color, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(title),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSavedClientsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Saved Clients'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: _savedClients.isEmpty
              ? const Center(child: Text('No saved clients'))
              : ListView.builder(
                  itemCount: _savedClients.length,
                  itemBuilder: (context, index) {
                    final client = _savedClients[index];
                    return ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(client['name']!),
                      subtitle: Text(client['email'] ?? ''),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () {
                          Navigator.pop(context);
                          _selectSavedClient(client);
                          setState(() => _selectedIndex = 1);
                        },
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
        ],
      ),
    );
  }

  void _showInvoiceDetails(Map<String, dynamic> invoice, int index) {
    final template = InvoiceTemplate.fromId(invoice['template'] as String?);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Expanded(child: Text(invoice['invoiceNumber'] ?? 'Invoice')),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: template.accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: template.accentColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                template.name,
                style: TextStyle(
                  fontSize: 11,
                  color: template.accentColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Client: ${invoice['clientName']}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Date: ${invoice['date']}'),
              Text('Due: ${invoice['dueDate']}'),
              Text('Total: $_currency${invoice['total']}'),
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: _getStatusColor(invoice['status']),
                    borderRadius: BorderRadius.circular(12)),
                child: Text(invoice['status'],
                    style: const TextStyle(color: Colors.white)),
              ),
              const Divider(),
              const Text('Items:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              ...(invoice['items'] as List).map((item) => Padding(
                    padding: const EdgeInsets.only(left: 8, top: 4),
                    child: Text(
                        '• ${item['name']} x ${item['quantity']} = $_currency${item['price'] * item['quantity']}'),
                  )),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.palette_outlined, size: 16),
            label: const Text('View Design'),
            onPressed: () {
              Navigator.pop(context);
              _viewSavedInvoiceTemplate(invoice);
            },
          ),
          if (invoice['status'] == 'pending')
            TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _markAsPaid(invoice, index);
                },
                child: const Text('Mark Paid')),
          if (invoice['status'] == 'pending' || invoice['status'] == 'overdue')
            TextButton.icon(
              icon: const Icon(Icons.chat, color: Color(0xFFEA580C), size: 16),
              label: const Text('WA Reminder',
                  style: TextStyle(color: Color(0xFFEA580C))),
              onPressed: () {
                _sendPaymentReminder(invoice);
                final msg = _formatWhatsAppReminder(invoice);
                _shareViaWhatsApp(
                    phone: (invoice['clientPhone'] ?? '').toString(),
                    message: msg);
              },
            ),
          TextButton.icon(
            icon: const Icon(Icons.download, color: Colors.teal, size: 16),
            label: const Text('Download', style: TextStyle(color: Colors.teal)),
            onPressed: () {
              Navigator.pop(context);
              _downloadInvoice(invoice);
            },
          ),
          TextButton.icon(
            icon: const Icon(Icons.chat, color: Color(0xFF25D366), size: 16),
            label: const Text('WhatsApp',
                style: TextStyle(color: Color(0xFF25D366))),
            onPressed: () {
              Navigator.pop(context);
              final msg = _formatWhatsAppInvoice(invoice);
              _showWhatsAppPhoneDialog(msg, invoice);
            },
          ),
          TextButton(
              onPressed: () => _shareInvoice(invoice),
              child: const Text('Share')),
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _buildInvoiceForm() {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Create Invoice'),
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_savedClients.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Quick Select Client',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 50,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _savedClients.length,
                          itemBuilder: (context, index) {
                            final client = _savedClients[index];
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ActionChip(
                                  label: Text(client['name']!),
                                  onPressed: () => _selectSavedClient(client)),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            _buildSectionCard('Client Information', Icons.person, [
              TextField(
                controller: _clientNameController,
                decoration: const InputDecoration(
                  labelText: 'Client Name *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _clientEmailController,
                onChanged: _validateEmail,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.email_outlined),
                  errorText: _emailError.isNotEmpty ? _emailError : null,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _clientPhoneController,
                onChanged: _validatePhone,
                decoration: InputDecoration(
                  labelText: 'Phone',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.phone_outlined),
                  errorText: _phoneError.isNotEmpty ? _phoneError : null,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _clientAddressController,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _clientGstController,
                decoration: const InputDecoration(
                  labelText: 'GST Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.receipt_long_outlined),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: _saveCurrentClient,
                  icon: const Icon(Icons.person_add),
                  label: const Text('Save Client to Quick Access'),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            _buildSectionCard('Invoice Details', Icons.description, [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _invoiceDateController,
                      decoration: const InputDecoration(
                        labelText: 'Date (DD/MM/YYYY)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _dueDateController,
                      decoration: const InputDecoration(
                        labelText: 'Due Date (DD/MM/YYYY)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedPaymentMethod,
                      items: const [
                        DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                        DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                        DropdownMenuItem(value: 'Card', child: Text('Card')),
                        DropdownMenuItem(
                            value: 'Bank Transfer',
                            child: Text('Bank Transfer')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedPaymentMethod = value);
                        }
                      },
                      decoration: const InputDecoration(
                        labelText: 'Payment Method',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<double>(
                      initialValue: _taxRate,
                      items: const [
                        DropdownMenuItem(value: 0.0, child: Text('GST 0%')),
                        DropdownMenuItem(value: 5.0, child: Text('GST 5%')),
                        DropdownMenuItem(value: 12.0, child: Text('GST 12%')),
                        DropdownMenuItem(value: 18.0, child: Text('GST 18%')),
                        DropdownMenuItem(value: 28.0, child: Text('GST 28%')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _taxRate = value);
                        }
                      },
                      decoration: const InputDecoration(
                        labelText: 'Tax Rate',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes / Payment Terms',
                  border: OutlineInputBorder(),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            _buildSectionCard('Invoice Status', Icons.flag, [
              DropdownButtonFormField<String>(
                initialValue: _invoiceStatus,
                items: const [
                  DropdownMenuItem(value: 'pending', child: Text('Pending')),
                  DropdownMenuItem(value: 'paid', child: Text('Paid')),
                  DropdownMenuItem(value: 'overdue', child: Text('Overdue')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _invoiceStatus = value);
                  }
                },
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
            ]),
            const SizedBox(height: 16),
            _buildSectionCard('Add Items', Icons.shopping_cart, [
              Row(
                children: [
                  Expanded(
                      flex: 2,
                      child: TextField(
                          controller: _itemNameController,
                          decoration: const InputDecoration(
                              hintText: 'Item', border: OutlineInputBorder()))),
                  const SizedBox(width: 8),
                  Expanded(
                      child: TextField(
                          controller: _itemPriceController,
                          decoration: const InputDecoration(
                              hintText: 'Price',
                              border: OutlineInputBorder(),
                              prefixText: '₹'),
                          keyboardType: TextInputType.number)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: TextField(
                          controller: _itemQtyController,
                          decoration: const InputDecoration(
                              hintText: 'Qty', border: OutlineInputBorder()),
                          keyboardType: TextInputType.number)),
                  const SizedBox(width: 8),
                  IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.indigo),
                      onPressed: _addItem),
                ],
              ),
            ]),
            if (_items.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      const Text('Items',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return ListTile(
                            title: Text(item['name']),
                            subtitle: Text(
                                '₹${item['price']} x ${item['quantity']} = ₹${item['price'] * item['quantity']}'),
                            trailing: IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _removeItem(index)),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
          onPressed: () => setState(() => _selectedIndex = 2),
          child: const Icon(Icons.preview)),
    );
  }

  Widget _buildSectionCard(String title, IconData icon, List<Widget> children) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: Colors.indigo),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold))
            ]),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateSelector() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.style, size: 18, color: Colors.indigo),
              const SizedBox(width: 8),
              const Text(
                'Template:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _selectedTemplate.accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color:
                          _selectedTemplate.accentColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  _selectedTemplate.name,
                  style: TextStyle(
                    fontSize: 12,
                    color: _selectedTemplate.accentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: InvoiceTemplate.values.map((tmpl) {
                final isSelected = _selectedTemplate == tmpl;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    avatar: Icon(
                      tmpl.icon,
                      size: 16,
                      color: isSelected ? Colors.white : tmpl.accentColor,
                    ),
                    label: Text(tmpl.name),
                    selected: isSelected,
                    selectedColor: tmpl.accentColor,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : null,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedTemplate = tmpl);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoicePreview() {
    final invoiceData = {
      'invoiceNumber': _invoiceNumberController.text.isEmpty
          ? 'INV-001'
          : _invoiceNumberController.text,
      'clientName': _clientNameController.text.isEmpty
          ? 'Not specified'
          : _clientNameController.text,
      'clientEmail': _clientEmailController.text,
      'clientPhone': _clientPhoneController.text,
      'clientAddress': _clientAddressController.text,
      'clientGst': _clientGstController.text,
      'date': _invoiceDateController.text.isEmpty
          ? DateFormat('dd/MM/yyyy').format(DateTime.now())
          : _invoiceDateController.text,
      'dueDate': _dueDateController.text,
      'items': _items,
      'subtotal': _subtotal,
      'taxRate': _taxRate,
      'taxAmount': _taxAmount,
      'discountPercent': _discountPercent,
      'discountAmount': _discountAmount,
      'total': _total,
      'paymentMethod': _selectedPaymentMethod,
      'status': _invoiceStatus,
      'notes': _notesController.text,
      'template': _selectedTemplate.id,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Preview Invoice'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share invoice',
            onPressed: () => _shareInvoice(invoiceData),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTemplateSelector(),
            const SizedBox(height: 12),
            InvoiceTemplateView(
              template: _selectedTemplate,
              invoiceNumber: _invoiceNumberController.text.isEmpty
                  ? 'INV-001'
                  : _invoiceNumberController.text,
              date: _invoiceDateController.text.isEmpty
                  ? DateFormat('dd/MM/yyyy').format(DateTime.now())
                  : _invoiceDateController.text,
              dueDate: _dueDateController.text,
              clientName: _clientNameController.text.isEmpty
                  ? 'Client Name'
                  : _clientNameController.text,
              clientEmail: _clientEmailController.text,
              clientPhone: _clientPhoneController.text,
              clientAddress: _clientAddressController.text,
              clientGst: _clientGstController.text,
              companyName: _companyName,
              companyAddress: _companyAddress,
              companyPhone: _companyPhone,
              companyEmail: _companyEmail,
              items: _items,
              subtotal: _subtotal,
              taxRate: _taxRate,
              taxAmount: _taxAmount,
              discountPercent: _discountPercent,
              discountAmount: _discountAmount,
              total: _total,
              currency: _currency,
              status: _invoiceStatus,
              paymentMethod: _selectedPaymentMethod,
              notes: _notesController.text,
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => setState(() => _selectedIndex = 1),
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit'),
                ),
                ElevatedButton.icon(
                  onPressed: _saveInvoiceToStorage,
                  icon: const Icon(Icons.save),
                  label: const Text('Save'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _downloadInvoice(invoiceData),
                  icon: const Icon(Icons.download),
                  label: const Text('Download'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _sendCurrentInvoiceViaWhatsApp,
                  icon: const Icon(Icons.chat),
                  label: const Text('WhatsApp'),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedInvoices() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice History'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => _showSearchDialog()),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'csv') _exportToCSV();
              if (value == 'json') _exportToJSON();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'csv', child: Text('Export CSV')),
              PopupMenuItem(value: 'json', child: Text('Backup JSON')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                      label: const Text('All'),
                      selected: _filterStatus == 'all',
                      onSelected: (_) => setState(() => _filterStatus = 'all')),
                  const SizedBox(width: 8),
                  FilterChip(
                      label: const Text('Pending'),
                      selected: _filterStatus == 'pending',
                      onSelected: (_) =>
                          setState(() => _filterStatus = 'pending'),
                      backgroundColor: Colors.orange.shade100),
                  const SizedBox(width: 8),
                  FilterChip(
                      label: const Text('Paid'),
                      selected: _filterStatus == 'paid',
                      onSelected: (_) => setState(() => _filterStatus = 'paid'),
                      backgroundColor: Colors.green.shade100),
                  const SizedBox(width: 8),
                  FilterChip(
                      label: const Text('Overdue'),
                      selected: _filterStatus == 'overdue',
                      onSelected: (_) =>
                          setState(() => _filterStatus = 'overdue'),
                      backgroundColor: Colors.red.shade100),
                ],
              ),
            ),
          ),
          Expanded(
            child: _filteredInvoices.isEmpty
                ? const Center(child: Text('No invoices found'))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _filteredInvoices.length,
                    itemBuilder: (context, index) {
                      final inv = _filteredInvoices[index];
                      final originalIndex = _savedInvoices.indexOf(inv);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                              backgroundColor: _getStatusColor(inv['status']),
                              child: Text('${index + 1}')),
                          title: Text(inv['invoiceNumber'],
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(inv['clientName']),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('$_currency${inv['total']}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              Text(inv['date'],
                                  style: const TextStyle(fontSize: 10)),
                            ],
                          ),
                          onTap: () => _showInvoiceDetails(inv, originalIndex),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Invoices'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(
              hintText: 'Invoice number or client name',
              prefixIcon: Icon(Icons.search)),
          onChanged: (value) => setState(() => _searchQuery = value),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'))
        ],
      ),
    );
  }

  Widget _buildNotifications() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.mark_as_unread),
            onPressed: () {
              setState(() {
                for (final n in _notifications) {
                  n['read'] = true;
                }
              });
              _saveNotifications();
            },
          ),
        ],
      ),
      body: _notifications.isEmpty
          ? const Center(child: Text('No notifications'))
          : ListView.builder(
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                final notif = _notifications[index];
                return Card(
                  margin: const EdgeInsets.all(8),
                  color: notif['read'] == false ? Colors.indigo.shade50 : null,
                  child: ListTile(
                    leading: Icon(
                      notif['type'] == 'success'
                          ? Icons.check_circle
                          : notif['type'] == 'warning'
                              ? Icons.warning
                              : Icons.info,
                      color: notif['type'] == 'success'
                          ? Colors.green
                          : notif['type'] == 'warning'
                              ? Colors.orange
                              : Colors.blue,
                    ),
                    title: Text(notif['title']),
                    subtitle: Text(notif['message']),
                    trailing: Text(
                        DateFormat('dd/MM/yy')
                            .format(DateTime.parse(notif['time'])),
                        style: const TextStyle(fontSize: 10)),
                    onTap: () {
                      setState(() => notif['read'] = true);
                      _saveNotifications();
                    },
                  ),
                );
              },
            ),
    );
  }

  Widget _buildSettings() {
    final session = SupabaseService.instance.currentSession;
    final isConfigured = SupabaseService.instance.isConfigured;

    return Scaffold(
      appBar: AppBar(
          title: const Text('Settings'),
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: Icon(
              session?.isAdmin == true
                  ? Icons.admin_panel_settings
                  : Icons.badge,
              color: Colors.indigo,
            ),
            title: const Text('User Session & Role'),
            subtitle: Text(
              '${session?.email ?? "Guest"} (${session?.role.displayName ?? "Staff"})'
              '${session?.isDemo == true ? " • Demo Mode" : ""}',
            ),
            trailing: OutlinedButton(
              onPressed: () => LoginDialog.show(
                context,
                onSessionChanged: () => setState(() {}),
              ),
              child: const Text('Switch / Login'),
            ),
            onTap: () => LoginDialog.show(
              context,
              onSessionChanged: () => setState(() {}),
            ),
          ),
          ListTile(
            leading: Icon(
              Icons.cloud_done,
              color: isConfigured ? Colors.green : Colors.orange,
            ),
            title: const Text('Supabase Cloud Backend'),
            subtitle: Text(
              isConfigured
                  ? 'Connected to ${SupabaseService.instance.supabaseUrl}'
                  : 'Offline / Demo Mode (Tap to configure cloud keys)',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showSupabaseConfigDialog,
          ),
          ListTile(
            leading: const Icon(
              Icons.chat,
              color: Color(0xFF25D366),
            ),
            title: const Text('Business WhatsApp Helpline'),
            subtitle: Text(
              '+91 $_companyWhatsApp (Used for client downloads & chat)',
            ),
            trailing: const Icon(Icons.edit),
            onTap: _showEditWhatsAppDialog,
          ),
          const Divider(),
          SwitchListTile(
              title: const Text('Dark Mode'),
              subtitle: const Text('Toggle dark/light theme'),
              value: _isDarkMode,
              onChanged: (value) {
                setState(() => _isDarkMode = value);
                _saveSettings();
              }),
          const Divider(),
          ListTile(
              leading: const Icon(Icons.backup),
              title: const Text('Backup Data'),
              subtitle: const Text('Export all invoices as JSON'),
              onTap: _exportToJSON),
          ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Export as CSV'),
              subtitle: const Text('Export for Excel/Sheets'),
              onTap: _exportToCSV),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Clear All Data'),
            subtitle: const Text('Delete all invoices and clients'),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear All Data'),
                  content:
                      const Text('This action cannot be undone. Are you sure?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel')),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _savedInvoices.clear();
                          _savedClients.clear();
                          _notifications.clear();
                        });
                        _saveInvoicesToStorage();
                        _saveClientsToStorage();
                        _saveNotifications();
                        Navigator.pop(context);
                        _showSnackBar('All data cleared', Colors.orange);
                      },
                      style:
                          ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              );
            },
          ),
          const Divider(),
          const ListTile(
              leading: Icon(Icons.info),
              title: Text('About'),
              subtitle: Text('Version 2.0.0 | Professional Billing App')),
        ],
      ),
    );
  }

  void _showEditWhatsAppDialog() {
    final ctrl = TextEditingController(text: _companyWhatsApp);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.chat, color: Color(0xFF25D366)),
            SizedBox(width: 8),
            Text('Business WhatsApp'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the default WhatsApp number used for invoice delivery, client downloads, and support:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'WhatsApp Number',
                hintText: 'e.g. 9876543210',
                prefixText: '+91 ',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final cleaned = ctrl.text.replaceAll(RegExp(r'[^0-9]'), '');
              if (cleaned.isNotEmpty &&
                  (cleaned.length < 7 || cleaned.length > 15)) {
                _showSnackBar(
                    'Please enter a valid phone number (7-15 digits)',
                    Colors.red);
                return;
              }
              setState(() {
                _companyWhatsApp = cleaned;
                _companyPhone = cleaned.isNotEmpty ? '+91 $cleaned' : '';
              });
              _saveSettings();
              Navigator.pop(dialogContext);
              _showSnackBar(
                  cleaned.isNotEmpty
                      ? 'WhatsApp number updated to +91 $_companyWhatsApp'
                      : 'WhatsApp number cleared',
                  Colors.green);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showSupabaseConfigDialog() {
    final urlController = TextEditingController(
      text: SupabaseService.instance.supabaseUrl,
    );
    final anonKeyController = TextEditingController(
      text: SupabaseService.instance.supabaseAnonKey,
    );
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.cloud, color: Colors.teal),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Supabase Backend Config',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Connect your app directly to Supabase PostgreSQL database and Cloud Auth.',
                  style: TextStyle(fontSize: 13, color: Colors.black87),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: urlController,
                  decoration: const InputDecoration(
                    labelText: 'Supabase Project URL',
                    hintText: 'https://xyzcompany.supabase.co',
                    prefixIcon: Icon(Icons.link),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: anonKeyController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Supabase Anon Public Key',
                    hintText: 'eyJh...anon-key',
                    prefixIcon: Icon(Icons.key),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.code, size: 16),
                      label: const Text('Copy SQL Schema'),
                      onPressed: () {
                        Clipboard.setData(const ClipboardData(
                          text: SupabaseService.supabaseSqlSchema,
                        ));
                        _showSnackBar(
                          'SQL Schema copied to clipboard! Paste into Supabase SQL Editor.',
                          Colors.teal,
                        );
                      },
                    ),
                    if (SupabaseService.instance.isConfigured)
                      TextButton.icon(
                        icon: const Icon(Icons.link_off,
                            size: 16, color: Colors.red),
                        label: const Text('Disconnect',
                            style: TextStyle(color: Colors.red)),
                        onPressed: () async {
                          await SupabaseService.instance
                              .configure(url: '', anonKey: '');
                          if (dialogCtx.mounted) {
                            Navigator.pop(dialogCtx);
                            setState(() {});
                            _showSnackBar(
                                'Switched to Local/Demo mode', Colors.orange);
                          }
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      setDialogState(() => isSaving = true);
                      final url = urlController.text.trim();
                      final key = anonKeyController.text.trim();
                      if (url.isEmpty || key.isEmpty) {
                        _showSnackBar(
                          'Please enter both URL and Anon Key, or keep using Demo mode.',
                          Colors.red,
                        );
                        setDialogState(() => isSaving = false);
                        return;
                      }

                      final success = await SupabaseService.instance.configure(
                        url: url,
                        anonKey: key,
                      );

                      if (dialogCtx.mounted) {
                        Navigator.pop(dialogCtx);
                        setState(() {});
                        if (success) {
                          _showSnackBar('Connected to Supabase successfully!',
                              Colors.green);
                        } else {
                          _showSnackBar(
                            'Supabase initialized (verify credentials if sync fails)',
                            Colors.orange,
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white),
              child: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Save & Connect'),
            ),
          ],
        ),
      ),
    );
  }
}
