import 'package:flutter_test/flutter_test.dart';

import 'package:billing_app/domain/calculation_engine.dart';
import 'package:billing_app/domain/models.dart';
import 'package:billing_app/domain/money.dart';

void main() {
  const defaultSeller = Business(
    id: 'biz_01',
    name: 'Tech Solutions India Ltd',
    state: 'Kerala',
    stateCode: '32',
    gstin: '32ABCDE1234F1Z5',
  );

  const defaultBuyer = Customer(
    id: 'cust_01',
    businessId: 'biz_01',
    name: 'Acme Retail Enterprises',
    state: 'Kerala',
    stateCode: '32',
    gstin: '32XYZAB5678C1Z2',
  );

  group('Phase 5 — Financial Calculation Engine & 30 Exhaustive Scenarios', () {
    // ------------------------------------------------------------------------
    // Scenario 1: Basic Single Item Tax-Exclusive (Intra-State 18%)
    // ------------------------------------------------------------------------
    test('Scenario 01: Single item tax exclusive (Intra-State 18%: 9% CGST + 9% SGST)', () {
      final inv = FinancialCalculationEngine.calculateInvoice(
        id: 'inv_s1',
        businessId: 'biz_01',
        invoiceNumber: 'INV-2026-001',
        financialYear: '2026-2027',
        date: '16/09/2026',
        input: const InvoiceCalculationInput(
          seller: defaultSeller,
          buyer: defaultBuyer,
          placeOfSupplyCode: '32',
          dueDate: '30/09/2026',
          items: [
            LineItemCalculationInput(
              name: 'IT Support Services',
              quantity: 1,
              unitPrice: 10000.0,
              gstRate: 18.0,
            ),
          ],
        ),
      );

      expect(inv.subtotal.inRupees, 10000.0);
      expect(inv.taxableAmount.inRupees, 10000.0);
      expect(inv.totalCgst.inRupees, 900.0);
      expect(inv.totalSgst.inRupees, 900.0);
      expect(inv.totalIgst.inRupees, 0.0);
      expect(inv.totalTax.inRupees, 1800.0);
      expect(inv.grandTotal.inRupees, 11800.0);
      expect(inv.amountDue.inRupees, 11800.0);
    });

    // ------------------------------------------------------------------------
    // Scenario 2: Single Item Tax-Inclusive Backward Deduction (Intra-State 18%)
    // ------------------------------------------------------------------------
    test('Scenario 02: Single item tax inclusive reverse extraction (Intra-State 18%)', () {
      final inv = FinancialCalculationEngine.calculateInvoice(
        id: 'inv_s2',
        businessId: 'biz_01',
        invoiceNumber: 'INV-2026-002',
        financialYear: '2026-2027',
        date: '16/09/2026',
        input: const InvoiceCalculationInput(
          seller: defaultSeller,
          buyer: defaultBuyer,
          placeOfSupplyCode: '32',
          dueDate: '30/09/2026',
          items: [
            LineItemCalculationInput(
              name: 'Retail Software Bundle (MRP inclusive)',
              quantity: 1,
              unitPrice: 11800.0,
              isTaxInclusive: true,
              gstRate: 18.0,
            ),
          ],
        ),
      );

      expect(inv.subtotal.inRupees, 11800.0);
      expect(inv.taxableAmount.inRupees, 10000.0);
      expect(inv.totalCgst.inRupees, 900.0);
      expect(inv.totalSgst.inRupees, 900.0);
      expect(inv.totalTax.inRupees, 1800.0);
      expect(inv.grandTotal.inRupees, 11800.0);
    });

    // ------------------------------------------------------------------------
    // Scenario 3: Inter-State Supply (100% IGST, 0% CGST/SGST)
    // ------------------------------------------------------------------------
    test('Scenario 03: Inter-State supply (Kerala to Maharashtra: 100% IGST)', () {
      final inv = FinancialCalculationEngine.calculateInvoice(
        id: 'inv_s3',
        businessId: 'biz_01',
        invoiceNumber: 'INV-2026-003',
        financialYear: '2026-2027',
        date: '16/09/2026',
        input: const InvoiceCalculationInput(
          seller: defaultSeller, // State 32 (Kerala)
          buyer: defaultBuyer,
          placeOfSupplyCode: '27', // State 27 (Maharashtra)
          dueDate: '30/09/2026',
          items: [
            LineItemCalculationInput(
              name: 'Dedicated Cloud Server Hosting',
              quantity: 2,
              unitPrice: 25000.0,
              gstRate: 18.0,
            ),
          ],
        ),
      );

      expect(inv.isInterState, isTrue);
      expect(inv.subtotal.inRupees, 50000.0);
      expect(inv.taxableAmount.inRupees, 50000.0);
      expect(inv.totalCgst.inRupees, 0.0);
      expect(inv.totalSgst.inRupees, 0.0);
      expect(inv.totalIgst.inRupees, 9000.0);
      expect(inv.totalTax.inRupees, 9000.0);
      expect(inv.grandTotal.inRupees, 59000.0);
    });

    // ------------------------------------------------------------------------
    // Scenario 4: Reverse Charge Mechanism (RCM)
    // ------------------------------------------------------------------------
    test('Scenario 04: Reverse Charge Mechanism (seller tax = 0, buyer liable)', () {
      final inv = FinancialCalculationEngine.calculateInvoice(
        id: 'inv_s4',
        businessId: 'biz_01',
        invoiceNumber: 'INV-2026-004',
        financialYear: '2026-2027',
        date: '16/09/2026',
        input: const InvoiceCalculationInput(
          seller: defaultSeller,
          buyer: defaultBuyer,
          placeOfSupplyCode: '32',
          isReverseCharge: true,
          dueDate: '30/09/2026',
          items: [
            LineItemCalculationInput(
              name: 'Legal & Advocacy Consultancy',
              quantity: 1,
              unitPrice: 50000.0,
              gstRate: 18.0,
            ),
          ],
        ),
      );

      expect(inv.isReverseCharge, isTrue);
      expect(inv.subtotal.inRupees, 50000.0);
      expect(inv.taxableAmount.inRupees, 50000.0);
      expect(inv.totalTax.inRupees, 0.0); // Seller does not collect GST on RCM
      expect(inv.grandTotal.inRupees, 50000.0);
    });

    // ------------------------------------------------------------------------
    // Scenario 5: Line Item Percentage Discount
    // ------------------------------------------------------------------------
    test('Scenario 05: Line item percentage discount (15% off gross)', () {
      final inv = FinancialCalculationEngine.calculateInvoice(
        id: 'inv_s5',
        businessId: 'biz_01',
        invoiceNumber: 'INV-2026-005',
        financialYear: '2026-2027',
        date: '16/09/2026',
        input: const InvoiceCalculationInput(
          seller: defaultSeller,
          buyer: defaultBuyer,
          placeOfSupplyCode: '32',
          dueDate: '30/09/2026',
          items: [
            LineItemCalculationInput(
              name: 'Annual Software License',
              quantity: 1,
              unitPrice: 20000.0,
              discountPercent: 15.0, // ₹3,000 discount
              gstRate: 18.0,
            ),
          ],
        ),
      );

      expect(inv.subtotal.inRupees, 20000.0);
      expect(inv.totalDiscount.inRupees, 3000.0);
      expect(inv.taxableAmount.inRupees, 17000.0);
      expect(inv.totalCgst.inRupees, 1530.0);
      expect(inv.totalSgst.inRupees, 1530.0);
      expect(inv.grandTotal.inRupees, 20060.0);
    });

    // ------------------------------------------------------------------------
    // Scenario 6: Line Item Fixed Amount Discount
    // ------------------------------------------------------------------------
    test('Scenario 06: Line item fixed amount discount (₹2,500 flat discount)', () {
      final inv = FinancialCalculationEngine.calculateInvoice(
        id: 'inv_s6',
        businessId: 'biz_01',
        invoiceNumber: 'INV-2026-006',
        financialYear: '2026-2027',
        date: '16/09/2026',
        input: const InvoiceCalculationInput(
          seller: defaultSeller,
          buyer: defaultBuyer,
          placeOfSupplyCode: '32',
          dueDate: '30/09/2026',
          items: [
            LineItemCalculationInput(
              name: 'Workstation Setup Services',
              quantity: 2,
              unitPrice: 10000.0, // Gross = 20,000
              discountAmount: 2500.0, // Taxable = 17,500
              gstRate: 18.0,
            ),
          ],
        ),
      );

      expect(inv.subtotal.inRupees, 20000.0);
      expect(inv.totalDiscount.inRupees, 2500.0);
      expect(inv.taxableAmount.inRupees, 17500.0);
      expect(inv.totalCgst.inRupees, 1575.0);
      expect(inv.totalSgst.inRupees, 1575.0);
      expect(inv.grandTotal.inRupees, 20650.0);
    });

    // ------------------------------------------------------------------------
    // Scenario 7: Compound Line Item Discount (Clamped to Gross Base)
    // ------------------------------------------------------------------------
    test('Scenario 07: Line item discount exceeding item total is clamped', () {
      final item = FinancialCalculationEngine.calculateLineItem(
        input: const LineItemCalculationInput(
          name: 'Special Promotional Trial',
          quantity: 1,
          unitPrice: 5000.0,
          discountAmount: 8000.0, // Exceeds ₹5,000 base
          gstRate: 18.0,
        ),
        isInterState: false,
        isReverseCharge: false,
      );

      expect(item.discountAmount.inRupees, 5000.0); // Clamped to ₹5,000
      expect(item.taxableAmount.inRupees, 0.0);
      expect(item.lineTotal.inRupees, 0.0);
    });

    // ------------------------------------------------------------------------
    // Scenario 8: Invoice-Level Percentage Discount Distributed Across Brackets
    // ------------------------------------------------------------------------
    test('Scenario 08: Invoice-level percentage discount (10% invoice discount)', () {
      final inv = FinancialCalculationEngine.calculateInvoice(
        id: 'inv_s8',
        businessId: 'biz_01',
        invoiceNumber: 'INV-2026-008',
        financialYear: '2026-2027',
        date: '16/09/2026',
        input: const InvoiceCalculationInput(
          seller: defaultSeller,
          buyer: defaultBuyer,
          placeOfSupplyCode: '32',
          dueDate: '30/09/2026',
          invoiceDiscountPercent: 10.0, // 10% on 30,000 = 3,000 discount
          items: [
            LineItemCalculationInput(
              name: 'Enterprise Consulting Service',
              quantity: 1,
              unitPrice: 30000.0,
              gstRate: 18.0,
            ),
          ],
        ),
      );

      expect(inv.subtotal.inRupees, 30000.0);
      expect(inv.invoiceDiscountAmount.inRupees, 3000.0);
      expect(inv.taxableAmount.inRupees, 27000.0);
      expect(inv.totalCgst.inRupees, 2430.0);
      expect(inv.totalSgst.inRupees, 2430.0);
      expect(inv.grandTotal.inRupees, 31860.0);
    });

    // ------------------------------------------------------------------------
    // Scenario 9: Invoice-Level Fixed Amount Discount
    // ------------------------------------------------------------------------
    test('Scenario 09: Invoice-level fixed amount discount (₹5,000 flat voucher)', () {
      final inv = FinancialCalculationEngine.calculateInvoice(
        id: 'inv_s9',
        businessId: 'biz_01',
        invoiceNumber: 'INV-2026-009',
        financialYear: '2026-2027',
        date: '16/09/2026',
        input: const InvoiceCalculationInput(
          seller: defaultSeller,
          buyer: defaultBuyer,
          placeOfSupplyCode: '32',
          dueDate: '30/09/2026',
          invoiceDiscountAmount: 5000.0, // ₹5,000 flat discount
          items: [
            LineItemCalculationInput(
              name: 'Cloud Infrastructure Migration',
              quantity: 1,
              unitPrice: 45000.0,
              gstRate: 18.0,
            ),
          ],
        ),
      );

      expect(inv.subtotal.inRupees, 45000.0);
      expect(inv.invoiceDiscountAmount.inRupees, 5000.0);
      expect(inv.taxableAmount.inRupees, 40000.0);
      expect(inv.totalCgst.inRupees, 3600.0);
      expect(inv.totalSgst.inRupees, 3600.0);
      expect(inv.grandTotal.inRupees, 47200.0);
    });

    // ------------------------------------------------------------------------
    // Scenario 10: Multi-Slab Invoice (0%, 5%, 12%, 18%, 28%)
    // ------------------------------------------------------------------------
    test('Scenario 10: Multi-slab invoice containing items with 0%, 5%, 12%, 18%, and 28% GST', () {
      final inv = FinancialCalculationEngine.calculateInvoice(
        id: 'inv_s10',
        businessId: 'biz_01',
        invoiceNumber: 'INV-2026-010',
        financialYear: '2026-2027',
        date: '16/09/2026',
        input: const InvoiceCalculationInput(
          seller: defaultSeller,
          buyer: defaultBuyer,
          placeOfSupplyCode: '32',
          dueDate: '30/09/2026',
          items: [
            LineItemCalculationInput(
              name: 'Exempt Food Grain Goods',
              quantity: 1,
              unitPrice: 1000.0,
              gstRate: 0.0,
            ),
            LineItemCalculationInput(
              name: 'Packaged Tea Supplies',
              quantity: 1,
              unitPrice: 2000.0,
              gstRate: 5.0, // Tax = 100 (50 CGST + 50 SGST)
            ),
            LineItemCalculationInput(
              name: 'Apparel & Uniforms',
              quantity: 1,
              unitPrice: 3000.0,
              gstRate: 12.0, // Tax = 360 (180 CGST + 180 SGST)
            ),
            LineItemCalculationInput(
              name: 'IT Consultancy',
              quantity: 1,
              unitPrice: 10000.0,
              gstRate: 18.0, // Tax = 1800 (900 CGST + 900 SGST)
            ),
            LineItemCalculationInput(
              name: 'Air Conditioner Appliance',
              quantity: 1,
              unitPrice: 20000.0,
              gstRate: 28.0, // Tax = 5600 (2800 CGST + 2800 SGST)
            ),
          ],
        ),
      );

      // Subtotal: 1000 + 2000 + 3000 + 10000 + 20000 = 36,000
      expect(inv.subtotal.inRupees, 36000.0);
      expect(inv.taxableAmount.inRupees, 36000.0);
      // CGST = 0 + 50 + 180 + 900 + 2800 = 3930
      expect(inv.totalCgst.inRupees, 3930.0);
      expect(inv.totalSgst.inRupees, 3930.0);
      expect(inv.totalTax.inRupees, 7860.0);
      expect(inv.grandTotal.inRupees, 43860.0);
    });

    // ------------------------------------------------------------------------
    // Scenario 11: Statutory Cess on Luxury Goods (12% Cess)
    // ------------------------------------------------------------------------
    test('Scenario 11: Statutory Cess on luxury item (28% GST + 12% Cess)', () {
      final inv = FinancialCalculationEngine.calculateInvoice(
        id: 'inv_s11',
        businessId: 'biz_01',
        invoiceNumber: 'INV-2026-011',
        financialYear: '2026-2027',
        date: '16/09/2026',
        input: const InvoiceCalculationInput(
          seller: defaultSeller,
          buyer: defaultBuyer,
          placeOfSupplyCode: '32',
          dueDate: '30/09/2026',
          items: [
            LineItemCalculationInput(
              name: 'Luxury SUV Automotive Part',
              quantity: 1,
              unitPrice: 100000.0,
              gstRate: 28.0,
              cessRate: 12.0,
            ),
          ],
        ),
      );

      expect(inv.subtotal.inRupees, 100000.0);
      expect(inv.taxableAmount.inRupees, 100000.0);
      expect(inv.totalCgst.inRupees, 14000.0);
      expect(inv.totalSgst.inRupees, 14000.0);
      expect(inv.totalCess.inRupees, 12000.0);
      expect(inv.totalTax.inRupees, 40000.0);
      expect(inv.grandTotal.inRupees, 140000.0);
    });

    // ------------------------------------------------------------------------
    // Scenario 12: Fractional Quantities
    // ------------------------------------------------------------------------
    test('Scenario 12: Fractional quantities (2.750 kg @ ₹450.50/kg with 5% GST)', () {
      final inv = FinancialCalculationEngine.calculateInvoice(
        id: 'inv_s12',
        businessId: 'biz_01',
        invoiceNumber: 'INV-2026-012',
        financialYear: '2026-2027',
        date: '16/09/2026',
        input: const InvoiceCalculationInput(
          seller: defaultSeller,
          buyer: defaultBuyer,
          placeOfSupplyCode: '32',
          dueDate: '30/09/2026',
          items: [
            LineItemCalculationInput(
              name: 'Specialty Coffee Beans',
              quantity: 2.75,
              unit: 'Kg',
              unitPrice: 450.50, // Gross = 2.75 * 450.50 = 1238.875 -> 1238.88
              gstRate: 5.0,
            ),
          ],
        ),
      );

      expect(inv.subtotal.inRupees, 1238.88);
      expect(inv.taxableAmount.inRupees, 1238.88);
      // 5% GST = 61.944 -> 30.97 CGST + 30.97 SGST = 61.94
      expect(inv.totalTax.inRupees, 61.94);
      // Unrounded total = 1238.88 + 61.94 = 1300.82 -> rounds to 1301.00 (+0.18 roundOff)
      expect(inv.grandTotal.inRupees, 1301.00);
      expect(inv.roundOff.inRupees, 0.18);
    });

    // ------------------------------------------------------------------------
    // Scenario 13: Statutory Round-Off (Round-Up scenario: .55 -> +0.45)
    // ------------------------------------------------------------------------
    test('Scenario 13: Statutory round-off rounding up (total .55 rounds to next rupee)', () {
      final inv = FinancialCalculationEngine.calculateInvoice(
        id: 'inv_s13',
        businessId: 'biz_01',
        invoiceNumber: 'INV-2026-013',
        financialYear: '2026-2027',
        date: '16/09/2026',
        input: const InvoiceCalculationInput(
          seller: defaultSeller,
          buyer: defaultBuyer,
          placeOfSupplyCode: '32',
          dueDate: '30/09/2026',
          enableRoundOff: true,
          items: [
            LineItemCalculationInput(
              name: 'Custom Fabricated Hardware',
              quantity: 1,
              unitPrice: 100.55,
              gstRate: 0.0,
            ),
          ],
        ),
      );

      expect(inv.taxableAmount.inRupees, 100.55);
      expect(inv.roundOff.inRupees, 0.45);
      expect(inv.grandTotal.inRupees, 101.00);
    });

    // ------------------------------------------------------------------------
    // Scenario 14: Statutory Round-Off (Round-Down scenario: .40 -> -0.40)
    // ------------------------------------------------------------------------
    test('Scenario 14: Statutory round-off rounding down (total .40 rounds to current rupee)', () {
      final inv = FinancialCalculationEngine.calculateInvoice(
        id: 'inv_s14',
        businessId: 'biz_01',
        invoiceNumber: 'INV-2026-014',
        financialYear: '2026-2027',
        date: '16/09/2026',
        input: const InvoiceCalculationInput(
          seller: defaultSeller,
          buyer: defaultBuyer,
          placeOfSupplyCode: '32',
          dueDate: '30/09/2026',
          enableRoundOff: true,
          items: [
            LineItemCalculationInput(
              name: 'Precision Metal Bushing',
              quantity: 1,
              unitPrice: 100.40,
              gstRate: 0.0,
            ),
          ],
        ),
      );

      expect(inv.taxableAmount.inRupees, 100.40);
      expect(inv.roundOff.inRupees, -0.40);
      expect(inv.grandTotal.inRupees, 100.00);
    });

    // ------------------------------------------------------------------------
    // Scenario 15: Round-Off Disabled Mode
    // ------------------------------------------------------------------------
    test('Scenario 15: Round-off disabled mode preserves exact unrounded paise', () {
      final inv = FinancialCalculationEngine.calculateInvoice(
        id: 'inv_s15',
        businessId: 'biz_01',
        invoiceNumber: 'INV-2026-015',
        financialYear: '2026-2027',
        date: '16/09/2026',
        input: const InvoiceCalculationInput(
          seller: defaultSeller,
          buyer: defaultBuyer,
          placeOfSupplyCode: '32',
          dueDate: '30/09/2026',
          enableRoundOff: false, // Disabled
          items: [
            LineItemCalculationInput(
              name: 'Micro Electronic Component',
              quantity: 1,
              unitPrice: 125.75,
              gstRate: 18.0, // Tax = 22.64
            ),
          ],
        ),
      );

      expect(inv.roundOff.paise, 0);
      expect(inv.grandTotal.inRupees, 148.39);
    });

    // ------------------------------------------------------------------------
    // Scenario 16: Partial Payment Settlement Ledger
    // ------------------------------------------------------------------------
    test('Scenario 16: Partial payment settlement ledger and balance due', () {
      final inv = FinancialCalculationEngine.calculateInvoice(
        id: 'inv_s16',
        businessId: 'biz_01',
        invoiceNumber: 'INV-2026-016',
        financialYear: '2026-2027',
        date: '16/09/2026',
        input: InvoiceCalculationInput(
          seller: defaultSeller,
          buyer: defaultBuyer,
          placeOfSupplyCode: '32',
          dueDate: '30/09/2026',
          isFinalized: true,
          items: [
            const LineItemCalculationInput(
              name: 'Quarterly Maintenance Retainer',
              quantity: 1,
              unitPrice: 50000.0,
              gstRate: 0.0,
            ),
          ],
          paymentsReceived: [Money.fromRupees(15000.0)],
        ),
      );

      expect(inv.status, InvoiceLifecycleStatus.partiallyPaid);
      expect(inv.amountPaid.inRupees, 15000.0);
      expect(inv.amountDue.inRupees, 35000.0);
    });

    // ------------------------------------------------------------------------
    // Scenario 17: Full Payment Settlement Ledger
    // ------------------------------------------------------------------------
    test('Scenario 17: Full payment settlement ledger (balance due = ₹0.00, status paid)', () {
      final inv = FinancialCalculationEngine.calculateInvoice(
        id: 'inv_s17',
        businessId: 'biz_01',
        invoiceNumber: 'INV-2026-017',
        financialYear: '2026-2027',
        date: '16/09/2026',
        input: InvoiceCalculationInput(
          seller: defaultSeller,
          buyer: defaultBuyer,
          placeOfSupplyCode: '32',
          dueDate: '30/09/2026',
          isFinalized: true,
          items: [
            const LineItemCalculationInput(
              name: 'Consulting Sprint Delivery',
              quantity: 1,
              unitPrice: 60000.0,
              gstRate: 0.0,
            ),
          ],
          paymentsReceived: [Money.fromRupees(60000.0)],
        ),
      );

      expect(inv.status, InvoiceLifecycleStatus.paid);
      expect(inv.amountPaid.inRupees, 60000.0);
      expect(inv.amountDue.inRupees, 0.0);
      expect(inv.isSettled, isTrue);
    });

    // ------------------------------------------------------------------------
    // Scenario 18: Multiple Partial Payments Installment Ledger
    // ------------------------------------------------------------------------
    test('Scenario 18: Multiple partial payments installment ledger test (3 installments)', () {
      final inv = FinancialCalculationEngine.calculateInvoice(
        id: 'inv_s18',
        businessId: 'biz_01',
        invoiceNumber: 'INV-2026-018',
        financialYear: '2026-2027',
        date: '16/09/2026',
        input: InvoiceCalculationInput(
          seller: defaultSeller,
          buyer: defaultBuyer,
          placeOfSupplyCode: '32',
          dueDate: '30/09/2026',
          isFinalized: true,
          items: [
            const LineItemCalculationInput(
              name: 'Full Stack App Development Milestone',
              quantity: 1,
              unitPrice: 100000.0,
              gstRate: 0.0,
            ),
          ],
          paymentsReceived: [
            Money.fromRupees(30000.0),
            Money.fromRupees(40000.0),
            Money.fromRupees(30000.0),
          ],
        ),
      );

      expect(inv.amountPaid.inRupees, 100000.0);
      expect(inv.amountDue.inRupees, 0.0);
      expect(inv.status, InvoiceLifecycleStatus.paid);
    });

    // ------------------------------------------------------------------------
    // Scenario 19: Overpayment Clamping (Balance Due Cannot Be Negative)
    // ------------------------------------------------------------------------
    test('Scenario 19: Overpayment clamping (amountDue clamped to ₹0.00)', () {
      final inv = FinancialCalculationEngine.calculateInvoice(
        id: 'inv_s19',
        businessId: 'biz_01',
        invoiceNumber: 'INV-2026-019',
        financialYear: '2026-2027',
        date: '16/09/2026',
        input: InvoiceCalculationInput(
          seller: defaultSeller,
          buyer: defaultBuyer,
          placeOfSupplyCode: '32',
          dueDate: '30/09/2026',
          isFinalized: true,
          items: [
            const LineItemCalculationInput(
              name: 'Minor Repair Work',
              quantity: 1,
              unitPrice: 5000.0,
              gstRate: 0.0,
            ),
          ],
          paymentsReceived: [Money.fromRupees(6000.0)], // Excess ₹1,000 paid
        ),
      );

      expect(inv.amountPaid.inRupees, 6000.0);
      expect(inv.amountDue.inRupees, 0.0); // Clamped, not -1000
      expect(inv.status, InvoiceLifecycleStatus.paid);
    });

    // ------------------------------------------------------------------------
    // Scenario 20: Overdue Invoice Lifecycle Derivation
    // ------------------------------------------------------------------------
    test('Scenario 20: Overdue status derived when current date is past due date', () {
      final inv = FinancialCalculationEngine.calculateInvoice(
        id: 'inv_s20',
        businessId: 'biz_01',
        invoiceNumber: 'INV-2026-020',
        financialYear: '2026-2027',
        date: '01/01/2026',
        input: const InvoiceCalculationInput(
          seller: defaultSeller,
          buyer: defaultBuyer,
          placeOfSupplyCode: '32',
          dueDate: '15/01/2026', // Way in the past
          isFinalized: true,
          items: [
            LineItemCalculationInput(
              name: 'Overdue Subscription',
              quantity: 1,
              unitPrice: 12000.0,
              gstRate: 0.0,
            ),
          ],
        ),
      );

      expect(inv.status, InvoiceLifecycleStatus.overdue);
    });

    // ------------------------------------------------------------------------
    // Scenario 21: High-Volume Invoice Line Items (100 Line Items)
    // ------------------------------------------------------------------------
    test('Scenario 21: High-volume invoice line items (100 distinct items aggregation)', () {
      final items = List.generate(
        100,
        (i) => LineItemCalculationInput(
          name: 'Item ${i + 1}',
          quantity: 2,
          unitPrice: 100.0, // 200 per item -> Total = 20,000
          gstRate: 18.0, // 18% on 200 = 36 per item -> Total Tax = 3,600
        ),
      );

      final inv = FinancialCalculationEngine.calculateInvoice(
        id: 'inv_s21',
        businessId: 'biz_01',
        invoiceNumber: 'INV-2026-021',
        financialYear: '2026-2027',
        date: '16/09/2026',
        input: InvoiceCalculationInput(
          seller: defaultSeller,
          buyer: defaultBuyer,
          placeOfSupplyCode: '32',
          dueDate: '30/09/2026',
          items: items,
        ),
      );

      expect(inv.items.length, 100);
      expect(inv.subtotal.inRupees, 20000.0);
      expect(inv.taxableAmount.inRupees, 20000.0);
      expect(inv.totalCgst.inRupees, 1800.0);
      expect(inv.totalSgst.inRupees, 1800.0);
      expect(inv.totalTax.inRupees, 3600.0);
      expect(inv.grandTotal.inRupees, 23600.0);
    });

    // ------------------------------------------------------------------------
    // Scenario 22: Large-Scale Enterprise Invoice (₹10 Crores Transaction)
    // ------------------------------------------------------------------------
    test('Scenario 22: Large-scale enterprise invoice (₹10,00,00,000 with exact paise)', () {
      final inv = FinancialCalculationEngine.calculateInvoice(
        id: 'inv_s22',
        businessId: 'biz_01',
        invoiceNumber: 'INV-2026-022',
        financialYear: '2026-2027',
        date: '16/09/2026',
        input: const InvoiceCalculationInput(
          seller: defaultSeller,
          buyer: defaultBuyer,
          placeOfSupplyCode: '32',
          dueDate: '30/09/2026',
          items: [
            LineItemCalculationInput(
              name: 'Enterprise Data Center Construction',
              quantity: 1,
              unitPrice: 100000000.0, // ₹10 Crores
              gstRate: 18.0,
            ),
          ],
        ),
      );

      expect(inv.subtotal.inRupees, 100000000.0);
      expect(inv.totalCgst.inRupees, 9000000.0); // ₹90 Lakhs CGST
      expect(inv.totalSgst.inRupees, 9000000.0); // ₹90 Lakhs SGST
      expect(inv.grandTotal.inRupees, 118000000.0); // ₹11.80 Crores
      expect(inv.grandTotal.paise, 11800000000); // 11.8 billion paise
    });

    // ------------------------------------------------------------------------
    // Scenario 23: Small Value / Micro-Paise Transaction
    // ------------------------------------------------------------------------
    test('Scenario 23: Small value micro transaction (₹0.50 unit price with 18% GST)', () {
      final inv = FinancialCalculationEngine.calculateInvoice(
        id: 'inv_s23',
        businessId: 'biz_01',
        invoiceNumber: 'INV-2026-023',
        financialYear: '2026-2027',
        date: '16/09/2026',
        input: const InvoiceCalculationInput(
          seller: defaultSeller,
          buyer: defaultBuyer,
          placeOfSupplyCode: '32',
          dueDate: '30/09/2026',
          enableRoundOff: false,
          items: [
            LineItemCalculationInput(
              name: 'SMS Notification Credit',
              quantity: 1,
              unitPrice: 0.50,
              gstRate: 18.0,
            ),
          ],
        ),
      );

      expect(inv.subtotal.inRupees, 0.50);
      // Under Section 170 of CGST Act, CGST and SGST heads round independently:
      // 9% on 50 paise = 4.5 paise -> rounds to 5 paise CGST and 5 paise SGST -> 10 paise total tax
      expect(inv.totalCgst.paise, 5);
      expect(inv.totalSgst.paise, 5);
      expect(inv.totalTax.paise, 10);
      expect(inv.grandTotal.paise, 60); // ₹0.60
    });

    // ------------------------------------------------------------------------
    // Scenario 24: Zero-Rated / Nil-Rated Supply (0% GST)
    // ------------------------------------------------------------------------
    test('Scenario 24: Zero-rated supply (0% GST)', () {
      final inv = FinancialCalculationEngine.calculateInvoice(
        id: 'inv_s24',
        businessId: 'biz_01',
        invoiceNumber: 'INV-2026-024',
        financialYear: '2026-2027',
        date: '16/09/2026',
        input: const InvoiceCalculationInput(
          seller: defaultSeller,
          buyer: defaultBuyer,
          placeOfSupplyCode: '32',
          dueDate: '30/09/2026',
          items: [
            LineItemCalculationInput(
              name: 'Organic Unbranded Fresh Produce',
              quantity: 5,
              unitPrice: 200.0,
              gstRate: 0.0,
            ),
          ],
        ),
      );

      expect(inv.subtotal.inRupees, 1000.0);
      expect(inv.totalTax.inRupees, 0.0);
      expect(inv.grandTotal.inRupees, 1000.0);
    });

    // ------------------------------------------------------------------------
    // Scenario 25: Export / Overseas Supply (Place of Supply 96: Foreign)
    // ------------------------------------------------------------------------
    test('Scenario 25: Export / Overseas supply (treated as inter-state supply)', () {
      final inv = FinancialCalculationEngine.calculateInvoice(
        id: 'inv_s25',
        businessId: 'biz_01',
        invoiceNumber: 'INV-2026-025',
        financialYear: '2026-2027',
        date: '16/09/2026',
        input: const InvoiceCalculationInput(
          seller: defaultSeller,
          buyer: Customer(
            id: 'cust_export',
            businessId: 'biz_01',
            name: 'US Global Client Inc',
            state: 'Other Territory',
            stateCode: '96', // Other Territory / Export
            gstType: GstRegistrationType.overseas,
          ),
          placeOfSupplyCode: '96',
          dueDate: '30/09/2026',
          items: [
            LineItemCalculationInput(
              name: 'Offshore Software Development',
              quantity: 1,
              unitPrice: 250000.0,
              gstRate: 18.0,
            ),
          ],
        ),
      );

      expect(inv.isInterState, isTrue);
      expect(inv.totalCgst.inRupees, 0.0);
      expect(inv.totalSgst.inRupees, 0.0);
      expect(inv.totalIgst.inRupees, 45000.0);
      expect(inv.grandTotal.inRupees, 295000.0);
    });

    // ------------------------------------------------------------------------
    // Scenario 26: Union Territory GST (UTGST: Chandigarh State Code 04)
    // ------------------------------------------------------------------------
    test('Scenario 26: Union Territory GST (Intra-UT supply: Chandigarh 04 to 04)', () {
      const utSeller = Business(
        id: 'biz_ut',
        name: 'Chandigarh Tech Hub',
        state: 'Chandigarh',
        stateCode: '04',
      );

      const utBuyer = Customer(
        id: 'cust_ut',
        businessId: 'biz_ut',
        name: 'Sector 17 Retailer',
        state: 'Chandigarh',
        stateCode: '04',
      );

      final inv = FinancialCalculationEngine.calculateInvoice(
        id: 'inv_s26',
        businessId: 'biz_ut',
        invoiceNumber: 'INV-2026-026',
        financialYear: '2026-2027',
        date: '16/09/2026',
        input: const InvoiceCalculationInput(
          seller: utSeller,
          buyer: utBuyer,
          placeOfSupplyCode: '04',
          dueDate: '30/09/2026',
          items: [
            LineItemCalculationInput(
              name: 'Local Networking Hardware',
              quantity: 1,
              unitPrice: 10000.0,
              gstRate: 18.0,
            ),
          ],
        ),
      );

      expect(inv.isInterState, isFalse);
      expect(inv.totalCgst.inRupees, 900.0);
      expect(inv.totalSgst.inRupees, 900.0); // Acts as UTGST
      expect(inv.totalIgst.inRupees, 0.0);
      expect(inv.grandTotal.inRupees, 11800.0);
    });

    // ------------------------------------------------------------------------
    // Scenario 27: Special Economic Zone (SEZ) Supply Treated as Inter-State
    // ------------------------------------------------------------------------
    test('Scenario 27: Special Economic Zone (SEZ) supply with IGST', () {
      final inv = FinancialCalculationEngine.calculateInvoice(
        id: 'inv_s27',
        businessId: 'biz_01',
        invoiceNumber: 'INV-2026-027',
        financialYear: '2026-2027',
        date: '16/09/2026',
        input: const InvoiceCalculationInput(
          seller: defaultSeller,
          buyer: defaultBuyer,
          placeOfSupplyCode: '27', // SEZ unit located in Maharashtra
          dueDate: '30/09/2026',
          items: [
            LineItemCalculationInput(
              name: 'SEZ Software Consulting',
              quantity: 1,
              unitPrice: 80000.0,
              gstRate: 18.0,
            ),
          ],
        ),
      );

      expect(inv.isInterState, isTrue);
      expect(inv.totalIgst.inRupees, 14400.0);
      expect(inv.grandTotal.inRupees, 94400.0);
    });

    // ------------------------------------------------------------------------
    // Scenario 28: Mixed Tax-Inclusive and Tax-Exclusive Items
    // ------------------------------------------------------------------------
    test('Scenario 28: Mixed tax-inclusive and tax-exclusive items in same invoice', () {
      final inv = FinancialCalculationEngine.calculateInvoice(
        id: 'inv_s28',
        businessId: 'biz_01',
        invoiceNumber: 'INV-2026-028',
        financialYear: '2026-2027',
        date: '16/09/2026',
        input: const InvoiceCalculationInput(
          seller: defaultSeller,
          buyer: defaultBuyer,
          placeOfSupplyCode: '32',
          dueDate: '30/09/2026',
          items: [
            LineItemCalculationInput(
              name: 'Exclusive Consulting Hour',
              quantity: 1,
              unitPrice: 1000.0,
              isTaxInclusive: false, // 1000 + 180 tax = 1180
              gstRate: 18.0,
            ),
            LineItemCalculationInput(
              name: 'Inclusive Retail Product',
              quantity: 1,
              unitPrice: 1180.0,
              isTaxInclusive: true, // 1000 base + 180 tax = 1180
              gstRate: 18.0,
            ),
          ],
        ),
      );

      expect(inv.subtotal.inRupees, 2180.0);
      expect(inv.taxableAmount.inRupees, 2000.0);
      expect(inv.totalCgst.inRupees, 180.0);
      expect(inv.totalSgst.inRupees, 180.0);
      expect(inv.totalTax.inRupees, 360.0);
      expect(inv.grandTotal.inRupees, 2360.0);
    });

    // ------------------------------------------------------------------------
    // Scenario 29: Invoice Discount Exceeding Taxable Total (Clamped)
    // ------------------------------------------------------------------------
    test('Scenario 29: Invoice discount exceeding taxable amount is clamped', () {
      final inv = FinancialCalculationEngine.calculateInvoice(
        id: 'inv_s29',
        businessId: 'biz_01',
        invoiceNumber: 'INV-2026-029',
        financialYear: '2026-2027',
        date: '16/09/2026',
        input: const InvoiceCalculationInput(
          seller: defaultSeller,
          buyer: defaultBuyer,
          placeOfSupplyCode: '32',
          dueDate: '30/09/2026',
          invoiceDiscountAmount: 50000.0, // Exceeds ₹10,000 base
          items: [
            LineItemCalculationInput(
              name: 'Standard Audit',
              quantity: 1,
              unitPrice: 10000.0,
              gstRate: 18.0,
            ),
          ],
        ),
      );

      expect(inv.invoiceDiscountAmount.inRupees, 10000.0); // Clamped
      expect(inv.taxableAmount.inRupees, 0.0);
      expect(inv.totalTax.inRupees, 0.0);
      expect(inv.grandTotal.inRupees, 0.0);
    });

    // ------------------------------------------------------------------------
    // Scenario 30: Negative, NaN, and Infinite Quantity/Price Sanitization
    // ------------------------------------------------------------------------
    test('Scenario 30: Bad inputs (NaN, Infinity, negatives) sanitized gracefully', () {
      final item = FinancialCalculationEngine.calculateLineItem(
        input: const LineItemCalculationInput(
          name: 'Anomalous Entry',
          quantity: double.nan,
          unitPrice: -500.0,
          discountPercent: 150.0,
          gstRate: -18.0,
        ),
        isInterState: false,
        isReverseCharge: false,
      );

      expect(item.quantity, 0.0);
      expect(item.unitPrice.inRupees, 0.0);
      expect(item.grossAmount.inRupees, 0.0);
      expect(item.taxableAmount.inRupees, 0.0);
      expect(item.lineTotal.inRupees, 0.0);
    });
  });
}
