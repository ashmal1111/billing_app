import 'money.dart';


/// User Role inside a Business Workspace
enum SaaSRole {
  owner,
  admin,
  accountant,
  employee,
  viewer;

  String get displayName {
    switch (this) {
      case SaaSRole.owner:
        return 'Owner';
      case SaaSRole.admin:
        return 'Administrator';
      case SaaSRole.accountant:
        return 'Accountant';
      case SaaSRole.employee:
        return 'Staff / Employee';
      case SaaSRole.viewer:
        return 'Read-Only Viewer';
    }
  }

  bool get canCreateInvoices =>
      this == SaaSRole.owner ||
      this == SaaSRole.admin ||
      this == SaaSRole.accountant ||
      this == SaaSRole.employee;

  bool get canDeleteInvoices => this == SaaSRole.owner || this == SaaSRole.admin;

  bool get canManageSettings => this == SaaSRole.owner || this == SaaSRole.admin;

  bool get canRecordPayments =>
      this == SaaSRole.owner ||
      this == SaaSRole.admin ||
      this == SaaSRole.accountant;

  bool get canViewFinancialReports =>
      this == SaaSRole.owner ||
      this == SaaSRole.admin ||
      this == SaaSRole.accountant;
}

/// Multi-Tenant Business Profile
class Business {
  final String id;
  final String name;
  final String legalName;
  final String gstin;
  final String pan;
  final String state;
  final String stateCode; // 2-digit code e.g. "32" for Kerala, "27" for Maharashtra
  final String address;
  final String phone;
  final String whatsapp;
  final String email;
  final String website;
  final String bankName;
  final String accountNumber;
  final String ifsc;
  final String upiId;
  final String currency;
  final String invoicePrefix;

