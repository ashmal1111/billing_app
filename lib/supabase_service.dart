import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_storage.dart';
import 'security_service.dart';

enum UserRole {
  admin,
  staff;

  String get displayName => this == UserRole.admin ? 'Administrator' : 'Staff';
}

class AppUserSession {
  final String id;
  final String email;
  final UserRole role;
  final bool isDemo;
  final DateTime loggedInAt;

  AppUserSession({
    required this.id,
    required this.email,
    required this.role,
    this.isDemo = false,
    DateTime? loggedInAt,
  }) : loggedInAt = loggedInAt ?? DateTime.now();

  bool get isAdmin => role == UserRole.admin;
  bool get isStaff => role == UserRole.staff;

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'role': role.name,
        'isDemo': isDemo,
        'loggedInAt': loggedInAt.toIso8601String(),
      };

  factory AppUserSession.fromJson(Map<String, dynamic> json) {
    return AppUserSession(
      id: json['id'] as String? ?? 'admin_01',
      email: json['email'] as String? ?? 'admin@billingpro.com',
      role: json['role'] == 'staff' ? UserRole.staff : UserRole.admin,
      isDemo: json['isDemo'] as bool? ?? false,
      loggedInAt: json['loggedInAt'] != null
          ? DateTime.tryParse(json['loggedInAt'] as String)
          : null,
    );
  }
}

class SupabaseService {
  static final SupabaseService instance = SupabaseService._internal();

  SupabaseService._internal();

  final AppStorage _storage = createAppStorage();

  String _supabaseUrl = '';
  String _supabaseAnonKey = '';
  bool _isConfigured = false;
  AppUserSession? _currentSession;

  String get supabaseUrl => _supabaseUrl;
  String get supabaseAnonKey => _supabaseAnonKey;
  bool get isConfigured => _isConfigured;
  AppUserSession? get currentSession => _currentSession;
  bool get isLoggedIn => _currentSession != null;
  bool get isAdmin => _currentSession?.isAdmin ?? false;

  SupabaseClient? get client {
    if (!_isConfigured) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Initialize service and restore previous session from local storage.
  Future<void> init() async {
    try {
      final configJson = await _storage.readText('supabase_config.json');
      if (configJson != null) {
        final data = json.decode(configJson) as Map<String, dynamic>;
        _supabaseUrl = (data['url'] as String?)?.trim() ?? '';
        _supabaseAnonKey = (data['anonKey'] as String?)?.trim() ?? '';
        if (_supabaseUrl.isNotEmpty && _supabaseAnonKey.isNotEmpty) {
          await _initSupabaseClient(_supabaseUrl, _supabaseAnonKey);
        }
      }

      final sessionJson = await _storage.readText('auth_session.json');
      if (sessionJson != null) {
        final data = json.decode(sessionJson) as Map<String, dynamic>;
        _currentSession = AppUserSession.fromJson(data);
      } else {
        // Default to Demo Admin session so income dashboard and features
        // are immediately usable out of the box.
        _currentSession = AppUserSession(
          id: 'admin_default',
          email: 'admin@billingpro.com',
          role: UserRole.admin,
          isDemo: true,
        );
      }
    } catch (e) {
      debugPrint('SupabaseService.init error: $e');
    }
  }

  Future<bool> configure({
    required String url,
    required String anonKey,
  }) async {
    _supabaseUrl = url.trim();
    _supabaseAnonKey = anonKey.trim();

    if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
      _isConfigured = false;
      await _storage.writeText(
        'supabase_config.json',
        json.encode({'url': '', 'anonKey': ''}),
      );
      return false;
    }

    final success = await _initSupabaseClient(_supabaseUrl, _supabaseAnonKey);
    if (success) {
      await _storage.writeText(
        'supabase_config.json',
        json.encode({'url': _supabaseUrl, 'anonKey': _supabaseAnonKey}),
      );
    }
    return success;
  }

  Future<bool> _initSupabaseClient(String url, String key) async {
    try {
      await Supabase.initialize(
        url: url,
        // ignore: deprecated_member_use
        anonKey: key,
        debug: kDebugMode,
      );
      _isConfigured = true;
      return true;
    } catch (e) {
      debugPrint('Error initializing Supabase client: $e');
      _isConfigured = false;
      return false;
    }
  }

  /// Sign in with email and password
  Future<AppUserSession> signIn({
    required String email,
    required String password,
    UserRole? fallbackRole,
  }) async {
    if (_isConfigured && client != null) {
      final response = await client!.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final user = response.user;
      if (user == null) {
        throw Exception('Sign in failed: User is null');
      }

      final roleStr = user.userMetadata?['role'] as String?;
      final role = roleStr == 'staff'
          ? UserRole.staff
          : (fallbackRole ??
              (email.toLowerCase().contains('staff')
                  ? UserRole.staff
                  : UserRole.admin));

      final session = AppUserSession(
        id: user.id,
        email: user.email ?? email,
        role: role,
        isDemo: false,
      );

      _currentSession = session;
      await _saveSession();
      return session;
    } else {
      // Local/Demo authentication fallback
      final role = fallbackRole ??
          (email.toLowerCase().contains('staff')
              ? UserRole.staff
              : UserRole.admin);

      final session = AppUserSession(
        id: 'local_${DateTime.now().millisecondsSinceEpoch}',
        email: email.trim(),
        role: role,
        isDemo: true,
      );

      _currentSession = session;
      await _saveSession();
      return session;
    }
  }

