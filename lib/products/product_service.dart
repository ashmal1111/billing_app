import 'dart:convert';

import '../app_storage.dart';
import '../auth/multi_tenant_service.dart';
import '../core/env.dart';
import '../domain/calculation_engine.dart';
import '../domain/models.dart';
import '../domain/money.dart';
import '../security_service.dart';
import '../supabase_service.dart';

/// Paginated Product Catalog Result
class ProductPageResult {
  final List<Product> items;
  final int totalCount;
  final int page;
  final int pageSize;
  final int totalPages;

  const ProductPageResult({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });
}

/// Product & Services Master Service
class ProductService {
  static final ProductService instance = ProductService._internal();

  ProductService._internal();

  final AppStorage _storage = createAppStorage();
  final List<Product> _products = [];

  /// Standard Indian GST Tax Rates
  static const List<double> standardGstRates = [
    0.0,
    0.1,
    0.25,
    1.5,
    3.0,
    5.0,
    6.0,
    7.5,
    12.0,
    18.0,
    28.0,
  ];

  /// Standard Catalog Categories
  static const List<String> defaultCategories = [
    'Hardware',
    'Cloud Services',
    'Consulting',
    'Software Licenses',
    'Maintenance',
    'General',
  ];

  List<Product> get allProducts => List.unmodifiable(_products);

  Future<void> init() async {
    try {
      final dataStr = await _storage.readText('products_state.json');
      if (dataStr != null && dataStr.isNotEmpty) {
        final list = (json.decode(dataStr) as List?) ?? [];
        _products.clear();
        for (var item in list) {
          _products.add(Product.fromJson(item as Map<String, dynamic>));
        }
      }
    } catch (e) {
      AppLogger.error('Error loading products: $e');
    }
  }

  /// Create a new validated Product / Service within active business tenant
  Future<Product> createProduct({
    required String name,
    String sku = '',
    String description = '',
    String category = 'General',
    required String hsnSac,
    String unit = 'Pcs',
    Money costPrice = Money.zero,
    required Money sellingPrice,
    double gstRate = 18.0,
    bool isTaxInclusive = false,
    double stockQuantity = 0.0,
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
        message: 'Unauthorized: Current role cannot manage products',
        code: 'ROLE_UNAUTHORIZED',
      );
    }

    final trimmedName = SecurityValidator.sanitizeText(name, maxLength: 150);
    if (trimmedName.isEmpty) {
      throw AppError(
        message: 'Product name is mandatory',
        code: 'INVALID_NAME',
      );
    }

    final cleanHsn = hsnSac.trim();
    if (!SecurityValidator.isValidHsnSac(cleanHsn)) {
      throw AppError(
        message: 'Invalid HSN/SAC code format (2 to 8 numeric digits required)',
        code: 'INVALID_HSN_SAC',
      );
    }

    if (sellingPrice.isNegative) {
      throw AppError(
        message: 'Selling price cannot be negative',
        code: 'NEGATIVE_SELLING_PRICE',
      );
    }

    if (costPrice.isNegative) {
      throw AppError(
        message: 'Cost price cannot be negative',
        code: 'NEGATIVE_COST_PRICE',
      );
    }

    if (gstRate < 0 || gstRate > 100) {
      throw AppError(
        message: 'Invalid GST rate percentage',
        code: 'INVALID_GST_RATE',
      );
    }

    final productId = 'prod_${DateTime.now().millisecondsSinceEpoch}_${_products.length}';
    final product = Product(
      id: productId,
      businessId: activeBiz.id,
      name: trimmedName,
      sku: SecurityValidator.sanitizeText(sku, maxLength: 50),
      description: SecurityValidator.sanitizeText(description, maxLength: 500),
      category: SecurityValidator.sanitizeText(category, maxLength: 50),
      hsnSac: cleanHsn,
      unit: SecurityValidator.sanitizeText(unit, maxLength: 20),
      costPrice: costPrice,
      sellingPrice: sellingPrice,
      gstRate: gstRate,
      isTaxInclusive: isTaxInclusive,
      stockQuantity: stockQuantity.isNaN || stockQuantity.isInfinite ? 0.0 : stockQuantity,
    );

