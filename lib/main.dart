import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const BillingApp());
}

class BillingApp extends StatelessWidget {
  const BillingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Billing App Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: const BillingHomePage(),
    );
  }
}

class BillingHomePage extends StatefulWidget {
  const BillingHomePage({super.key});

  @override
  State<BillingHomePage> createState() => _BillingHomePageState();
}

class _BillingHomePageState extends State<BillingHomePage> {
  bool _isDarkMode = false;
  
  final TextEditingController _clientNameController = TextEditingController();
  final TextEditingController _clientEmailController = TextEditingController();
  final TextEditingController _clientPhoneController = TextEditingController();
  final TextEditingController _clientAddressController = TextEditingController();
  final TextEditingController _clientGstController = TextEditingController();
  
  List<Map<String, String>> _savedClients = [];
  
  String _emailError = '';
  String _phoneError = '';
  
  final TextEditingController _invoiceNumberController = TextEditingController();
  final TextEditingController _invoiceDateController = TextEditingController();
  final TextEditingController _dueDateController = TextEditingController();
  
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _itemPriceController = TextEditingController();
  final TextEditingController _itemQtyController = TextEditingController();
  
  final TextEditingController _notesController = TextEditingController();
  
  List<Map<String, dynamic>> _items = [];
  double _taxRate = 18.0;
  int _selectedIndex = 0;
  String _currency = '₹';
  String _selectedPaymentMethod = 'UPI';
  String _invoiceStatus = 'pending';
  
  bool _showGST = true;
  bool _showDiscount = false;
  double _discountPercent = 0.0;
  String _companyName = 'Your Business Name';
  String _companyAddress = '123 Business Street, City - 123456';
  String _companyPhone = '+91 98765 43210';
  String _companyEmail = 'contact@yourbusiness.com';
  
  String _searchQuery = '';
  String _filterStatus = 'all';
  
  bool _isRecurring = false;
  String _recurringType = 'monthly';
  DateTime? _recurringEndDate;
  
  List<Map<String, dynamic>> _notifications = [];
  List<Map<String, dynamic>> _savedInvoices = [];
  
  @override
  void initState() {
    super.initState();
    _setDefaultDates();
    _setDefaultInvoiceNumber();
    _loadSavedInvoices();
    _loadSavedClients();
    _loadSettings();
    _checkDueInvoices();
    
    Timer.periodic(const Duration(hours: 24), (timer) {
      _checkDueInvoices();
    });
  }
  