  const Business({
    required this.id,
    required this.name,
    this.legalName = '',
    this.gstin = '',
    this.pan = '',
    this.state = 'Kerala',
    this.stateCode = '32',
    this.address = '',
    this.phone = '',
    this.whatsapp = '',
    this.email = 'billing@company.com',
    this.website = '',
    this.bankName = '',
    this.accountNumber = '',
    this.ifsc = '',
    this.upiId = '',
    this.currency = '₹',
    this.invoicePrefix = 'INV-',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'legalName': legalName,
        'gstin': gstin,
        'pan': pan,
        'state': state,
        'stateCode': stateCode,
        'address': address,
        'phone': phone,
        'whatsapp': whatsapp,
        'email': email,
        'website': website,
        'bankName': bankName,
        'accountNumber': accountNumber,
        'ifsc': ifsc,
        'upiId': upiId,
        'currency': currency,
        'invoicePrefix': invoicePrefix,
      };

  factory Business.fromJson(Map<String, dynamic> json) => Business(
        id: json['id'] as String? ?? 'default_biz',
        name: json['name'] as String? ?? 'My Business',
        legalName: json['legalName'] as String? ?? '',
        gstin: json['gstin'] as String? ?? '',
        pan: json['pan'] as String? ?? '',
        state: json['state'] as String? ?? 'Kerala',
        stateCode: json['stateCode'] as String? ?? '32',
        address: json['address'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        whatsapp: json['whatsapp'] as String? ?? '',
        email: json['email'] as String? ?? 'billing@company.com',
        website: json['website'] as String? ?? '',
        bankName: json['bankName'] as String? ?? '',
        accountNumber: json['accountNumber'] as String? ?? '',
        ifsc: json['ifsc'] as String? ?? '',
        upiId: json['upiId'] as String? ?? '',
        currency: json['currency'] as String? ?? '₹',
        invoicePrefix: json['invoicePrefix'] as String? ?? 'INV-',
      );
}

/// GST Registration Types for Customers
enum GstRegistrationType {
  registered('Registered Business (Regular)'),
  unregistered('Unregistered Business'),
  composition('Composition Dealer'),
  consumer('End Consumer (B2C)'),
  overseas('Export / Overseas');

  final String label;
  const GstRegistrationType(this.label);
}

/// Customer Master Record
class Customer {
  final String id;
  final String businessId;
  final String name;
  final String companyName;
  final String phone;
  final String email;
  final String gstin;
  final String pan;
  final GstRegistrationType gstType;
  final String billingAddress;
  final String shippingAddress;
  final String state;
  final String stateCode;
  final Money creditLimit;
  final String notes;

  const Customer({
    required this.id,
    required this.businessId,
    required this.name,
    this.companyName = '',
    this.phone = '',
    this.email = '',
    this.gstin = '',
    this.pan = '',
    this.gstType = GstRegistrationType.registered,
    this.billingAddress = '',
    this.shippingAddress = '',
    this.state = 'Kerala',
    this.stateCode = '32',
    this.creditLimit = Money.zero,
    this.notes = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'businessId': businessId,
        'name': name,
        'companyName': companyName,
        'phone': phone,
        'email': email,
        'gstin': gstin,
        'pan': pan,
        'gstType': gstType.name,
        'billingAddress': billingAddress,
        'shippingAddress': shippingAddress,
        'state': state,
        'stateCode': stateCode,
        'creditLimit': creditLimit.inRupees,
        'notes': notes,
      };

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        id: json['id'] as String? ?? '',
        businessId: json['businessId'] as String? ?? '',
        name: json['name'] as String? ?? '',
        companyName: json['companyName'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        email: json['email'] as String? ?? '',
        gstin: json['gstin'] as String? ?? '',
        pan: json['pan'] as String? ?? '',
        gstType: GstRegistrationType.values.firstWhere(
          (t) => t.name == json['gstType'],
          orElse: () => GstRegistrationType.registered,
        ),
        billingAddress: json['billingAddress'] as String? ?? '',
        shippingAddress: json['shippingAddress'] as String? ?? '',
        state: json['state'] as String? ?? 'Kerala',
        stateCode: json['stateCode'] as String? ?? '32',
        creditLimit: Money.fromRupees(json['creditLimit'] as num? ?? 0),
        notes: json['notes'] as String? ?? '',
      );
}

/// Product & Service Catalog Record
class Product {
  final String id;
  final String businessId;
  final String name;
  final String sku;
  final String description;
  final String category;
  final String hsnSac;
  final String unit; // Pcs, Kg, Hours, Days, etc.
  final Money costPrice;
  final Money sellingPrice;
  final double gstRate; // 0, 5, 12, 18, 28
  final bool isTaxInclusive;
  final double stockQuantity;

  const Product({
    required this.id,
    required this.businessId,
    required this.name,
    this.sku = '',
    this.description = '',
    this.category = 'General',
    required this.hsnSac,
    this.unit = 'Pcs',
    this.costPrice = Money.zero,
    required this.sellingPrice,
    this.gstRate = 18.0,
    this.isTaxInclusive = false,
    this.stockQuantity = 0.0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'businessId': businessId,
        'name': name,
        'sku': sku,
        'description': description,
        'category': category,
        'hsnSac': hsnSac,
        'unit': unit,
        'costPrice': costPrice.inRupees,
        'sellingPrice': sellingPrice.inRupees,
        'gstRate': gstRate,
        'isTaxInclusive': isTaxInclusive,
        'stockQuantity': stockQuantity,
      };

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as String? ?? '',
        businessId: json['businessId'] as String? ?? '',
        name: json['name'] as String? ?? '',
        sku: json['sku'] as String? ?? '',
        description: json['description'] as String? ?? '',
        category: json['category'] as String? ?? 'General',
        hsnSac: json['hsnSac'] as String? ?? '998311',
        unit: json['unit'] as String? ?? 'Pcs',
        costPrice: Money.fromRupees(json['costPrice'] as num? ?? 0),
        sellingPrice: Money.fromRupees(json['sellingPrice'] as num? ?? 0),
        gstRate: (json['gstRate'] as num?)?.toDouble() ?? 18.0,
        isTaxInclusive: json['isTaxInclusive'] as bool? ?? false,
        stockQuantity: (json['stockQuantity'] as num?)?.toDouble() ?? 0.0,
      );
}

/// Evaluated Line Item in an Invoice or Estimate
class InvoiceLineItem {
  final String? productId;
  final String name;
  final String description;
  final String hsnSac;
  final double quantity;
  final String unit;
  final Money unitPrice;
  final double discountPercent;
  final Money discountAmount;
  final bool isTaxInclusive;
  final double gstRate;
  final double cessRate;

  // Evaluated values (populated by Calculation Engine)
  final Money grossAmount;
  final Money taxableAmount;
  final Money cgst;
  final Money sgst;
  final Money igst;
  final Money cess;
  final Money lineTotal;

  const InvoiceLineItem({
    this.productId,
    required this.name,
    this.description = '',
    this.hsnSac = '',
    required this.quantity,
    this.unit = 'Pcs',
    required this.unitPrice,
    this.discountPercent = 0.0,
    this.discountAmount = Money.zero,
    this.isTaxInclusive = false,
    this.gstRate = 18.0,
    this.cessRate = 0.0,
    required this.grossAmount,
    required this.taxableAmount,
    required this.cgst,
    required this.sgst,
    required this.igst,
    required this.cess,
    required this.lineTotal,
  });

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'name': name,
        'description': description,
        'hsnSac': hsnSac,
        'quantity': quantity,
        'unit': unit,
        'unitPrice': unitPrice.inRupees,
        'discountPercent': discountPercent,
        'discountAmount': discountAmount.inRupees,
        'isTaxInclusive': isTaxInclusive,
        'gstRate': gstRate,
        'cessRate': cessRate,
        'grossAmount': grossAmount.inRupees,
        'taxableAmount': taxableAmount.inRupees,
        'cgst': cgst.inRupees,
        'sgst': sgst.inRupees,
        'igst': igst.inRupees,
        'cess': cess.inRupees,
        'lineTotal': lineTotal.inRupees,
      };

  factory InvoiceLineItem.fromJson(Map<String, dynamic> json) => InvoiceLineItem(
        productId: json['productId'] as String?,
        name: json['name'] as String? ?? 'Item',
        description: json['description'] as String? ?? '',
        hsnSac: json['hsnSac'] as String? ?? '',
        quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
        unit: json['unit'] as String? ?? 'Pcs',
        unitPrice: Money.fromRupees(json['unitPrice'] as num? ?? 0),
        discountPercent: (json['discountPercent'] as num?)?.toDouble() ?? 0.0,
        discountAmount: Money.fromRupees(json['discountAmount'] as num? ?? 0),
        isTaxInclusive: json['isTaxInclusive'] as bool? ?? false,
        gstRate: (json['gstRate'] as num?)?.toDouble() ?? 18.0,
        cessRate: (json['cessRate'] as num?)?.toDouble() ?? 0.0,
        grossAmount: Money.fromRupees(json['grossAmount'] as num? ?? 0),
        taxableAmount: Money.fromRupees(json['taxableAmount'] as num? ?? 0),
        cgst: Money.fromRupees(json['cgst'] as num? ?? 0),
        sgst: Money.fromRupees(json['sgst'] as num? ?? 0),
        igst: Money.fromRupees(json['igst'] as num? ?? 0),
        cess: Money.fromRupees(json['cess'] as num? ?? 0),
        lineTotal: Money.fromRupees(json['lineTotal'] as num? ?? 0),
      );
}

/// Document Types
enum InvoiceDocumentType {
  taxInvoice('Tax Invoice'),
  billOfSupply('Bill of Supply'),
  proforma('Proforma Invoice'),
  quotation('Quotation / Estimate'),
  creditNote('Credit Note'),
  debitNote('Debit Note');

  final String displayName;
  const InvoiceDocumentType(this.displayName);
}

/// Life-Cycle Status of an Invoice
enum InvoiceLifecycleStatus {
  draft,
  finalized,
  sent,
  partiallyPaid,
  paid,
  overdue,
  cancelled;

  String get displayName {
    switch (this) {
      case InvoiceLifecycleStatus.draft:
        return 'Draft';
      case InvoiceLifecycleStatus.finalized:
        return 'Finalized';
      case InvoiceLifecycleStatus.sent:
        return 'Sent';
      case InvoiceLifecycleStatus.partiallyPaid:
        return 'Partially Paid';
      case InvoiceLifecycleStatus.paid:
        return 'Paid';
      case InvoiceLifecycleStatus.overdue:
        return 'Overdue';
      case InvoiceLifecycleStatus.cancelled:
        return 'Cancelled';
    }
  }
}

/// Canonical, Single-Source-of-Truth Invoice Model
class CanonicalInvoice {
  final String id;
  final String businessId;
  final String? customerId;
  final String invoiceNumber;
  final String financialYear; // e.g. "2026-2027"
  final InvoiceDocumentType invoiceType;
  final InvoiceLifecycleStatus status;
  final String date; // DD/MM/YYYY
  final String dueDate; // DD/MM/YYYY

  // Seller Snapshot
  final Business seller;

  // Buyer Snapshot
  final Customer buyer;

  // Statutory GST Logistics
  final String placeOfSupply;
  final String placeOfSupplyCode; // 2-digit code
  final bool isInterState;
  final bool isReverseCharge;

  // Items
  final List<InvoiceLineItem> items;

  // Summary Financial Totals (computed deterministically via Paise)
  final Money subtotal;
  final double invoiceDiscountPercent;
  final Money invoiceDiscountAmount;
  final Money totalDiscount;
  final Money taxableAmount;
  final Money totalCgst;
  final Money totalSgst;
  final Money totalIgst;
  final Money totalCess;
  final Money totalTax;
  final Money roundOff;
  final Money grandTotal;

  // Settlement Ledger
  final Money amountPaid;
  final Money amountDue;
  final String paymentMethod;

  // Metadata & Customization
  final String templateId;
  final String notes;
  final String terms;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CanonicalInvoice({
    required this.id,
    required this.businessId,
    this.customerId,
    required this.invoiceNumber,
    required this.financialYear,
    this.invoiceType = InvoiceDocumentType.taxInvoice,
    this.status = InvoiceLifecycleStatus.draft,
    required this.date,
    required this.dueDate,
    required this.seller,
    required this.buyer,
    required this.placeOfSupply,
    required this.placeOfSupplyCode,
    required this.isInterState,
    this.isReverseCharge = false,
    required this.items,
    required this.subtotal,
    this.invoiceDiscountPercent = 0.0,
    required this.invoiceDiscountAmount,
    required this.totalDiscount,
    required this.taxableAmount,
    required this.totalCgst,
    required this.totalSgst,
    required this.totalIgst,
    required this.totalCess,
    required this.totalTax,
    required this.roundOff,
    required this.grandTotal,
    required this.amountPaid,
    required this.amountDue,
    this.paymentMethod = 'UPI',
    this.templateId = 'modern',
    this.notes = '',
    this.terms = '',
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isSettled => amountDue.isZero;
  bool get isPartiallyPaid => amountPaid.isPositive && !amountDue.isZero;

  Map<String, dynamic> toJson() => {
        'id': id,
        'businessId': businessId,
        'customerId': customerId,
        'invoiceNumber': invoiceNumber,
        'financialYear': financialYear,
        'invoiceType': invoiceType.name,
        'status': status.name,
        'date': date,
        'dueDate': dueDate,
        'seller': seller.toJson(),
        'buyer': buyer.toJson(),
        'placeOfSupply': placeOfSupply,
        'placeOfSupplyCode': placeOfSupplyCode,
        'isInterState': isInterState,
        'isReverseCharge': isReverseCharge,
        'items': items.map((i) => i.toJson()).toList(),
        'subtotal': subtotal.inRupees,
        'invoiceDiscountPercent': invoiceDiscountPercent,
        'invoiceDiscountAmount': invoiceDiscountAmount.inRupees,
        'totalDiscount': totalDiscount.inRupees,
        'taxableAmount': taxableAmount.inRupees,
        'totalCgst': totalCgst.inRupees,
        'totalSgst': totalSgst.inRupees,
        'totalIgst': totalIgst.inRupees,
        'totalCess': totalCess.inRupees,
        'totalTax': totalTax.inRupees,
        'roundOff': roundOff.inRupees,
        'grandTotal': grandTotal.inRupees,
        'amountPaid': amountPaid.inRupees,
        'amountDue': amountDue.inRupees,
        'paymentMethod': paymentMethod,
        'templateId': templateId,
        'notes': notes,
        'terms': terms,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}

/// Recorded Payment Transaction
class PaymentRecord {
  final String id;
  final String businessId;
  final String invoiceId;
  final String? customerId;
  final Money amount;
  final String date;
  final String paymentMethod; // Cash, UPI, Bank Transfer, Card, Cheque
  final String referenceNumber;
  final String notes;

  const PaymentRecord({
    required this.id,
    required this.businessId,
    required this.invoiceId,
    this.customerId,
    required this.amount,
    required this.date,
    required this.paymentMethod,
    this.referenceNumber = '',
    this.notes = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'businessId': businessId,
        'invoiceId': invoiceId,
        'customerId': customerId,
        'amount': amount.inRupees,
        'date': date,
        'paymentMethod': paymentMethod,
        'referenceNumber': referenceNumber,
        'notes': notes,
      };

  factory PaymentRecord.fromJson(Map<String, dynamic> json) => PaymentRecord(
        id: json['id'] as String? ?? '',
        businessId: json['businessId'] as String? ?? '',
        invoiceId: json['invoiceId'] as String? ?? '',
        customerId: json['customerId'] as String?,
        amount: Money.fromRupees(json['amount'] as num? ?? 0),
        date: json['date'] as String? ?? '',
        paymentMethod: json['paymentMethod'] as String? ?? 'UPI',
        referenceNumber: json['referenceNumber'] as String? ?? '',
        notes: json['notes'] as String? ?? '',
      );
}