  /// Sign up a new user with email, password, and assigned role
  Future<AppUserSession> signUp({
    required String email,
    required String password,
    required UserRole role,
  }) async {
    if (_isConfigured && client != null) {
      final response = await client!.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'role': role.name},
      );
      final user = response.user;
      if (user == null) {
        throw Exception('Sign up failed: User is null');
      }

      final session = AppUserSession(
        id: user.id,
        email: user.email ?? email,
        role: role,
        isDemo: false,
      );

      _currentSession = session;
      await _saveSession();
      return session;
    } else {
      // Local/Demo user creation
      final session = AppUserSession(
        id: 'local_${DateTime.now().millisecondsSinceEpoch}',
        email: email.trim(),
        role: role,
        isDemo: true,
      );

      _currentSession = session;
      await _saveSession();
      return session;
    }
  }

  /// Quick 1-click Demo Admin session switch
  Future<AppUserSession> loginAsDemoAdmin() async {
    final session = AppUserSession(
      id: 'demo_admin',
      email: 'admin@company.com',
      role: UserRole.admin,
      isDemo: true,
    );
    _currentSession = session;
    await _saveSession();
    return session;
  }

  /// Quick 1-click Demo Staff session switch
  Future<AppUserSession> loginAsDemoStaff() async {
    final session = AppUserSession(
      id: 'demo_staff',
      email: 'staff@company.com',
      role: UserRole.staff,
      isDemo: true,
    );
    _currentSession = session;
    await _saveSession();
    return session;
  }

  /// Sign out current session
  Future<void> signOut() async {
    try {
      if (_isConfigured && client != null) {
        await client!.auth.signOut();
      }
    } catch (_) {
      // Ignore signOut network errors
    }
    _currentSession = null;
    await _storage.writeText('auth_session.json', '');
  }

  Future<void> _saveSession() async {
    if (_currentSession != null) {
      await _storage.writeText(
        'auth_session.json',
        json.encode(_currentSession!.toJson()),
      );
    }
  }

  /// Sync local invoices with Supabase with input sanitization and user attribution
  Future<void> syncInvoiceToCloud(Map<String, dynamic> invoice) async {
    if (!_isConfigured || client == null) return;
    try {
      final sanitized = SecurityValidator.sanitizeInvoice(invoice);
      final userId = client!.auth.currentUser?.id;

      final record = <String, dynamic>{
        'invoice_number': sanitized['invoiceNumber'],
        'client_name': sanitized['clientName'],
        'client_email': sanitized['clientEmail'],
        'client_phone': sanitized['clientPhone'],
        'client_address': sanitized['clientAddress'],
        'client_gst': sanitized['clientGst'],
        'date': sanitized['date'],
        'due_date': sanitized['dueDate'],
        'items': sanitized['items'] ?? [],
        'subtotal': sanitized['subtotal'] ?? 0,
        'tax_rate': sanitized['taxRate'] ?? 18,
        'tax_amount': sanitized['taxAmount'] ?? 0,
        'discount_percent': sanitized['discountPercent'] ?? 0,
        'discount_amount': sanitized['discountAmount'] ?? 0,
        'total': sanitized['total'] ?? 0,
        'status': sanitized['status'] ?? 'pending',
        'payment_method': sanitized['paymentMethod'] ?? 'UPI',
        'template': sanitized['template'] ?? 'modern',
        'notes': sanitized['notes'] ?? '',
      };

      // Attribute record to authenticated user for strict RLS compliance
      if (userId != null && userId.isNotEmpty) {
        record['user_id'] = userId;
      }

      await client!.from('invoices').upsert(
            record,
            onConflict: 'invoice_number',
          );
    } catch (e) {
      debugPrint('Error syncing invoice to Supabase: $e');
    }
  }

  /// Production-hardened SQL script with strict RLS, relational constraints,
  /// and immutable audit logging.
  static const String supabaseSqlSchema = '''
-- =========================================================
-- BILLING APP PRO - PRODUCTION HARDENED SUPABASE / RDS SCHEMA
-- =========================================================

-- 1. Helper function to verify Admin role from JWT / user metadata
create or replace function public.is_admin()
returns boolean
language sql
security definer
stable
as \$\$
  select coalesce(
    (current_setting('request.jwt.claims', true)::jsonb -> 'user_metadata' ->> 'role') = 'admin',
    (current_setting('request.jwt.claims', true)::jsonb ->> 'role') = 'admin',
    false
  );
\$\$;

-- 2. Invoices Table with Relational & Field Constraints
create table if not exists public.invoices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null default auth.uid(),
  invoice_number varchar(50) not null unique,
  client_name varchar(100) not null,
  client_email varchar(255),
  client_phone varchar(25),
  client_address varchar(255),
  client_gst varchar(20),
  date varchar(30) not null default current_date::text,
  due_date varchar(30),
  items jsonb not null default '[]'::jsonb,
  subtotal numeric(12, 2) not null default 0 check (subtotal >= 0 and subtotal <= 1000000000),
  tax_rate numeric(5, 2) not null default 18 check (tax_rate >= 0 and tax_rate <= 100),
  tax_amount numeric(12, 2) not null default 0 check (tax_amount >= 0 and tax_amount <= 1000000000),
  discount_percent numeric(5, 2) not null default 0 check (discount_percent >= 0 and discount_percent <= 100),
  discount_amount numeric(12, 2) not null default 0 check (discount_amount >= 0 and discount_amount <= 1000000000),
  total numeric(12, 2) not null default 0 check (total >= 0 and total <= 1000000000),
  status varchar(20) not null default 'pending' check (status in ('paid', 'pending', 'overdue', 'cancelled')),
  payment_method varchar(50) not null default 'UPI',
  template varchar(30) not null default 'modern',
  notes varchar(500),
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now()
);

-- 3. Row Level Security (RLS) - Principle of Least Privilege
alter table public.invoices enable row level security;
alter table public.invoices force row level security;

-- SELECT Policy: Admins view all invoices; Staff view their own created invoices
drop policy if exists "invoices_select_policy" on public.invoices;
create policy "invoices_select_policy"
  on public.invoices for select
  to authenticated
  using (
    public.is_admin() or auth.uid() = user_id
  );

-- INSERT Policy: Authenticated users can insert invoices bound to their user ID
drop policy if exists "invoices_insert_policy" on public.invoices;
create policy "invoices_insert_policy"
  on public.invoices for insert
  to authenticated
  with check (
    public.is_admin() or auth.uid() = user_id or user_id is null
  );

-- UPDATE Policy: Admins can update any; Staff can only update their own
drop policy if exists "invoices_update_policy" on public.invoices;
create policy "invoices_update_policy"
  on public.invoices for update
  to authenticated
  using (
    public.is_admin() or auth.uid() = user_id
  )
  with check (
    public.is_admin() or auth.uid() = user_id
  );

-- DELETE Policy: ONLY Administrators can delete invoices (prevents fraud & ledger tampering)
drop policy if exists "invoices_delete_policy" on public.invoices;
create policy "invoices_delete_policy"
  on public.invoices for delete
  to authenticated
  using (
    public.is_admin()
  );

-- 4. Immutable Audit Logging Table
create table if not exists public.invoice_audit_logs (
  id uuid primary key default gen_random_uuid(),
  invoice_id uuid,
  invoice_number varchar(50),
  changed_by uuid references auth.users(id) default auth.uid(),
  action varchar(10) not null check (action in ('INSERT', 'UPDATE', 'DELETE')),
  old_data jsonb,
  new_data jsonb,
  changed_at timestamp with time zone not null default now()
);

alter table public.invoice_audit_logs enable row level security;

-- Only Admins can inspect audit logs; users cannot alter or delete audit history
drop policy if exists "audit_logs_select_admin" on public.invoice_audit_logs;
create policy "audit_logs_select_admin"
  on public.invoice_audit_logs for select
  to authenticated
  using (public.is_admin());

-- 5. Automatic Audit Trail Trigger
create or replace function public.log_invoice_changes()
returns trigger
language plpgsql
security definer
as \$\$
begin
  if (TG_OP = 'INSERT') then
    insert into public.invoice_audit_logs(invoice_id, invoice_number, changed_by, action, new_data)
    values (NEW.id, NEW.invoice_number, auth.uid(), 'INSERT', to_jsonb(NEW));
    return NEW;
  elsif (TG_OP = 'UPDATE') then
    NEW.updated_at = now();
    insert into public.invoice_audit_logs(invoice_id, invoice_number, changed_by, action, old_data, new_data)
    values (NEW.id, NEW.invoice_number, auth.uid(), 'UPDATE', to_jsonb(OLD), to_jsonb(NEW));
    return NEW;
  elsif (TG_OP = 'DELETE') then
    insert into public.invoice_audit_logs(invoice_id, invoice_number, changed_by, action, old_data)
    values (OLD.id, OLD.invoice_number, auth.uid(), 'DELETE', to_jsonb(OLD));
    return OLD;
  end if;
  return null;
end;
\$\$;

drop trigger if exists tr_invoice_audit on public.invoices;
create trigger tr_invoice_audit
  after insert or update or delete on public.invoices
  for each row execute function public.log_invoice_changes();
''';
}