    _products.add(product);
    await _saveState();
    await _syncProductToSupabase(product);

    return product;
  }

  /// Get product by ID with strict tenant boundary enforcement
  Product? getProduct(String id) {
    final activeBiz = MultiTenantService.instance.activeBusiness;
    if (activeBiz == null) return null;

    final matches = _products.where((p) => p.id == id && p.businessId == activeBiz.id);
    return matches.isNotEmpty ? matches.first : null;
  }

  /// Update existing product
  Future<Product> updateProduct(Product updated) async {
    final activeBiz = MultiTenantService.instance.activeBusiness;
    if (activeBiz == null || updated.businessId != activeBiz.id) {
      throw AppError(
        message: 'Unauthorized: Cross-business product update blocked',
        code: 'CROSS_BUSINESS_UPDATE_DENIED',
      );
    }

    final index = _products.indexWhere((p) => p.id == updated.id && p.businessId == activeBiz.id);
    if (index < 0) {
      throw AppError(
        message: 'Product not found in current business',
        code: 'PRODUCT_NOT_FOUND',
      );
    }

    _products[index] = updated;
    await _saveState();
    await _syncProductToSupabase(updated);
    return updated;
  }

  /// Delete product (Restricted to Owner & Admin)
  Future<bool> deleteProduct(String id) async {
    final activeBiz = MultiTenantService.instance.activeBusiness;
    if (activeBiz == null || !MultiTenantService.instance.isAdmin) {
      AppLogger.warn('Unauthorized attempt to delete product');
      return false;
    }

    final countBefore = _products.length;
    _products.removeWhere((p) => p.id == id && p.businessId == activeBiz.id);
    final deleted = _products.length < countBefore;

    if (deleted) {
      await _saveState();
      final client = SupabaseService.instance.client;
      if (client != null) {
        try {
          await client.from('products').delete().eq('id', id).eq('business_id', activeBiz.id);
        } catch (e) {
          AppLogger.error('Error deleting product from Supabase: $e');
        }
      }
    }
    return deleted;
  }

  /// Search, filter and paginate products with strict tenant isolation
  ProductPageResult getProducts({
    String? searchQuery,
    String? category,
    bool? lowStockOnly,
    double lowStockThreshold = 5.0,
    int page = 1,
    int pageSize = 10,
  }) {
    final activeBiz = MultiTenantService.instance.activeBusiness;
    if (activeBiz == null) {
      return const ProductPageResult(
        items: [],
        totalCount: 0,
        page: 1,
        pageSize: 10,
        totalPages: 0,
      );
    }

    // 1. Strict Tenant Filtering
    var list = _products.where((p) => p.businessId == activeBiz.id).toList();

    // 2. Category Filter
    if (category != null && category.trim().isNotEmpty && category != 'All') {
      final cat = category.trim().toLowerCase();
      list = list.where((p) => p.category.toLowerCase() == cat).toList();
    }

    // 3. Low Stock Filter
    if (lowStockOnly == true) {
      list = list.where((p) => p.stockQuantity <= lowStockThreshold).toList();
    }

    // 4. Search Query Filter (name, SKU, HSN/SAC, category, description)
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      list = list.where((p) {
        return p.name.toLowerCase().contains(q) ||
            p.sku.toLowerCase().contains(q) ||
            p.hsnSac.toLowerCase().contains(q) ||
            p.category.toLowerCase().contains(q) ||
            p.description.toLowerCase().contains(q);
      }).toList();
    }

    final totalCount = list.length;
    final totalPages = (totalCount / pageSize).ceil();

    // 5. Safe Pagination
    final startIndex = (page - 1) * pageSize;
    if (startIndex >= totalCount) {
      return ProductPageResult(
        items: [],
        totalCount: totalCount,
        page: page,
        pageSize: pageSize,
        totalPages: totalPages,
      );
    }

    final endIndex = (startIndex + pageSize) > totalCount ? totalCount : (startIndex + pageSize);
    final pageItems = list.sublist(startIndex, endIndex);

    return ProductPageResult(
      items: pageItems,
      totalCount: totalCount,
      page: page,
      pageSize: pageSize,
      totalPages: totalPages,
    );
  }

  /// Maps a Catalog Product directly to LineItemCalculationInput
  /// Automatically carries over HSN/SAC, unit, price, and GST rate.
  static LineItemCalculationInput mapProductToLineItemInput(
    Product product, {
    double quantity = 1.0,
    double discountPercent = 0.0,
    double discountAmount = 0.0,
    double cessRate = 0.0,
  }) {
    return LineItemCalculationInput(
      productId: product.id,
      name: product.name,
      description: product.description,
      hsnSac: product.hsnSac,
      quantity: quantity,
      unit: product.unit,
      unitPrice: product.sellingPrice.inRupees.toDouble(),
      discountPercent: discountPercent,
      discountAmount: discountAmount,
      isTaxInclusive: product.isTaxInclusive,
      gstRate: product.gstRate,
      cessRate: cessRate,
    );
  }

  /// Adjust stock inventory safely with multi-tenant boundary check
  Future<Product> adjustStock(String productId, double quantityDelta) async {
    final activeBiz = MultiTenantService.instance.activeBusiness;
    if (activeBiz == null) {
      throw AppError(
        message: 'No active business selected',
        code: 'NO_ACTIVE_BUSINESS',
      );
    }

    final index = _products.indexWhere((p) => p.id == productId && p.businessId == activeBiz.id);
    if (index < 0) {
      throw AppError(
        message: 'Product not found in current business',
        code: 'PRODUCT_NOT_FOUND',
      );
    }

    final current = _products[index];
    final updatedStock = current.stockQuantity + quantityDelta;
    final updated = Product(
      id: current.id,
      businessId: current.businessId,
      name: current.name,
      sku: current.sku,
      description: current.description,
      category: current.category,
      hsnSac: current.hsnSac,
      unit: current.unit,
      costPrice: current.costPrice,
      sellingPrice: current.sellingPrice,
      gstRate: current.gstRate,
      isTaxInclusive: current.isTaxInclusive,
      stockQuantity: updatedStock < 0 ? 0.0 : updatedStock,
    );

    _products[index] = updated;
    await _saveState();
    await _syncProductToSupabase(updated);
    return updated;
  }

  /// Retrieve distinct categories in active business
  List<String> getActiveCategories() {
    final activeBiz = MultiTenantService.instance.activeBusiness;
    if (activeBiz == null) return [];

    final categories = _products
        .where((p) => p.businessId == activeBiz.id)
        .map((p) => p.category.trim())
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();
    categories.sort();
    return categories;
  }

  Future<void> _saveState() async {
    final payload = _products.map((p) => p.toJson()).toList();
    await _storage.writeText('products_state.json', json.encode(payload));
  }

  Future<void> _syncProductToSupabase(Product product) async {
    final client = SupabaseService.instance.client;
    if (client == null) return;

    try {
      await client.from('products').upsert({
        'id': product.id,
        'business_id': product.businessId,
        'name': product.name,
        'sku': product.sku,
        'description': product.description,
        'category': product.category,
        'hsn_sac': product.hsnSac,
        'unit': product.unit,
        'cost_price': product.costPrice.inRupees,
        'selling_price': product.sellingPrice.inRupees,
        'gst_rate': product.gstRate,
        'is_tax_inclusive': product.isTaxInclusive,
        'stock_quantity': product.stockQuantity,
      });
    } catch (e) {
      AppLogger.error('Error syncing product to Supabase: $e');
    }
  }
}
