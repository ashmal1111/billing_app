import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:billing_app/invoice_templates.dart';
import 'package:billing_app/main.dart';
import 'package:billing_app/security_service.dart';
import 'package:billing_app/supabase_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return '.';
    });
  });

  setUp(() async {
    // Reset to default demo admin session before each test
    await SupabaseService.instance.loginAsDemoAdmin();
  });

  testWidgets('BillingApp smoke test - loads dashboard and navigation',
      (WidgetTester tester) async {
    await tester.pumpWidget(const BillingApp());
    await tester.pumpAndSettle();

    // Verify that dashboard elements are displayed.
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Quick Actions'), findsOneWidget);
    expect(find.text('Total Revenue'), findsOneWidget);

    // Verify bottom navigation bar items exist.
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Create'), findsOneWidget);
    expect(find.text('Preview'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Alerts'),
        findsNWidgets(2)); // StatCard + BottomNavigationBar
    expect(find.text('Settings'), findsOneWidget);

    // Verify User Session Chip in AppBar
    expect(find.text('Administrator'), findsOneWidget);

    // Tap 'Create' tab and verify Create Invoice screen is shown.
    await tester.tap(find.byIcon(Icons.edit_note));
    await tester.pumpAndSettle();
    expect(find.text('Create Invoice'), findsOneWidget);

    // Tap 'Income' tab and verify Admin Income Dashboard is shown for Admin.
    await tester.tap(find.byIcon(Icons.query_stats).last);
    await tester.pumpAndSettle();
    expect(find.text('Admin Income Dashboard'), findsOneWidget);
    expect(find.text('Net Income Realized'), findsOneWidget);
    expect(find.text('Gross Invoiced'), findsOneWidget);

    // Tap 'Settings' tab and verify Settings screen is shown.
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    expect(find.text('User Session & Role'), findsOneWidget);
    expect(find.text('Supabase Cloud Backend'), findsOneWidget);
    expect(find.text('Business WhatsApp Helpline'), findsOneWidget);
    expect(find.text('Dark Mode'), findsOneWidget);
  });

  testWidgets('Admin Income Dashboard access control - Admin vs Staff role',
      (WidgetTester tester) async {
    await tester.pumpWidget(const BillingApp());
    await tester.pumpAndSettle();

    // Navigate to Income tab as Admin
    await tester.tap(find.byIcon(Icons.query_stats).last);
    await tester.pumpAndSettle();
    expect(find.text('Admin Income Dashboard'), findsOneWidget);

    // Switch to Staff role
    await SupabaseService.instance.loginAsDemoStaff();
    await tester.pumpWidget(const BillingApp());
    await tester.pumpAndSettle();

    // Tap Income tab as Staff - should display access restricted lock screen
    await tester.tap(find.byIcon(Icons.query_stats).last);
    await tester.pumpAndSettle();
    expect(find.text('Access Restricted'), findsOneWidget);
    expect(find.text('Administrator Privileges Required'), findsOneWidget);
    expect(find.text('Log in as Administrator'), findsOneWidget);

    // Tap unlock button in lock screen
    await tester.tap(find.text('Log in as Administrator'));
    await tester.pumpAndSettle();
    expect(find.text('User Authentication'), findsOneWidget);

    // Switch back to Admin
    await tester.tap(find.text('Demo Admin'));
    await tester.pumpAndSettle();
    expect(find.text('Admin Income Dashboard'), findsOneWidget);
  });

  testWidgets('Create Invoice form validation - item price and required fields',
      (WidgetTester tester) async {
    await tester.pumpWidget(const BillingApp());
    await tester.pumpAndSettle();

    // Navigate to Create tab
    await tester.tap(find.byIcon(Icons.edit_note));
    await tester.pumpAndSettle();

    // Verify fields are present
    expect(find.text('Client Information'), findsOneWidget);
    expect(find.text('Invoice Details'), findsOneWidget);
    expect(find.text('Add Items'), findsOneWidget);

    // Scroll until Add Item button is visible and tap it with empty fields
    await tester.ensureVisible(find.byIcon(Icons.add_circle));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add_circle));
    await tester.pump();
    expect(find.text('Please enter item name'), findsOneWidget);
  });

  testWidgets('Invoice Preview renders template selector and WhatsApp button',
      (WidgetTester tester) async {
    await tester.pumpWidget(const BillingApp());
    await tester.pumpAndSettle();

    // Navigate to Preview tab
    await tester.tap(find.byIcon(Icons.preview));
    await tester.pumpAndSettle();

    // Verify Preview screen title
    expect(find.text('Preview Invoice'), findsOneWidget);

    // Verify all 5 built-in templates are available as chips
    expect(find.text('Modern Gradient'), findsWidgets);
    expect(find.text('Classic Corporate'), findsOneWidget);
    expect(find.text('Minimal Clean'), findsOneWidget);
    expect(find.text('Emerald Creative'), findsOneWidget);
    expect(find.text('Thermal POS Receipt'), findsOneWidget);

    // Verify action buttons including WhatsApp and Download are present
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Download'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);

    // Tap WhatsApp and verify business WhatsApp number 7356946847
    await tester.tap(find.text('WhatsApp'));
    await tester.pumpAndSettle();
    expect(find.text('WhatsApp & Download'), findsOneWidget);
    expect(find.text('Send to WhatsApp (+91 7356946847)'), findsOneWidget);
    expect(find.text('Download Invoice & Send'), findsOneWidget);
    await tester.tap(find.text('Open WhatsApp'));
    await tester.pumpAndSettle();

    // Switch to Classic Corporate template
    await tester.ensureVisible(find.text('Classic Corporate'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Classic Corporate'));
    await tester.pumpAndSettle();
    expect(find.text('Classic Corporate'), findsWidgets);

    // Switch to Thermal POS Receipt template
    await tester.ensureVisible(find.text('Thermal POS Receipt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thermal POS Receipt'));
    await tester.pumpAndSettle();
    expect(find.text('Thermal POS Receipt'), findsWidgets);

    // Switch to Emerald Creative template
    await tester.ensureVisible(find.text('Emerald Creative'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Emerald Creative'));
    await tester.pumpAndSettle();
    expect(find.text('Emerald Creative'), findsWidgets);
  });

  testWidgets('InvoiceTemplate model fromId mapping',
      (WidgetTester tester) async {
    expect(InvoiceTemplate.values.length, 5);
    expect(InvoiceTemplate.fromId('modern'), InvoiceTemplate.modern);
    expect(InvoiceTemplate.fromId('classic'), InvoiceTemplate.classic);
    expect(InvoiceTemplate.fromId('minimal'), InvoiceTemplate.minimal);
    expect(InvoiceTemplate.fromId('emerald'), InvoiceTemplate.emerald);
    expect(InvoiceTemplate.fromId('receipt'), InvoiceTemplate.receipt);
    expect(InvoiceTemplate.fromId('invalid_id'), InvoiceTemplate.modern);
  });

  testWidgets('Settings screen dark mode toggle', (WidgetTester tester) async {
    await tester.pumpWidget(const BillingApp());
    await tester.pumpAndSettle();

    // Navigate to Settings tab
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    // Find Dark Mode switch
    final switchFinder = find.byType(Switch);
    expect(switchFinder, findsOneWidget);

    // Toggle switch
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();
  });

  group('SecurityValidator Unit Tests', () {
    test('sanitizes text, null bytes, and control characters', () {
      const input = "Acme Corp\x00'; DROP TABLE invoices; --\x07";
      final result = SecurityValidator.sanitizeText(input);
      expect(result.contains('\x00'), isFalse);
      expect(result.contains('\x07'), isFalse);
      expect(result, "Acme Corp'; DROP TABLE invoices; --");

      // Length boundary
      final longText = 'A' * 300;
      final capped = SecurityValidator.sanitizeText(longText, maxLength: 50);
      expect(capped.length, 50);
    });

    test('prevents path traversal in sanitizeFileName', () {
      expect(SecurityValidator.sanitizeFileName('../../etc/passwd'),
          isNot(contains('..')));
      expect(SecurityValidator.sanitizeFileName('..\\..\\windows\\system32'),
          isNot(contains('..')));
      expect(SecurityValidator.sanitizeFileName('normal_invoice'),
          'normal_invoice.json');
      expect(
          SecurityValidator.sanitizeFileName('export.csv',
              defaultExtension: '.csv'),
          'export.csv');
    });

    test('sanitizes numbers against NaN, Infinity, and negatives', () {
      expect(SecurityValidator.sanitizeNumeric(double.nan, fallback: 0), 0);
      expect(
          SecurityValidator.sanitizeNumeric(double.infinity, fallback: 0), 0);
      expect(SecurityValidator.sanitizeNumeric(-50, min: 0), 0);
      expect(SecurityValidator.sanitizeNumeric(150, min: 0, max: 100), 100);
      expect(SecurityValidator.sanitizeNumeric('999.50'), 999.50);
      expect(SecurityValidator.sanitizeNumeric('invalid_number', fallback: 10),
          10);
    });

    test('validates email, phone, and Indian GSTIN', () {
      // Email
      expect(SecurityValidator.isValidEmail('billing@company.com'), isTrue);
      expect(SecurityValidator.isValidEmail('invalid-email'), isFalse);
      expect(SecurityValidator.isValidEmail(''), isFalse);

      // Phone
      expect(SecurityValidator.isValidPhone('+919876543210'), isTrue);
      expect(SecurityValidator.isValidPhone('9876543210'), isTrue);
      expect(SecurityValidator.isValidPhone('123'), isFalse); // too short
      expect(SecurityValidator.isValidPhone('letters_in_phone'), isFalse);

      // GSTIN (15 characters)
      expect(SecurityValidator.isValidGst('29ABCDE1234F1Z5'), isTrue);
      expect(SecurityValidator.isValidGst('INVALID_GST'), isFalse);
      expect(SecurityValidator.isValidGst(''), isTrue); // Optional field
    });

    test('sanitizeInvoice cleans entire invoice payload safely', () {
      final raw = {
        'invoiceNumber': "INV-001\x00",
        'clientName': "Client <script>alert(1)</script>",
        'clientEmail': "client@domain.com",
        'status': "UNKNOWN_STATUS",
        'subtotal': -500,
        'taxRate': 150,
        'taxAmount': double.nan,
        'total': -100,
        'items': [
          {
            'name': "Consulting\x00",
            'price': -200,
            'quantity': double.nan,
          }
        ],
      };

      final clean = SecurityValidator.sanitizeInvoice(raw);
      expect(clean['invoiceNumber'], 'INV-001');
      expect(clean['clientName'], 'Client <script>alert(1)</script>');
      expect(clean['status'], 'pending'); // Normalized to allowed enum
      expect(clean['subtotal'], 0); // Bounded to min 0
      expect(clean['taxRate'], 100); // Bounded to max 100
      expect(clean['taxAmount'], 0); // Handled NaN
      expect(clean['total'], 0); // Bounded to min 0

      final items = clean['items'] as List;
      expect(items.first['name'], 'Consulting');
      expect(items.first['price'], 0); // Bounded
      expect(items.first['quantity'], 1); // Handled NaN to min 1
    });
  });
}
