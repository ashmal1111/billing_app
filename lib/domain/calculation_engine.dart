import 'gst_engine.dart';
import 'models.dart';
import 'money.dart';

/// Calculation Input for a single Line Item
class LineItemCalculationInput {
  final String? productId;
  final String name;
  final String description;
  final String hsnSac;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double discountPercent;
  final double discountAmount;
  final bool isTaxInclusive;
  final double gstRate;
  final double cessRate;

  const LineItemCalculationInput({
    this.productId,
    required this.name,
    this.description = '',
    this.hsnSac = '',
    required this.quantity,
    this.unit = 'Pcs',
    required this.unitPrice,
    this.discountPercent = 0.0,
    this.discountAmount = 0.0,
    this.isTaxInclusive = false,
    this.gstRate = 18.0,
    this.cessRate = 0.0,
  });
}

/// Calculation Input for an entire Invoice
class InvoiceCalculationInput {
  final Business seller;
  final Customer buyer;
  final String placeOfSupplyCode;
  final bool isReverseCharge;
  final List<LineItemCalculationInput> items;
  final double invoiceDiscountPercent;
  final double invoiceDiscountAmount;
  final bool enableRoundOff;
  final List<Money> paymentsReceived;
  final String dueDate; // DD/MM/YYYY
  final bool isFinalized;

  const InvoiceCalculationInput({
    required this.seller,
    required this.buyer,
    required this.placeOfSupplyCode,
    this.isReverseCharge = false,
    required this.items,
    this.invoiceDiscountPercent = 0.0,
    this.invoiceDiscountAmount = 0.0,
    this.enableRoundOff = true,
    this.paymentsReceived = const [],
    required this.dueDate,
    this.isFinalized = false,
  });
}

/// Production Universal Financial Calculation Engine
///
/// Single source of truth across UI, PDF Generation, Reports, and Database.
/// Guarantees exact, deterministic, penny/paise-accurate financial outputs.
class FinancialCalculationEngine {
  /// Calculate a single line item with GST decomposition
  static InvoiceLineItem calculateLineItem({
    required LineItemCalculationInput input,
    required bool isInterState,
    required bool isReverseCharge,
  }) {
    // Sanitize quantities & prices against negatives, NaN, or Infinity
    final qty = input.quantity.isNaN || input.quantity.isInfinite || input.quantity < 0
        ? 0.0
        : input.quantity;

    final unitPrice = Money.fromRupees(input.unitPrice).clampToZero();
    final grossBase = unitPrice.multiply(qty);

    // Calculate item discount
    Money itemDiscount = Money.zero;
    if (input.discountAmount > 0) {
      itemDiscount = Money.fromRupees(input.discountAmount).clampToZero();
    } else if (input.discountPercent > 0) {
      itemDiscount = grossBase.percentage(input.discountPercent);
    }
    // Discount cannot exceed base price
    if (itemDiscount.paise > grossBase.paise) {
      itemDiscount = grossBase;
    }

    final postDiscountBase = grossBase - itemDiscount;

    // GST Decomposition
    GstTaxBreakdown gst;
    if (input.isTaxInclusive) {
      gst = GstEngine.calculateFromTaxInclusive(
        grossAmount: postDiscountBase,
        gstRate: input.gstRate,
        isInterState: isInterState,
        cessRate: input.cessRate,
        isReverseCharge: isReverseCharge,
      );
    } else {
      gst = GstEngine.calculateFromTaxExclusive(
        taxableAmount: postDiscountBase,
        gstRate: input.gstRate,
        isInterState: isInterState,
        cessRate: input.cessRate,
        isReverseCharge: isReverseCharge,
      );
    }

    return InvoiceLineItem(
      productId: input.productId,
      name: input.name.trim().isEmpty ? 'Item' : input.name.trim(),
      description: input.description,
      hsnSac: input.hsnSac,
      quantity: qty,
      unit: input.unit,
      unitPrice: unitPrice,
      discountPercent: input.discountPercent,
      discountAmount: itemDiscount,
      isTaxInclusive: input.isTaxInclusive,
      gstRate: input.gstRate,
      cessRate: input.cessRate,
      grossAmount: grossBase,
      taxableAmount: gst.taxableAmount,
      cgst: gst.cgst,
      sgst: gst.sgst,
      igst: gst.igst,
      cess: gst.cess,
      lineTotal: gst.grandTotal,
    );
  }

