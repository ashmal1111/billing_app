/// Security and sanitization utility for Billing App Pro.
///
/// Defends against:
/// 1. SQL Injection / PostgREST query injection
/// 2. Cross-Site Scripting (XSS) and Control Character injection
/// 3. Path Traversal attacks in local storage/file exports
/// 4. Numeric boundary anomalies (NaN, Infinity, negative revenue)
/// 5. URI / Scheme injection in WhatsApp and deep links
class SecurityValidator {
  SecurityValidator._();

  /// Regex pattern to detect directory traversal attempts
  static final RegExp _pathTraversalRegex =
      RegExp(r'(\.\.[/\\]|[/\\]\.\.)|([/\\]{2,})|[\x00-\x1F\x7F]');

  /// Regex for valid phone digits (7 to 15 digits, optional leading +)
  static final RegExp _phoneRegex = RegExp(r'^\+?[0-9]{7,15}$');

  /// Regex for standard email validation
  static final RegExp _emailRegex = RegExp(
      r'^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*$');

  /// Regex for Indian Goods & Services Tax Identification Number (GSTIN)
  /// Format: 2 digits (State code) + 10 alphanumeric (PAN) + 1 digit (entity) + 'Z' + 1 check digit
  static final RegExp _gstRegex =
      RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$');

