import 'package:flutter_test/flutter_test.dart';

import 'package:billing_app/auth/multi_tenant_service.dart';
import 'package:billing_app/customers/customer_service.dart';
import 'package:billing_app/domain/models.dart';
import 'package:billing_app/domain/money.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 3 — Customer Management & Quantitative Gate Tests', () {
    late CustomerService service;
    late MultiTenantService tenantService;

    setUp(() async {
      tenantService = MultiTenantService.instance;
      await tenantService.init();

      service = CustomerService.instance;
      await service.init();
    });

    test('Creates 20 distinct customer records and tests pagination', () async {
      final biz = await tenantService.createBusiness(name: 'Enterprise Logistics Corp');
      await tenantService.switchBusiness(biz.id);

      // Create 20 distinct customer records
      for (int i = 1; i <= 20; i++) {
        final cust = await service.createCustomer(
          name: 'Client Alpha $i',
          companyName: 'Company $i Pvt Ltd',
          phone: '98765432${i.toString().padLeft(2, '0')}',
          email: 'client$i@example.com',
          gstin: '32ABCDE1234F1Z${(i % 9) + 1}',
          gstType: i % 2 == 0 ? GstRegistrationType.registered : GstRegistrationType.consumer,
          creditLimit: Money.fromRupees(i * 1000.0),
        );
        expect(cust.id.isNotEmpty, isTrue);
        expect(cust.businessId, biz.id);
      }

      // Test Pagination: Page 1 (10 items)
      final page1 = service.getCustomers(page: 1, pageSize: 10);
      expect(page1.items.length, 10);
      expect(page1.totalCount, 20);
      expect(page1.totalPages, 2);

      // Test Pagination: Page 2 (10 items)
      final page2 = service.getCustomers(page: 2, pageSize: 10);
      expect(page2.items.length, 10);
      expect(page2.totalCount, 20);

      // Verify Page 1 and Page 2 contain zero duplicate records
      final idsPage1 = page1.items.map((c) => c.id).toSet();
      final idsPage2 = page2.items.map((c) => c.id).toSet();
      expect(idsPage1.intersection(idsPage2).isEmpty, isTrue);
    });

    test('Customer search works across Name, Company, Email, Phone, and GSTIN', () async {
      final searchResultName = service.getCustomers(searchQuery: 'Client Alpha 7');
      expect(searchResultName.items.length, 1);
      expect(searchResultName.items.first.name, 'Client Alpha 7');

      final searchResultCompany = service.getCustomers(searchQuery: 'Company 14');
      expect(searchResultCompany.items.length, 1);
      expect(searchResultCompany.items.first.companyName, 'Company 14 Pvt Ltd');

      final searchResultEmail = service.getCustomers(searchQuery: 'client19@example.com');
      expect(searchResultEmail.items.length, 1);
      expect(searchResultEmail.items.first.email, 'client19@example.com');
    });

    test('Validation enforces mandatory name and valid email/phone/GSTIN formats', () async {
      // 1. Empty name should throw
      expect(
        () => service.createCustomer(name: '   '),
        throwsA(isA<Exception>()),
      );

      // 2. Invalid email should throw
      expect(
        () => service.createCustomer(name: 'Valid Name', email: 'invalid-email-no-at'),
        throwsA(isA<Exception>()),
      );

      // 3. Invalid phone number (too short) should throw
      expect(
        () => service.createCustomer(name: 'Valid Name', phone: '123'),
        throwsA(isA<Exception>()),
      );

      // 4. Invalid GSTIN format (wrong length or characters) should throw
      expect(
        () => service.createCustomer(name: 'Valid Name', gstin: 'BADGSTIN'),
        throwsA(isA<Exception>()),
      );
    });

    test('Strict Tenant Isolation: Business A customers cannot be accessed by Business B', () async {
      // Setup Business A
      final bizA = await tenantService.createBusiness(name: 'Tenant Alpha');
      await tenantService.switchBusiness(bizA.id);
      final custA = await service.createCustomer(
        name: 'Confidential Client A',
        email: 'clientA@secret.com',
      );

      // Setup Business B
      final bizB = await tenantService.createBusiness(name: 'Tenant Beta');
      await tenantService.switchBusiness(bizB.id);

      // In Business B, searching for Client A must return empty (0 leaks)
      final resultsInB = service.getCustomers(searchQuery: 'Confidential Client A');
      expect(resultsInB.items.isEmpty, isTrue);

      // Direct getCustomer for custA ID in Business B context must return null
      final directLookup = service.getCustomer(custA.id);
      expect(directLookup, isNull);
    });

    test('Customer financial summary ledger calculates correct balances', () {
      final now = DateTime.now();
      const seller = Business(id: 'biz_01', name: 'Seller');
      const buyer = Customer(id: 'cust_target', businessId: 'biz_01', name: 'Target Client');

      final invoice1 = CanonicalInvoice(
        id: 'inv_1',
        businessId: 'biz_01',
        customerId: 'cust_target',
        invoiceNumber: 'INV-101',
        financialYear: '2026-2027',
        date: '10/09/2026',
        dueDate: '20/09/2026',
        seller: seller,
        buyer: buyer,
        placeOfSupply: 'Kerala',
        placeOfSupplyCode: '32',
        isInterState: false,
        items: const [],
        subtotal: Money.fromRupees(10000.0),
        invoiceDiscountAmount: Money.zero,
        totalDiscount: Money.zero,
        taxableAmount: Money.fromRupees(10000.0),
        totalCgst: Money.zero,
        totalSgst: Money.zero,
        totalIgst: Money.zero,
        totalCess: Money.zero,
        totalTax: Money.zero,
        roundOff: Money.zero,
        grandTotal: Money.fromRupees(10000.0),
        amountPaid: Money.fromRupees(6000.0),
        amountDue: Money.fromRupees(4000.0),
        createdAt: now,
        updatedAt: now,
      );

      final invoice2 = CanonicalInvoice(
        id: 'inv_2',
        businessId: 'biz_01',
        customerId: 'cust_target',
        invoiceNumber: 'INV-102',
        financialYear: '2026-2027',
        date: '01/08/2026',
        dueDate: '15/08/2026',
        status: InvoiceLifecycleStatus.overdue,
        seller: seller,
        buyer: buyer,
        placeOfSupply: 'Kerala',
        placeOfSupplyCode: '32',
        isInterState: false,
        items: const [],
        subtotal: Money.fromRupees(5000.0),
        invoiceDiscountAmount: Money.zero,
        totalDiscount: Money.zero,
        taxableAmount: Money.fromRupees(5000.0),
        totalCgst: Money.zero,
        totalSgst: Money.zero,
        totalIgst: Money.zero,
        totalCess: Money.zero,
        totalTax: Money.zero,
        roundOff: Money.zero,
        grandTotal: Money.fromRupees(5000.0),
        amountPaid: Money.zero,
        amountDue: Money.fromRupees(5000.0),
        createdAt: now,
        updatedAt: now,
      );

      final payments = [
        const PaymentRecord(
          id: 'pay_1',
          businessId: 'biz_01',
          invoiceId: 'inv_1',
          customerId: 'cust_target',
          amount: Money.fromPaise(600000), // ₹6000
          date: '12/09/2026',
          paymentMethod: 'UPI',
        ),
      ];

      final summary = service.getCustomerFinancialSummary('cust_target', [invoice1, invoice2], payments);
      expect(summary.totalInvoices, 2);
      expect(summary.totalInvoiced.inRupees, 15000.0);
      expect(summary.totalPaid.inRupees, 6000.0);
      expect(summary.outstandingBalance.inRupees, 9000.0);
      expect(summary.overdueAmount.inRupees, 5000.0);
    });
  });
}