  /// Full Invoice Calculation: sums line items, applies invoice-level discounts,
  /// statutory taxes, round-off, and derives payment balances.
  static CanonicalInvoice calculateInvoice({
    required String id,
    required String businessId,
    String? customerId,
    required String invoiceNumber,
    required String financialYear,
    InvoiceDocumentType invoiceType = InvoiceDocumentType.taxInvoice,
    required String date,
    required InvoiceCalculationInput input,
    String paymentMethod = 'UPI',
    String templateId = 'modern',
    String notes = '',
    String terms = '',
    DateTime? createdAt,
  }) {
    // 1. Determine Interstate vs Intrastate
    final isInterState = GstEngine.isInterStateSupply(
      sellerStateCode: input.seller.stateCode,
      placeOfSupplyCode: input.placeOfSupplyCode,
    );

    // 2. Evaluate all Line Items
    final evaluatedItems = input.items.map((itemInput) {
      return calculateLineItem(
        input: itemInput,
        isInterState: isInterState,
        isReverseCharge: input.isReverseCharge,
      );
    }).toList();

    // 3. Aggregate Item Totals
    Money subtotal = Money.zero;
    Money totalItemDiscounts = Money.zero;
    Money rawTaxable = Money.zero;
    Money totalCgst = Money.zero;
    Money totalSgst = Money.zero;
    Money totalIgst = Money.zero;
    Money totalCess = Money.zero;

    for (final item in evaluatedItems) {
      subtotal += item.grossAmount;
      totalItemDiscounts += item.discountAmount;
      rawTaxable += item.taxableAmount;
      totalCgst += item.cgst;
      totalSgst += item.sgst;
      totalIgst += item.igst;
      totalCess += item.cess;
    }

    // 4. Invoice-Level Discount
    Money invoiceDiscount = Money.zero;
    if (input.invoiceDiscountAmount > 0) {
      invoiceDiscount =
          Money.fromRupees(input.invoiceDiscountAmount).clampToZero();
    } else if (input.invoiceDiscountPercent > 0) {
      invoiceDiscount = rawTaxable.percentage(input.invoiceDiscountPercent);
    }
    if (invoiceDiscount.paise > rawTaxable.paise) {
      invoiceDiscount = rawTaxable;
    }

    final totalDiscount = totalItemDiscounts + invoiceDiscount;

    // Adjust taxes if invoice-level discount exists
    if (invoiceDiscount.isPositive && rawTaxable.isPositive) {
      final discountRatio = 1.0 - (invoiceDiscount.paise / rawTaxable.paise);
      totalCgst = totalCgst.multiply(discountRatio);
      totalSgst = totalSgst.multiply(discountRatio);
      totalIgst = totalIgst.multiply(discountRatio);
      totalCess = totalCess.multiply(discountRatio);
      rawTaxable = rawTaxable - invoiceDiscount;
    }

    final Money totalTax = input.isReverseCharge
        ? Money.zero
        : (totalCgst + totalSgst + totalIgst + totalCess);

    final unroundedTotal = rawTaxable + totalTax;

    // 5. Statutory Round-off to nearest Rupee
    Money roundOff = Money.zero;
    Money grandTotal = unroundedTotal;
    if (input.enableRoundOff && unroundedTotal.isPositive) {
      final roundedPaise = (unroundedTotal.inRupees.round()) * 100;
      roundOff = Money.fromPaise(roundedPaise - unroundedTotal.paise);
      grandTotal = Money.fromPaise(roundedPaise);
    }

    // 6. Payment Aggregation & Balance Due
    Money amountPaid = Money.zero;
    for (final p in input.paymentsReceived) {
      amountPaid += p;
    }

    final Money amountDue =
        (grandTotal - amountPaid).isNegative ? Money.zero : (grandTotal - amountPaid);

    // 7. Derive Canonical Status
    final status = _deriveStatus(
      isFinalized: input.isFinalized,
      grandTotal: grandTotal,
      amountPaid: amountPaid,
      amountDue: amountDue,
      dueDateStr: input.dueDate,
    );

    final state = IndianState.findByCode(input.placeOfSupplyCode);

    final now = DateTime.now();
    return CanonicalInvoice(
      id: id,
      businessId: businessId,
      customerId: customerId,
      invoiceNumber: invoiceNumber,
      financialYear: financialYear,
      invoiceType: invoiceType,
      status: status,
      date: date,
      dueDate: input.dueDate,
      seller: input.seller,
      buyer: input.buyer,
      placeOfSupply: state.name,
      placeOfSupplyCode: state.code,
      isInterState: isInterState,
      isReverseCharge: input.isReverseCharge,
      items: evaluatedItems,
      subtotal: subtotal,
      invoiceDiscountPercent: input.invoiceDiscountPercent,
      invoiceDiscountAmount: invoiceDiscount,
      totalDiscount: totalDiscount,
      taxableAmount: rawTaxable,
      totalCgst: totalCgst,
      totalSgst: totalSgst,
      totalIgst: totalIgst,
      totalCess: totalCess,
      totalTax: totalTax,
      roundOff: roundOff,
      grandTotal: grandTotal,
      amountPaid: amountPaid,
      amountDue: amountDue,
      paymentMethod: paymentMethod,
      templateId: templateId,
      notes: notes,
      terms: terms,
      createdAt: createdAt ?? now,
      updatedAt: now,
    );
  }

  /// Automatically derive life-cycle status based on balance and due date
  static InvoiceLifecycleStatus _deriveStatus({
    required bool isFinalized,
    required Money grandTotal,
    required Money amountPaid,
    required Money amountDue,
    required String dueDateStr,
  }) {
    if (!isFinalized) {
      return InvoiceLifecycleStatus.draft;
    }

    if (grandTotal.isPositive && amountDue.isZero) {
      return InvoiceLifecycleStatus.paid;
    }

    if (amountPaid.isPositive && amountDue.isPositive) {
      return InvoiceLifecycleStatus.partiallyPaid;
    }

    // Check if Overdue
    try {
      DateTime? dueDate;
      if (dueDateStr.contains('/')) {
        final parts = dueDateStr.split('/');
        if (parts.length == 3) {
          dueDate = DateTime(
            int.parse(parts[2]),
            int.parse(parts[1]),
            int.parse(parts[0]),
          );
        }
      } else {
        dueDate = DateTime.tryParse(dueDateStr);
      }

      if (dueDate != null) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
        if (today.isAfter(dueDay) && amountDue.isPositive) {
          return InvoiceLifecycleStatus.overdue;
        }
      }
    } catch (_) {}

    return InvoiceLifecycleStatus.finalized;
  }
}
