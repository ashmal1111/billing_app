import 'dart:convert';

import '../app_storage.dart';
import '../auth/multi_tenant_service.dart';
import '../core/env.dart';
import '../domain/models.dart';
import '../domain/money.dart';
import '../security_service.dart';
import '../supabase_service.dart';

/// Customer Financial Summary
class CustomerFinancialSummary {
  final String customerId;
  final int totalInvoices;
  final Money totalInvoiced;
  final Money totalPaid;
  final Money outstandingBalance;
  final Money overdueAmount;

  const CustomerFinancialSummary({
    required this.customerId,
    required this.totalInvoices,
    required this.totalInvoiced,
    required this.totalPaid,
    required this.outstandingBalance,
    required this.overdueAmount,
  });
}

/// Paginated Customer Result
class CustomerPageResult {
  final List<Customer> items;
  final int totalCount;
  final int page;
  final int pageSize;
  final int totalPages;

  const CustomerPageResult({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });
}

/// Production Customer Master Service
class CustomerService {
  static final CustomerService instance = CustomerService._internal();

  CustomerService._internal();

  final AppStorage _storage = createAppStorage();
  final List<Customer> _customers = [];

  List<Customer> get allCustomers => List.unmodifiable(_customers);

  Future<void> init() async {
    try {
      final dataStr = await _storage.readText('customers_state.json');
      if (dataStr != null && dataStr.isNotEmpty) {
        final list = (json.decode(dataStr) as List?) ?? [];
        _customers.clear();
        for (var item in list) {
          _customers.add(Customer.fromJson(item as Map<String, dynamic>));
        }
      }
    } catch (e) {
      AppLogger.error('Error loading customers: $e');
    }
  }

  /// Create a new validated Customer within the active business tenant
  Future<Customer> createCustomer({
    required String name,
    String companyName = '',
    String phone = '',
    String email = '',
    String gstin = '',
    String pan = '',
    GstRegistrationType gstType = GstRegistrationType.registered,
    String billingAddress = '',
    String shippingAddress = '',
    String state = 'Kerala',
    String? stateCode,
    Money creditLimit = Money.zero,
    String paymentTerms = 'Due on Receipt',
    String notes = '',
  }) async {
    final activeBiz = MultiTenantService.instance.activeBusiness;
    if (activeBiz == null) {
      throw AppError(
        message: 'No active business selected',
        code: 'NO_ACTIVE_BUSINESS',
      );
    }

    if (!MultiTenantService.instance.canCreateInvoices) {
      throw AppError(
        message: 'Unauthorized: Current role cannot manage customers',
        code: 'ROLE_UNAUTHORIZED',
      );
    }

    final trimmedName = SecurityValidator.sanitizeText(name, maxLength: 150);
    if (trimmedName.isEmpty) {
      throw AppError(
        message: 'Customer name is mandatory',
        code: 'INVALID_NAME',
      );
    }

    final cleanEmail = email.trim();
    if (cleanEmail.isNotEmpty && !SecurityValidator.isValidEmail(cleanEmail)) {
      throw AppError(
        message: 'Invalid email address format',
        code: 'INVALID_EMAIL',
      );
    }

    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.isNotEmpty && !SecurityValidator.isValidPhone(phone)) {
      throw AppError(
        message: 'Invalid phone number format (expected 7-15 digits)',
        code: 'INVALID_PHONE',
      );
    }

    final cleanGstin = gstin.trim().toUpperCase();
    if (cleanGstin.isNotEmpty && !SecurityValidator.isValidGSTIN(cleanGstin)) {
      throw AppError(
        message: 'Invalid 15-character GSTIN format',
        code: 'INVALID_GSTIN',
      );
    }

    // Determine State Code from GSTIN if present
    String resolvedStateCode = stateCode ?? '32';
    if (cleanGstin.length >= 2) {
      resolvedStateCode = cleanGstin.substring(0, 2);
    }

    // Extract PAN from characters 3-12 of GSTIN if not explicitly provided
    String resolvedPan = pan.trim().toUpperCase();
    if (resolvedPan.isEmpty && cleanGstin.length == 15) {
      resolvedPan = cleanGstin.substring(2, 12);
    }

    final customerId = 'cust_${DateTime.now().millisecondsSinceEpoch}_${_customers.length}';
    final customer = Customer(
      id: customerId,
      businessId: activeBiz.id,
      name: trimmedName,
      companyName: SecurityValidator.sanitizeText(companyName, maxLength: 150),
      phone: cleanPhone,
      email: cleanEmail,
      gstin: cleanGstin,
      pan: resolvedPan,
      gstType: gstType,
      billingAddress: SecurityValidator.sanitizeText(billingAddress, maxLength: 300),
      shippingAddress: SecurityValidator.sanitizeText(shippingAddress, maxLength: 300),
      state: state,
      stateCode: resolvedStateCode,
      creditLimit: creditLimit,
      notes: notes,
    );

    _customers.add(customer);
    await _saveState();
    await _syncCustomerToSupabase(customer);

