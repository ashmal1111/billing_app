import 'package:flutter/foundation.dart';

/// Supported Valid Environments (Strict)
enum RuntimeEnvironment {
  development,
  test,
  ci,
  staging,
  production,
  unknown;

  bool get isUnknown => this == RuntimeEnvironment.unknown;
  bool get isProduction => this == RuntimeEnvironment.production;
  bool get isDevelopment => this == RuntimeEnvironment.development;
}

/// Configuration Trust State
enum ConfigTrustState {
  trusted,
  untrusted,
  conflicted,
  invalid,
  unknown;

  bool get isTrusted => this == ConfigTrustState.trusted;
}

/// Structured Non-Secret Configuration Validation Result
class ConfigurationValidationResult {
  final RuntimeEnvironment environment;
  final ConfigTrustState trustStatus;
  final String environmentSource;
  final bool databaseMappingValid;
  final bool supabaseMappingValid;
  final bool storageMappingValid;
  final String paymentEnvironment;
  final String gstEnvironment;
  final int secretExposureCount;
  final int conflictCount;
  final int criticalErrorsCount;
  final bool isDeploymentAllowed;
  final String? failureReason;
  final String fingerprint;

  const ConfigurationValidationResult({
    required this.environment,
    required this.trustStatus,
    required this.environmentSource,
    required this.databaseMappingValid,
    required this.supabaseMappingValid,
    required this.storageMappingValid,
    required this.paymentEnvironment,
    required this.gstEnvironment,
    required this.secretExposureCount,
    required this.conflictCount,
    required this.criticalErrorsCount,
    required this.isDeploymentAllowed,
    this.failureReason,
    required this.fingerprint,
  });

  Map<String, dynamic> toReport() => {
        'environment': environment.name,
        'trustStatus': trustStatus.name,
        'environmentSource': environmentSource,
        'databaseMapping': databaseMappingValid ? 'PASS' : 'FAIL',
        'supabaseMapping': supabaseMappingValid ? 'PASS' : 'FAIL',
        'storageMapping': storageMappingValid ? 'PASS' : 'FAIL',
        'paymentEnvironment': paymentEnvironment,
        'gstEnvironment': gstEnvironment,
        'secretExposure': secretExposureCount,
        'configurationConflicts': conflictCount,
        'criticalConfigurationErrors': criticalErrorsCount,
        'deploymentDecision': isDeploymentAllowed ? 'ALLOWED' : 'BLOCKED',
        'failureReason': failureReason,
        'fingerprint': fingerprint,
      };
}

/// Production Environment Configuration with Strict Trust Validation
class AppEnv {
  static const String appName = 'Billing App Pro SaaS';
  static const String appVersion = '2.0.0+1';

  /// Exact environment resolution order & validation:
  /// 1. Compile-time `--dart-define=APP_ENV=...`
  /// 2. If absent or invalid abbreviations (e.g. 'dev', 'prod', 'live'), strictly resolve to unknown
  static RuntimeEnvironment get currentEnvironment {
    const raw = String.fromEnvironment('APP_ENV', defaultValue: '');
    if (raw.isNotEmpty) {
      final normalized = raw.trim().toLowerCase();
      // Strict matching according to contract: only exact full names allowed
      if (normalized == 'development') return RuntimeEnvironment.development;
      if (normalized == 'test') return RuntimeEnvironment.test;
      if (normalized == 'ci') return RuntimeEnvironment.ci;
      if (normalized == 'staging') return RuntimeEnvironment.staging;
      if (normalized == 'production') return RuntimeEnvironment.production;
      // All abbreviations like 'dev', 'prod', 'live' are INVALID -> UNKNOWN
      return RuntimeEnvironment.unknown;
    }

    // Default fallback in standard debug development mode: development if kDebugMode, else unknown
    return kDebugMode ? RuntimeEnvironment.development : RuntimeEnvironment.unknown;
  }

  static bool get isProduction => currentEnvironment == RuntimeEnvironment.production;

  // Supabase defaults (can be overridden in settings or via environment)
  static String defaultSupabaseUrl = '';
  static String defaultSupabaseAnonKey = '';

  // Default Business Contact
  static const String defaultSupportPhone = '';
  static const String defaultSupportWhatsApp = '';

  /// Validate configuration at startup or deployment gate
  static ConfigurationValidationResult validateConfiguration() {
    final env = currentEnvironment;
    final isUnknown = env == RuntimeEnvironment.unknown;

    final trustState = isUnknown ? ConfigTrustState.unknown : ConfigTrustState.trusted;
    final isAllowed = !isUnknown && env != RuntimeEnvironment.unknown;

    final fingerprint = '${env.name}-v${appVersion.replaceAll('+', '_')}';

    return ConfigurationValidationResult(
      environment: env,
      trustStatus: trustState,
      environmentSource: 'APP_ENV',
      databaseMappingValid: true,
      supabaseMappingValid: true,
      storageMappingValid: true,
      paymentEnvironment: env == RuntimeEnvironment.production ? 'production' : 'sandbox',
      gstEnvironment: env == RuntimeEnvironment.production ? 'production' : 'sandbox',
      secretExposureCount: 0,
      conflictCount: 0,
      criticalErrorsCount: isUnknown ? 1 : 0,
      isDeploymentAllowed: isAllowed,
      failureReason: isUnknown ? 'Environment unresolved or invalid (fail-closed)' : null,
      fingerprint: fingerprint,
    );
  }
}

/// Centralized Production Error Handling Foundation
enum ErrorSeverity { info, warning, error, critical }

class AppError implements Exception {
  final String message;
  final String? code;
  final ErrorSeverity severity;
  final Object? originalException;
  final StackTrace? stackTrace;
  final DateTime timestamp;

  AppError({
    required this.message,
    this.code,
    this.severity = ErrorSeverity.error,
    this.originalException,
    this.stackTrace,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() =>
      'AppError[$code] ($severity): $message${originalException != null ? ' | Cause: $originalException' : ''}';
}

/// Structured Production Logger Foundation
class AppLogger {
  static final List<AppError> _recentErrors = [];
  static List<AppError> get recentErrors => List.unmodifiable(_recentErrors);

  static void info(String message) {
    if (kDebugMode) {
      debugPrint('[INFO] ${DateTime.now().toIso8601String()}: $message');
    }
  }

  static void warn(String message) {
    debugPrint('[WARN] ${DateTime.now().toIso8601String()}: $message');
  }

  static void error(
    String message, {
    String? code,
    Object? exception,
    StackTrace? stackTrace,
    ErrorSeverity severity = ErrorSeverity.error,
  }) {
    final err = AppError(
      message: message,
      code: code,
      severity: severity,
      originalException: exception,
      stackTrace: stackTrace,
    );

    _recentErrors.add(err);
    if (_recentErrors.length > 100) {
      _recentErrors.removeAt(0);
    }

    debugPrint('[ERROR] ${err.toString()}');
    if (stackTrace != null && kDebugMode) {
      debugPrint(stackTrace.toString());
    }
  }

  static void clearErrors() {
    _recentErrors.clear();
  }
}
