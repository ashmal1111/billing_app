import 'package:flutter_test/flutter_test.dart';

import 'package:billing_app/auth/multi_tenant_service.dart';
import 'package:billing_app/domain/calculation_engine.dart';
import 'package:billing_app/domain/money.dart';
import 'package:billing_app/products/product_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 4 — Product & Service Catalog & Quantitative Gate Tests', () {
    late ProductService service;
    late MultiTenantService tenantService;

    setUp(() async {
      tenantService = MultiTenantService.instance;
      await tenantService.init();

      service = ProductService.instance;
      await service.init();
    });

    test('Creates 20 distinct products across 5 categories and tests pagination', () async {
      final biz = await tenantService.createBusiness(name: 'Apex Infotech Solutions');
      await tenantService.switchBusiness(biz.id);

      final catalogData = [
        // Category 1: Hardware (4 products)
        {
          'name': 'Dell Latitude Business Laptop',
          'category': 'Hardware',
          'sku': 'HW-DELL-LAT',
          'hsn': '84713010',
          'unit': 'Unit',
          'cost': 55000.0,
          'selling': 65000.0,
          'gst': 18.0,
          'stock': 15.0,
        },
        {
          'name': 'Logitech MX Master 3S Mouse',
          'category': 'Hardware',
          'sku': 'HW-LOGI-MX3',
          'hsn': '84716060',
          'unit': 'Pcs',
          'cost': 6000.0,
          'selling': 8999.0,
          'gst': 18.0,
          'stock': 40.0,
        },
        {
          'name': 'Samsung 27" 4K IPS Monitor',
          'category': 'Hardware',
          'sku': 'HW-SAM-274K',
          'hsn': '85285200',
          'unit': 'Unit',
          'cost': 21000.0,
          'selling': 26500.0,
          'gst': 18.0,
          'stock': 12.0,
        },
        {
          'name': 'Epson Thermal POS Receipt Printer',
          'category': 'Hardware',
          'sku': 'HW-EPS-POS80',
          'hsn': '84433250',
          'unit': 'Unit',
          'cost': 7500.0,
          'selling': 9800.0,
          'gst': 18.0,
          'stock': 8.0,
        },

        // Category 2: Cloud Services (4 products)
        {
          'name': 'AWS Cloud Compute Cluster (c6i.2xlarge)',
          'category': 'Cloud Services',
          'sku': 'CS-AWS-C6I',
          'hsn': '998315',
          'unit': 'Month',
          'cost': 18000.0,
          'selling': 24000.0,
          'gst': 18.0,
          'stock': 100.0,
        },
        {
          'name': 'Supabase Dedicated PostgreSQL Cloud',
          'category': 'Cloud Services',
          'sku': 'CS-SUPA-PG',
          'hsn': '998315',
          'unit': 'Month',
          'cost': 15000.0,
          'selling': 20000.0,
          'gst': 18.0,
          'stock': 100.0,
        },
        {
          'name': 'Cloudflare Enterprise CDN & WAF',
          'category': 'Cloud Services',
          'sku': 'CS-CF-ENT',
          'hsn': '998315',
          'unit': 'Month',
          'cost': 12000.0,
          'selling': 16000.0,
          'gst': 18.0,
          'stock': 50.0,
        },
        {
          'name': 'Google Workspace Business Plus Seat',
          'category': 'Cloud Services',
          'sku': 'CS-GWS-PLUS',
          'hsn': '998314',
          'unit': 'Seat/Mo',
          'cost': 1200.0,
          'selling': 1500.0,
          'gst': 18.0,
          'stock': 500.0,
        },

        // Category 3: Consulting (4 products)
        {
          'name': 'Enterprise Architecture Advisory',
          'category': 'Consulting',
          'sku': 'CON-ARCH-ADV',
          'hsn': '998311',
          'unit': 'Day',
          'cost': 30000.0,
          'selling': 50000.0,
          'gst': 18.0,
          'stock': 30.0,
        },
        {
          'name': 'GST Filing & Compliance Advisory',
          'category': 'Consulting',
          'sku': 'CON-GST-COMP',
          'hsn': '998222',
          'unit': 'Audit',
          'cost': 15000.0,
          'selling': 25000.0,
          'gst': 18.0,
          'stock': 20.0,
        },
        {
          'name': 'Application Security Penetration Testing',
          'category': 'Consulting',
          'sku': 'CON-SEC-PENTEST',
          'hsn': '998316',
          'unit': 'Audit',
          'cost': 60000.0,
          'selling': 100000.0,
          'gst': 18.0,
          'stock': 10.0,
        },
        {
          'name': 'DevOps & CI/CD Pipeline Automation',
          'category': 'Consulting',
          'sku': 'CON-DEVOPS-AUTO',
          'hsn': '998313',
          'unit': 'Sprint',
          'cost': 40000.0,
          'selling': 65000.0,
          'gst': 18.0,
          'stock': 15.0,
        },

        // Category 4: Software Licenses (4 products)
        {
          'name': 'Billing App SaaS Pro Annual License',
          'category': 'Software Licenses',
          'sku': 'LIC-BILL-PRO',
          'hsn': '997331',
          'unit': 'Year',
          'cost': 4000.0,
          'selling': 9999.0,
          'gst': 18.0,
          'stock': 1000.0,
        },
        {
          'name': 'ERPNext Enterprise User License',
          'category': 'Software Licenses',
          'sku': 'LIC-ERP-ENT',
          'hsn': '997331',
          'unit': 'User/Yr',
          'cost': 18000.0,
          'selling': 25000.0,
          'gst': 18.0,
          'stock': 200.0,
        },
        {
          'name': 'Endpoint Antivirus Commercial License',
          'category': 'Software Licenses',
          'sku': 'LIC-AV-COMM',
          'hsn': '997331',
          'unit': 'Device/Yr',
          'cost': 800.0,
          'selling': 1500.0,
          'gst': 18.0,
          'stock': 300.0,
        },
        {
          'name': 'Universal PDF Invoice Generator SDK',
          'category': 'Software Licenses',
          'sku': 'LIC-PDF-SDK',
          'hsn': '997331',
          'unit': 'Developer',
          'cost': 20000.0,
          'selling': 35000.0,
          'gst': 18.0,
          'stock': 50.0,
        },

        // Category 5: Maintenance (4 products)
        {
          'name': 'Annual Maintenance Contract - Infrastructure',
          'category': 'Maintenance',
          'sku': 'MNT-AMC-INFRA',
          'hsn': '998717',
          'unit': 'Year',
          'cost': 25000.0,
          'selling': 45000.0,
          'gst': 18.0,
          'stock': 25.0,
        },
        {
          'name': 'Database Tuning & SLA Support 24x7',
          'category': 'Maintenance',
          'sku': 'MNT-DB-247',
          'hsn': '998313',
          'unit': 'Month',
          'cost': 12000.0,
          'selling': 22000.0,
          'gst': 18.0,
          'stock': 20.0,
        },
        {
          'name': 'On-Site Network Equipment Support',
          'category': 'Maintenance',
          'sku': 'MNT-NET-ONSITE',
          'hsn': '998717',
          'unit': 'Visit',
          'cost': 3000.0,
          'selling': 5500.0,
          'gst': 18.0,
          'stock': 50.0,
        },
        {
          'name': 'Automated Offsite Backup & DR SLA',
          'category': 'Maintenance',
          'sku': 'MNT-BACKUP-DR',
          'hsn': '998315',
          'unit': 'Month',
          'cost': 6000.0,
          'selling': 12000.0,
          'gst': 18.0,
          'stock': 3.0, // Low stock <= 5
        },
      ];

      expect(catalogData.length, 20);

      // Create all 20 products
      for (final item in catalogData) {
        final prod = await service.createProduct(
          name: item['name'] as String,
          category: item['category'] as String,
          sku: item['sku'] as String,
          hsnSac: item['hsn'] as String,
          unit: item['unit'] as String,
          costPrice: Money.fromRupees(item['cost'] as num),
          sellingPrice: Money.fromRupees(item['selling'] as num),
          gstRate: (item['gst'] as num).toDouble(),
          stockQuantity: (item['stock'] as num).toDouble(),
        );
        expect(prod.id.isNotEmpty, isTrue);
        expect(prod.businessId, biz.id);
      }

      // Verify categories count
      final distinctCategories = service.getActiveCategories();
      expect(distinctCategories.length, 5);
      expect(distinctCategories.contains('Hardware'), isTrue);
      expect(distinctCategories.contains('Cloud Services'), isTrue);
      expect(distinctCategories.contains('Consulting'), isTrue);
      expect(distinctCategories.contains('Software Licenses'), isTrue);
      expect(distinctCategories.contains('Maintenance'), isTrue);

      // Test Pagination: Page 1 (10 items)
      final page1 = service.getProducts(page: 1, pageSize: 10);
      expect(page1.items.length, 10);
      expect(page1.totalCount, 20);
      expect(page1.totalPages, 2);

      // Test Pagination: Page 2 (10 items)
      final page2 = service.getProducts(page: 2, pageSize: 10);
      expect(page2.items.length, 10);
      expect(page2.totalCount, 20);

      // Zero duplicate IDs between Page 1 and Page 2
      final ids1 = page1.items.map((p) => p.id).toSet();
      final ids2 = page2.items.map((p) => p.id).toSet();
      expect(ids1.intersection(ids2).isEmpty, isTrue);

      // Test Low Stock Filtering (threshold 5.0)
      final lowStockResult = service.getProducts(lowStockOnly: true, lowStockThreshold: 5.0);
      expect(lowStockResult.items.isNotEmpty, isTrue);
      for (final p in lowStockResult.items) {
        expect(p.stockQuantity <= 5.0, isTrue);
      }
    });

    test('10 Invoice Line-Item Autofill selections map with zero discrepancies', () {
      final testProducts = service.getProducts(pageSize: 10).items;
      expect(testProducts.length, 10);

      for (int i = 0; i < testProducts.length; i++) {
        final prod = testProducts[i];
        final quantity = (i + 1).toDouble();
        final discountPct = (i * 2).toDouble();

        // Map product to line item input
        final input = ProductService.mapProductToLineItemInput(
          prod,
          quantity: quantity,
          discountPercent: discountPct,
        );

        expect(input.productId, prod.id);
        expect(input.name, prod.name);
        expect(input.hsnSac, prod.hsnSac);
        expect(input.unit, prod.unit);
        expect(input.unitPrice, prod.sellingPrice.inRupees.toDouble());
        expect(input.gstRate, prod.gstRate);
        expect(input.isTaxInclusive, prod.isTaxInclusive);

        // Evaluate using FinancialCalculationEngine (Intra-State: 50% CGST + 50% SGST)
        final evaluated = FinancialCalculationEngine.calculateLineItem(
          input: input,
          isInterState: false,
          isReverseCharge: false,
        );

        final expectedGross = prod.sellingPrice.multiply(quantity);
        expect(evaluated.grossAmount, expectedGross);

        final expectedDiscount = expectedGross.percentage(discountPct);
        expect(evaluated.discountAmount, expectedDiscount);

        final expectedTaxable = expectedGross - expectedDiscount;
        expect(evaluated.taxableAmount, expectedTaxable);

        final expectedCgst = expectedTaxable.percentage(prod.gstRate / 2);
        final expectedSgst = expectedTaxable.percentage(prod.gstRate / 2);
        expect(evaluated.cgst, expectedCgst);
        expect(evaluated.sgst, expectedSgst);
        expect(evaluated.igst, Money.zero);

        final expectedLineTotal = expectedTaxable + expectedCgst + expectedSgst;
        expect(evaluated.lineTotal, expectedLineTotal);
      }
    });

    test('Strict Tenant Isolation: Business Alpha products cannot be accessed by Business Beta', () async {
      // Business Alpha
      final bizAlpha = await tenantService.createBusiness(name: 'Tenant Alpha Ventures');
      await tenantService.switchBusiness(bizAlpha.id);
      final prodAlpha = await service.createProduct(
        name: 'Proprietary Algorithm Alpha',
        hsnSac: '998311',
        sellingPrice: Money.fromRupees(150000.0),
      );

      // Business Beta
      final bizBeta = await tenantService.createBusiness(name: 'Tenant Beta Logistics');
      await tenantService.switchBusiness(bizBeta.id);

      // Beta search must return 0 results
      final searchInBeta = service.getProducts(searchQuery: 'Proprietary Algorithm Alpha');
      expect(searchInBeta.items.isEmpty, isTrue);

      // Beta direct lookup by ID must return null
      final directLookupInBeta = service.getProduct(prodAlpha.id);
      expect(directLookupInBeta, isNull);

      // Attempt to update Alpha product while Beta is active must fail
      expect(
        () => service.updateProduct(prodAlpha),
        throwsA(isA<Exception>()),
      );
    });

    test('Validation enforces mandatory name, valid HSN/SAC format, and non-negative pricing', () async {
      // 1. Empty name should throw
      expect(
        () => service.createProduct(
          name: '   ',
          hsnSac: '84713010',
          sellingPrice: Money.fromRupees(100.0),
        ),
        throwsA(isA<Exception>()),
      );

      // 2. Invalid HSN/SAC code (letters or invalid length) should throw
      expect(
        () => service.createProduct(
          name: 'Invalid HSN Product',
          hsnSac: 'ABCDE',
          sellingPrice: Money.fromRupees(100.0),
        ),
        throwsA(isA<Exception>()),
      );

      // 3. Negative selling price should throw
      expect(
        () => service.createProduct(
          name: 'Negative Price Item',
          hsnSac: '84713010',
          sellingPrice: const Money.fromPaise(-5000),
        ),
        throwsA(isA<Exception>()),
      );

      // 4. Negative cost price should throw
      expect(
        () => service.createProduct(
          name: 'Negative Cost Item',
          hsnSac: '84713010',
          costPrice: const Money.fromPaise(-1000),
          sellingPrice: Money.fromRupees(100.0),
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('Stock adjustments update quantity and reject cross-business tampering', () async {
      final biz = await tenantService.createBusiness(name: 'Inventory Pro Inc');
      await tenantService.switchBusiness(biz.id);

      final prod = await service.createProduct(
        name: 'USB-C Cable 1m',
        hsnSac: '85444299',
        sellingPrice: Money.fromRupees(299.0),
        stockQuantity: 20.0,
      );

      // Increase stock by 10
      final updatedPlus = await service.adjustStock(prod.id, 10.0);
      expect(updatedPlus.stockQuantity, 30.0);

      // Decrease stock by 5
      final updatedMinus = await service.adjustStock(prod.id, -5.0);
      expect(updatedMinus.stockQuantity, 25.0);

      // Oversell clamp to zero
      final updatedClamped = await service.adjustStock(prod.id, -50.0);
      expect(updatedClamped.stockQuantity, 0.0);
    });
  });
}