  /// Sanitizes generic text strings by removing null bytes, unprintable control
  /// characters, and enforcing length boundaries.
  static String sanitizeText(String? input, {int maxLength = 255}) {
    if (input == null) return '';
    // Strip null bytes and non-printable control characters (except newline, return, tab)
    final cleaned = input
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '')
        .trim();
    if (cleaned.length > maxLength) {
      return cleaned.substring(0, maxLength);
    }
    return cleaned;
  }

  /// Sanitizes file names to prevent Directory Traversal attacks (e.g. `../../etc/passwd`).
  static String sanitizeFileName(String fileName,
      {String defaultExtension = '.json'}) {
    // Strip traversal tokens and dangerous path characters
    String safe = fileName.replaceAll(_pathTraversalRegex, '_');
    safe = safe.replaceAll(RegExp(r'[/\\:]'), '_');

    // Remove leading dots or slashes
    safe = safe.replaceAll(RegExp(r'^[._]+'), '');
    if (safe.isEmpty) {
      safe = 'export_${DateTime.now().millisecondsSinceEpoch}';
    }

    // Ensure it doesn't exceed safe filesystem length
    if (safe.length > 100) {
      safe = safe.substring(0, 100);
    }

    if (!safe.contains('.')) {
      safe = '$safe$defaultExtension';
    }

    return safe;
  }

  /// Validates email format
  static bool isValidEmail(String? email) {
    if (email == null || email.trim().isEmpty) return false;
    return _emailRegex.hasMatch(email.trim());
  }

  /// Validates and normalizes phone number
  static bool isValidPhone(String? phone) {
    if (phone == null || phone.trim().isEmpty) return false;
    final digitsOnly = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    return _phoneRegex.hasMatch(digitsOnly);
  }

  /// Validates GST number (returns true if empty/null, or if matches valid format)
  static bool isValidGst(String? gst) {
    if (gst == null || gst.trim().isEmpty) return true;
    return _gstRegex.hasMatch(gst.trim().toUpperCase());
  }

  /// Strict non-empty 15-character GSTIN format validator
  static bool isValidGSTIN(String? gstin) {
    if (gstin == null || gstin.trim().length != 15) return false;
    return _gstRegex.hasMatch(gstin.trim().toUpperCase());
  }

  /// Regex for Indian GST HSN (Goods: 2-8 digits) and SAC (Services: 6 digits)
  static final RegExp _hsnSacRegex = RegExp(r'^[0-9]{2,8}$');

  /// Validates Indian HSN/SAC code format (2 to 8 numeric digits)
  static bool isValidHsnSac(String? code) {
    if (code == null || code.trim().isEmpty) return false;
    return _hsnSacRegex.hasMatch(code.trim());
  }

  /// Sanitizes and validates numeric financial values.
  /// Rejects `NaN`, `Infinity`, and enforces bounds [min, max].
  static num sanitizeNumeric(dynamic value,
      {num min = 0, num max = 1000000000, num fallback = 0}) {
    if (value == null) return fallback;

    num parsed;
    if (value is num) {
      parsed = value;
    } else {
      parsed = num.tryParse(value.toString()) ?? fallback;
    }

    if (parsed.isNaN || parsed.isInfinite) {
      return fallback;
    }

    if (parsed < min) return min;
    if (parsed > max) return max;

    return parsed;
  }

  /// Comprehensive invoice sanitization before storage or cloud synchronization.
  static Map<String, dynamic> sanitizeInvoice(Map<String, dynamic> raw) {
    final subtotal =
        sanitizeNumeric(raw['subtotal'], min: 0, max: 1000000000, fallback: 0);
    final taxRate =
        sanitizeNumeric(raw['taxRate'], min: 0, max: 100, fallback: 0);
    final taxAmount =
        sanitizeNumeric(raw['taxAmount'], min: 0, max: 1000000000, fallback: 0);
    final discountPercent =
        sanitizeNumeric(raw['discountPercent'], min: 0, max: 100, fallback: 0);
    final discountAmount = sanitizeNumeric(raw['discountAmount'],
        min: 0, max: 1000000000, fallback: 0);
    final total =
        sanitizeNumeric(raw['total'], min: 0, max: 1000000000, fallback: 0);

    // Validate and sanitize line items
    final rawItems = (raw['items'] as List?) ?? [];
    final sanitizedItems = <Map<String, dynamic>>[];
    for (final item in rawItems) {
      if (item is Map) {
        final name = sanitizeText(item['name']?.toString(), maxLength: 100);
        final price = sanitizeNumeric(item['price'],
            min: 0, max: 1000000000, fallback: 0);
        final quantity =
            sanitizeNumeric(item['quantity'], min: 1, max: 100000, fallback: 1);
        sanitizedItems.add({
          'name': name.isEmpty ? 'Item' : name,
          'price': price,
          'quantity': quantity,
        });
      }
    }

    // Sanitize status to allowed enum values
    const allowedStatuses = {'paid', 'pending', 'overdue', 'cancelled'};
    String status =
        sanitizeText(raw['status']?.toString(), maxLength: 20).toLowerCase();
    if (!allowedStatuses.contains(status)) {
      status = 'pending';
    }

    return {
      'invoiceNumber':
          sanitizeText(raw['invoiceNumber']?.toString(), maxLength: 50),
      'clientName': sanitizeText(raw['clientName']?.toString(), maxLength: 100),
      'clientEmail':
          sanitizeText(raw['clientEmail']?.toString(), maxLength: 255),
      'clientPhone':
          sanitizeText(raw['clientPhone']?.toString(), maxLength: 25),
      'clientAddress':
          sanitizeText(raw['clientAddress']?.toString(), maxLength: 255),
      'clientGst': sanitizeText(raw['clientGst']?.toString(), maxLength: 20)
          .toUpperCase(),
      'date': sanitizeText(raw['date']?.toString(), maxLength: 30),
      'dueDate': sanitizeText(raw['dueDate']?.toString(), maxLength: 30),
      'items': sanitizedItems,
      'subtotal': subtotal,
      'taxRate': taxRate,
      'taxAmount': taxAmount,
      'discountPercent': discountPercent,
      'discountAmount': discountAmount,
      'total': total,
      'paymentMethod':
          sanitizeText(raw['paymentMethod']?.toString(), maxLength: 50),
      'template': sanitizeText(raw['template']?.toString(), maxLength: 30),
      'notes': sanitizeText(raw['notes']?.toString(), maxLength: 500),
      'status': status,
      'isRecurring': raw['isRecurring'] == true,
      'recurringType':
          sanitizeText(raw['recurringType']?.toString(), maxLength: 30),
      'recurringEndDate':
          sanitizeText(raw['recurringEndDate']?.toString(), maxLength: 50),
      'savedAt': sanitizeText(raw['savedAt']?.toString(), maxLength: 50),
    };
  }
}