  void _loadSettings() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/settings.json');
      if (await file.exists()) {
        String data = await file.readAsString();
        final settings = json.decode(data);
        setState(() {
          _isDarkMode = settings['darkMode'] ?? false;
          _companyName = settings['companyName'] ?? _companyName;
          _companyAddress = settings['companyAddress'] ?? _companyAddress;
          _companyPhone = settings['companyPhone'] ?? _companyPhone;
          _companyEmail = settings['companyEmail'] ?? _companyEmail;
        });
      }
    } catch (e) {}
  }
  
  void _saveSettings() async {
    final settings = {
      'darkMode': _isDarkMode,
      'companyName': _companyName,
      'companyAddress': _companyAddress,
      'companyPhone': _companyPhone,
      'companyEmail': _companyEmail,
    };
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/settings.json');
      await file.writeAsString(json.encode(settings));
    } catch (e) {}
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
              message: 'Invoice ${invoice['invoiceNumber']} for ${invoice['clientName']} is overdue',
              type: 'warning',
            );
          }
        } catch (e) {}
      }
    }
    _saveInvoicesToStorage();
  }
  
  void _addNotification({required String title, required String message, required String type}) {
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
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/notifications.json');
      await file.writeAsString(json.encode(_notifications));
    } catch (e) {}
  }
  
  void _loadSavedClients() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/clients.json');
      if (await file.exists()) {
        String data = await file.readAsString();
        setState(() {
          _savedClients = List<Map<String, String>>.from(json.decode(data));
        });
      }
    } catch (e) {}
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
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/clients.json');
      await file.writeAsString(json.encode(_savedClients));
    } catch (e) {}
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
    _invoiceNumberController.text = "INV-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.hour}${now.minute}${now.second}";
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
    if (_itemNameController.text.isEmpty) {
      _showSnackBar('Please enter item name', Colors.orange);
      return;
    }
    if (_itemPriceController.text.isEmpty) {
      _showSnackBar('Please enter price', Colors.orange);
      return;
    }
    
    setState(() {
      _items.add({
        'name': _itemNameController.text,
        'price': double.parse(_itemPriceController.text),
        'quantity': int.tryParse(_itemQtyController.text) ?? 1,
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
    if (_clientNameController.text.trim().isEmpty) {
      _showSnackBar('Please enter client name', Colors.red);
      return;
    }
    if (_items.isEmpty) {
      _showSnackBar('Please add at least one item', Colors.red);
      return;
    }
    
    final invoice = {
      'invoiceNumber': _invoiceNumberController.text,
      'clientName': _clientNameController.text,
      'clientEmail': _clientEmailController.text,
      'clientPhone': _clientPhoneController.text,
      'clientAddress': _clientAddressController.text,
      'clientGst': _clientGstController.text,
      'date': _invoiceDateController.text,
      'dueDate': _dueDateController.text,
      'items': _items,
      'subtotal': _subtotal,
      'taxRate': _taxRate,
      'taxAmount': _taxAmount,
      'total': _total,
      'notes': _notesController.text,
      'paymentMethod': _selectedPaymentMethod,
      'status': _invoiceStatus,
      'isRecurring': _isRecurring,
      'recurringType': _recurringType,
      'recurringEndDate': _recurringEndDate?.toIso8601String(),
      'savedAt': DateTime.now().toIso8601String(),
    };
    
    setState(() {
      _savedInvoices.insert(0, invoice);
    });
    
    await _saveInvoicesToStorage();
    
    _addNotification(
      title: 'Invoice Created',
      message: 'Invoice ${_invoiceNumberController.text} created for ${_clientNameController.text}',
      type: 'success',
    );
    
    _showSnackBar('Invoice saved successfully!', Colors.green);
  }
  
  Future<void> _saveInvoicesToStorage() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/invoices.json');
      await file.writeAsString(json.encode(_savedInvoices));
    } catch (e) {}
  }
  
  Future<void> _loadSavedInvoices() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/invoices.json');
      if (await file.exists()) {
        String data = await file.readAsString();
        setState(() {
          _savedInvoices = List<Map<String, dynamic>>.from(json.decode(data));
        });
      }
    } catch (e) {}
  }
  
  List<Map<String, dynamic>> get _filteredInvoices {
    var filtered = _savedInvoices;
    
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((inv) =>
        inv['clientName'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
        inv['invoiceNumber'].toString().toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }
    
    if (_filterStatus != 'all') {
      filtered = filtered.where((inv) => inv['status'] == _filterStatus).toList();
    }
    
    return filtered;
  }
  
  double get _totalRevenue {
    return _savedInvoices.fold(0.0, (sum, inv) => sum + (inv['total'] as double));
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
    
    String csv = 'Invoice #,Client Name,Date,Due Date,Subtotal,Tax,Total,Status,Payment Method\n';
    for (var inv in _savedInvoices) {
      csv += '"${inv['invoiceNumber']}","${inv['clientName']}","${inv['date']}","${inv['dueDate']}",${inv['subtotal']},${inv['taxAmount']},${inv['total']},"${inv['status']}","${inv['paymentMethod']}"\n';
    }
    
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'invoices_export_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(csv);
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Export Successful'),
            content: Text('File saved: $fileName\n\nLocation: ${directory.path}'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
              TextButton(onPressed: () async { await Share.shareFiles([file.path]); if (mounted) Navigator.pop(context); }, child: const Text('Share')),
            ],
          ),
        );
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
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'invoices_backup_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.json';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(json.encode(_savedInvoices));
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Backup Created'),
            content: Text('File saved: $fileName'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
              TextButton(onPressed: () async { await Share.shareFiles([file.path]); if (mounted) Navigator.pop(context); }, child: const Text('Share')),
            ],
          ),
        );
      }
    } catch (e) {
      _showSnackBar('Error backing up: $e', Colors.red);
    }
  }
  
  Future<void> _shareInvoice(Map<String, dynamic> invoice) async {
    final invoiceText = _generateInvoiceText(invoice);
    await Share.share(invoiceText, subject: 'Invoice ${invoice['invoiceNumber']}');
  }
  
  String _generateInvoiceText(Map<String, dynamic> invoice) {
    final buffer = StringBuffer();
    buffer.writeln('=' * 50);
    buffer.writeln('INVOICE');
    buffer.writeln('=' * 50);
    buffer.writeln('\nInvoice #: ${invoice['invoiceNumber']}');
    buffer.writeln('Date: ${invoice['date']}');
    buffer.writeln('Client: ${invoice['clientName']}');
    buffer.writeln('Total: ${invoice['total']}');
    buffer.writeln('Status: ${invoice['status']}');
    return buffer.toString();
  }
  
  void _sendPaymentReminder(Map<String, dynamic> invoice) {
    _addNotification(
      title: 'Payment Reminder Sent',
      message: 'Reminder sent to ${invoice['clientName']} for invoice ${invoice['invoiceNumber']}',
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
      message: 'Payment received for invoice ${invoice['invoiceNumber']} from ${invoice['clientName']}',
      type: 'success',
    );
    _showSnackBar('Invoice marked as paid!', Colors.green);
  }
  
  Color _getStatusColor(String status) {
    switch (status) {
      case 'paid': return Colors.green;
      case 'pending': return Colors.orange;
      case 'overdue': return Colors.red;
      default: return Colors.grey;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _isDarkMode ? ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(primary: Colors.indigo),
        appBarTheme: const AppBarTheme(backgroundColor: Colors.indigo),
      ) : ThemeData.light().copyWith(
        colorScheme: const ColorScheme.light(primary: Colors.indigo),
        appBarTheme: const AppBarTheme(backgroundColor: Colors.indigo),
      ),
      home: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            _buildDashboard(),
            _buildInvoiceForm(),
            _buildInvoicePreview(),
            _buildSavedInvoices(),
            _buildNotifications(),
            _buildSettings(),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -5)),
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
              BottomNavigationBarItem(icon: Icon(Icons.edit_note), label: 'Create'),
              BottomNavigationBarItem(icon: Icon(Icons.preview), label: 'Preview'),
              BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
              BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Alerts'),
              BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildDashboard() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () { setState(() => _isDarkMode = !_isDarkMode); _saveSettings(); },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async { setState(() {}); await _loadSavedInvoices(); },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(children: [
                Expanded(child: _buildStatCard('Total Revenue', '${_currency}${_totalRevenue.toStringAsFixed(0)}', Icons.currency_rupee, Colors.green)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard('Total Invoices', _savedInvoices.length.toString(), Icons.receipt, Colors.blue)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _buildStatCard('Paid', _paidInvoicesCount.toString(), Icons.check_circle, Colors.green)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard('Pending', _pendingInvoicesCount.toString(), Icons.pending, Colors.orange)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _buildStatCard('Overdue', _overdueInvoicesCount.toString(), Icons.warning, Colors.red)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard('Alerts', _notifications.where((n) => n['read'] == false).length.toString(), Icons.notifications, Colors.purple)),
              ]),
              const SizedBox(height: 24),
              const Text('Quick Actions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _buildActionButton('New Invoice', Icons.add, Colors.indigo, () { setState(() { _resetForm(); _selectedIndex = 1; }); })),
                const SizedBox(width: 12),
                Expanded(child: _buildActionButton('Export CSV', Icons.download, Colors.green, _exportToCSV)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _buildActionButton('Backup', Icons.backup, Colors.orange, _exportToJSON)),
                const SizedBox(width: 12),
                Expanded(child: _buildActionButton('Saved Clients', Icons.people, Colors.purple, _showSavedClientsDialog)),
              ]),
              const SizedBox(height: 24),
              const Text('Recent Invoices', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (_savedInvoices.isEmpty) const Center(child: Text('No invoices yet'))
              else ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _savedInvoices.length > 5 ? 5 : _savedInvoices.length,
                itemBuilder: (context, index) {
                  final inv = _savedInvoices[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(backgroundColor: _getStatusColor(inv['status']), child: Text('${index + 1}')),
                      title: Text(inv['invoiceNumber']),
                      subtitle: Text(inv['clientName']),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('${_currency}${inv['total']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: _getStatusColor(inv['status']), borderRadius: BorderRadius.circular(12)),
                            child: Text(inv['status'], style: const TextStyle(color: Colors.white, fontSize: 10))),
                        ],
                      ),
                      onTap: () => _showInvoiceDetails(inv, _savedInvoices.indexOf(inv)),
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
  
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ],
        ),
      ),
    );
  }
  
  Widget _buildActionButton(String title, IconData icon, Color color, VoidCallback onTap) {
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }
  
  void _showInvoiceDetails(Map<String, dynamic> invoice, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(invoice['invoiceNumber']),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Client: ${invoice['clientName']}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Date: ${invoice['date']}'),
              Text('Due: ${invoice['dueDate']}'),
              Text('Total: ${_currency}${invoice['total']}'),
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: _getStatusColor(invoice['status']), borderRadius: BorderRadius.circular(12)),
                child: Text(invoice['status'], style: const TextStyle(color: Colors.white)),
              ),
              const Divider(),
              const Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...(invoice['items'] as List).map((item) => Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: Text('• ${item['name']} x ${item['quantity']} = ${_currency}${item['price'] * item['quantity']}'),
              )).toList(),
            ],
          ),
        ),
        actions: [
          if (invoice['status'] == 'pending')
            TextButton(onPressed: () { Navigator.pop(context); _markAsPaid(invoice, index); }, child: const Text('Mark Paid')),
          TextButton(onPressed: () => _sendPaymentReminder(invoice), child: const Text('Reminder')),
          TextButton(onPressed: () => _shareInvoice(invoice), child: const Text('Share')),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }
  
  Widget _buildInvoiceForm() {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Invoice'), backgroundColor: Colors.indigo, foregroundColor: Colors.white),
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
                      const Text('Quick Select Client', style: TextStyle(fontWeight: FontWeight.bold)),
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
                              child: ActionChip(label: Text(client['name']!), onPressed: () => _selectSavedClient(client)),
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
            ]),
            const SizedBox(height: 16),
            _buildSectionCard('Invoice Status', Icons.flag, [
              DropdownButtonFormField<String>(
                value: _invoiceStatus,
                items: const [
                  DropdownMenuItem(value: 'pending', child: Text('Pending')),
                  DropdownMenuItem(value: 'paid', child: Text('Paid')),
                  DropdownMenuItem(value: 'overdue', child: Text('Overdue')),
                ],
                onChanged: (value) => setState(() => _invoiceStatus = value!),
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
            ]),
            const SizedBox(height: 16),
            _buildSectionCard('Add Items', Icons.shopping_cart, [
              Row(
                children: [
                  Expanded(flex: 2, child: TextField(controller: _itemNameController, decoration: const InputDecoration(hintText: 'Item', border: OutlineInputBorder()))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: _itemPriceController, decoration: const InputDecoration(hintText: 'Price', border: OutlineInputBorder(), prefixText: '₹'), keyboardType: TextInputType.number)),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: _itemQtyController, decoration: const InputDecoration(hintText: 'Qty', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                  const SizedBox(width: 8),
                  IconButton(icon: const Icon(Icons.add_circle, color: Colors.indigo), onPressed: _addItem),
                ],
              ),
            ]),
            if (_items.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      const Text('Items', style: TextStyle(fontWeight: FontWeight.bold)),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return ListTile(
                            title: Text(item['name']),
                            subtitle: Text('₹${item['price']} x ${item['quantity']} = ₹${item['price'] * item['quantity']}'),
                            trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _removeItem(index)),
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
      floatingActionButton: FloatingActionButton(onPressed: () => setState(() => _selectedIndex = 2), child: const Icon(Icons.preview)),
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
            Row(children: [Icon(icon, color: Colors.indigo), const SizedBox(width: 8), Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
  
  Widget _buildInvoicePreview() {
    return Scaffold(
      appBar: AppBar(title: const Text('Preview Invoice'), backgroundColor: Colors.indigo, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 8,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(gradient: LinearGradient(colors: [Colors.indigo, Colors.indigoAccent]), borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('INVOICE', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(_invoiceNumberController.text, style: const TextStyle(color: Colors.white70)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: _getStatusColor(_invoiceStatus), borderRadius: BorderRadius.circular(12)),
                            child: Text(_invoiceStatus.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Bill To:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(_clientNameController.text.isEmpty ? 'Not specified' : _clientNameController.text),
                      if (_clientEmailController.text.isNotEmpty) Text(_clientEmailController.text),
                      if (_clientPhoneController.text.isNotEmpty) Text(_clientPhoneController.text),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (_items.isNotEmpty)
                  Table(
                    border: TableBorder.all(color: Colors.grey.shade300),
                    children: [
                      TableRow(
                        decoration: BoxDecoration(color: Colors.indigo.shade100),
                        children: const [
                          Padding(padding: EdgeInsets.all(12), child: Text('Item')),
                          Padding(padding: EdgeInsets.all(12), child: Text('Qty')),
                          Padding(padding: EdgeInsets.all(12), child: Text('Price')),
                          Padding(padding: EdgeInsets.all(12), child: Text('Total')),
                        ],
                      ),
                      ..._items.map((item) {
                        final total = item['price'] * item['quantity'];
                        return TableRow(children: [
                          Padding(padding: const EdgeInsets.all(12), child: Text(item['name'])),
                          Padding(padding: const EdgeInsets.all(12), child: Text(item['quantity'].toString())),
                          Padding(padding: const EdgeInsets.all(12), child: Text('₹${item['price']}')),
                          Padding(padding: const EdgeInsets.all(12), child: Text('₹$total', style: const TextStyle(fontWeight: FontWeight.bold))),
                        ]);
                      }).toList(),
                    ],
                  ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Subtotal:'), Text('₹${_subtotal.toStringAsFixed(2)}')]),
                      if (_showGST) const SizedBox(height: 8),
                      if (_showGST) Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('GST (${_taxRate.toInt()}%):'), Text('₹${_taxAmount.toStringAsFixed(2)}')]),
                      if (_showDiscount && _discountPercent > 0) const SizedBox(height: 8),
                      if (_showDiscount && _discountPercent > 0) Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Discount (${_discountPercent.toInt()}%):'), Text('-₹${_discountAmount.toStringAsFixed(2)}')]),
                      const Divider(),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Total:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), Text('₹${_total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.indigo))]),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: OutlinedButton.icon(onPressed: () => setState(() => _selectedIndex = 1), icon: const Icon(Icons.edit), label: const Text('Edit'))),
                    const SizedBox(width: 12),
                    Expanded(child: ElevatedButton.icon(onPressed: _saveInvoiceToStorage, icon: const Icon(Icons.save), label: const Text('Save'))),
                  ],
                ),
              ],
            ),
          ),
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
          IconButton(icon: const Icon(Icons.search), onPressed: () => _showSearchDialog()),
          PopupMenuButton<String>(
            onSelected: (value) { if (value == 'csv') _exportToCSV(); if (value == 'json') _exportToJSON(); },
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
                  FilterChip(label: const Text('All'), selected: _filterStatus == 'all', onSelected: (_) => setState(() => _filterStatus = 'all')),
                  const SizedBox(width: 8),
                  FilterChip(label: const Text('Pending'), selected: _filterStatus == 'pending', onSelected: (_) => setState(() => _filterStatus = 'pending'), backgroundColor: Colors.orange.shade100),
                  const SizedBox(width: 8),
                  FilterChip(label: const Text('Paid'), selected: _filterStatus == 'paid', onSelected: (_) => setState(() => _filterStatus = 'paid'), backgroundColor: Colors.green.shade100),
                  const SizedBox(width: 8),
                  FilterChip(label: const Text('Overdue'), selected: _filterStatus == 'overdue', onSelected: (_) => setState(() => _filterStatus = 'overdue'), backgroundColor: Colors.red.shade100),
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
                          leading: CircleAvatar(backgroundColor: _getStatusColor(inv['status']), child: Text('${index + 1}')),
                          title: Text(inv['invoiceNumber'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(inv['clientName']),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('${_currency}${inv['total']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text(inv['date'], style: const TextStyle(fontSize: 10)),
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
          decoration: const InputDecoration(hintText: 'Invoice number or client name', prefixIcon: Icon(Icons.search)),
          onChanged: (value) => setState(() => _searchQuery = value),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
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
            onPressed: () { setState(() => _notifications.forEach((n) => n['read'] = true)); _saveNotifications(); },
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
                      notif['type'] == 'success' ? Icons.check_circle : notif['type'] == 'warning' ? Icons.warning : Icons.info,
                      color: notif['type'] == 'success' ? Colors.green : notif['type'] == 'warning' ? Colors.orange : Colors.blue,
                    ),
                    title: Text(notif['title']),
                    subtitle: Text(notif['message']),
                    trailing: Text(DateFormat('dd/MM/yy').format(DateTime.parse(notif['time'])), style: const TextStyle(fontSize: 10)),
                    onTap: () { setState(() => notif['read'] = true); _saveNotifications(); },
                  ),
                );
              },
            ),
    );
  }
  
  Widget _buildSettings() {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), backgroundColor: Colors.indigo, foregroundColor: Colors.white),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(title: const Text('Dark Mode'), subtitle: const Text('Toggle dark/light theme'), value: _isDarkMode, onChanged: (value) { setState(() => _isDarkMode = value); _saveSettings(); }),
          const Divider(),
          ListTile(leading: const Icon(Icons.backup), title: const Text('Backup Data'), subtitle: const Text('Export all invoices as JSON'), onTap: _exportToJSON),
          ListTile(leading: const Icon(Icons.download), title: const Text('Export as CSV'), subtitle: const Text('Export for Excel/Sheets'), onTap: _exportToCSV),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Clear All Data'),
            subtitle: const Text('Delete all invoices and clients'),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear All Data'),
                  content: const Text('This action cannot be undone. Are you sure?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    ElevatedButton(
                      onPressed: () {
                        setState(() { _savedInvoices.clear(); _savedClients.clear(); _notifications.clear(); });
                        _saveInvoicesToStorage();
                        _saveClientsToStorage();
                        _saveNotifications();
                        Navigator.pop(context);
                        _showSnackBar('All data cleared', Colors.orange);
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              );
            },
          ),
          const Divider(),
          const ListTile(leading: Icon(Icons.info), title: Text('About'), subtitle: Text('Version 2.0.0 | Professional Billing App')),
        ],
      ),
    );
  }
}