    return customer;
  }

  /// Get customer by ID with strict tenant boundary enforcement
  Customer? getCustomer(String id) {
    final activeBiz = MultiTenantService.instance.activeBusiness;
    if (activeBiz == null) return null;

    final matches = _customers.where((c) => c.id == id && c.businessId == activeBiz.id);
    return matches.isNotEmpty ? matches.first : null;
  }

  /// Update existing customer
  Future<Customer> updateCustomer(Customer updated) async {
    final activeBiz = MultiTenantService.instance.activeBusiness;
    if (activeBiz == null || updated.businessId != activeBiz.id) {
      throw AppError(
        message: 'Unauthorized: Cross-business customer update blocked',
        code: 'CROSS_BUSINESS_UPDATE_DENIED',
      );
    }

    final index = _customers.indexWhere((c) => c.id == updated.id && c.businessId == activeBiz.id);
    if (index < 0) {
      throw AppError(
        message: 'Customer not found in current business',
        code: 'CUSTOMER_NOT_FOUND',
      );
    }

    _customers[index] = updated;
    await _saveState();
    await _syncCustomerToSupabase(updated);
    return updated;
  }

  /// Delete / Archive customer (Restricted to Owner & Admin)
  Future<bool> deleteCustomer(String id) async {
    final activeBiz = MultiTenantService.instance.activeBusiness;
    if (activeBiz == null || !MultiTenantService.instance.isAdmin) {
      AppLogger.warn('Unauthorized attempt to delete customer');
      return false;
    }

    final countBefore = _customers.length;
    _customers.removeWhere((c) => c.id == id && c.businessId == activeBiz.id);
    final deleted = _customers.length < countBefore;

    if (deleted) {
      await _saveState();
      final client = SupabaseService.instance.client;
      if (client != null) {
        try {
          await client.from('customers').delete().eq('id', id).eq('business_id', activeBiz.id);
        } catch (e) {
          AppLogger.error('Error deleting customer from Supabase: $e');
        }
      }
    }
    return deleted;
  }

  /// Search, filter and paginate customers with strict tenant isolation
  CustomerPageResult getCustomers({
    String? searchQuery,
    GstRegistrationType? filterType,
    int page = 1,
    int pageSize = 10,
  }) {
    final activeBiz = MultiTenantService.instance.activeBusiness;
    if (activeBiz == null) {
      return const CustomerPageResult(
        items: [],
        totalCount: 0,
        page: 1,
        pageSize: 10,
        totalPages: 0,
      );
    }

    // 1. Strict Tenant Filtering
    var list = _customers.where((c) => c.businessId == activeBiz.id).toList();

    // 2. GST Type Filter
    if (filterType != null) {
      list = list.where((c) => c.gstType == filterType).toList();
    }

    // 3. Search Query Filter (name, company, email, phone, GSTIN)
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      list = list.where((c) {
        return c.name.toLowerCase().contains(q) ||
            c.companyName.toLowerCase().contains(q) ||
            c.email.toLowerCase().contains(q) ||
            c.phone.contains(q) ||
            c.gstin.toLowerCase().contains(q);
      }).toList();
    }

    final totalCount = list.length;
    final totalPages = (totalCount / pageSize).ceil();

    // 4. Safe Pagination
    final startIndex = (page - 1) * pageSize;
    if (startIndex >= totalCount) {
      return CustomerPageResult(
        items: [],
        totalCount: totalCount,
        page: page,
        pageSize: pageSize,
        totalPages: totalPages,
      );
    }

    final endIndex = (startIndex + pageSize) > totalCount ? totalCount : (startIndex + pageSize);
    final pageItems = list.sublist(startIndex, endIndex);

    return CustomerPageResult(
      items: pageItems,
      totalCount: totalCount,
      page: page,
      pageSize: pageSize,
      totalPages: totalPages,
    );
  }

  /// Compute real-time financial ledger summary for a customer
  CustomerFinancialSummary getCustomerFinancialSummary(
    String customerId,
    List<CanonicalInvoice> invoices,
    List<PaymentRecord> payments,
  ) {
    final customerInvoices = invoices.where((i) => i.customerId == customerId || i.buyer.id == customerId).toList();
    final customerPayments = payments.where((p) => p.customerId == customerId).toList();

    Money totalInvoiced = Money.zero;
    Money totalDue = Money.zero;
    Money totalOverdue = Money.zero;

    for (final inv in customerInvoices) {
      totalInvoiced += inv.grandTotal;
      totalDue += inv.amountDue;
      if (inv.status == InvoiceLifecycleStatus.overdue) {
        totalOverdue += inv.amountDue;
      }
    }

    Money totalPaid = Money.zero;
    for (final p in customerPayments) {
      totalPaid += p.amount;
    }

    return CustomerFinancialSummary(
      customerId: customerId,
      totalInvoices: customerInvoices.length,
      totalInvoiced: totalInvoiced,
      totalPaid: totalPaid,
      outstandingBalance: totalDue,
      overdueAmount: totalOverdue,
    );
  }

  Future<void> _saveState() async {
    final payload = _customers.map((c) => c.toJson()).toList();
    await _storage.writeText('customers_state.json', json.encode(payload));
  }

  Future<void> _syncCustomerToSupabase(Customer customer) async {
    final client = SupabaseService.instance.client;
    if (client == null) return;

    try {
      await client.from('customers').upsert({
        'id': customer.id,
        'business_id': customer.businessId,
        'name': customer.name,
        'company_name': customer.companyName,
        'phone': customer.phone,
        'email': customer.email,
        'gstin': customer.gstin,
        'pan': customer.pan,
        'gst_type': customer.gstType.name,
        'billing_address': customer.billingAddress,
        'shipping_address': customer.shippingAddress,
        'state': customer.state,
        'state_code': customer.stateCode,
        'credit_limit': customer.creditLimit.inRupees,
        'notes': customer.notes,
      });
    } catch (e) {
      AppLogger.error('Error syncing customer to Supabase: $e');
    }
  }
}
