import 'dart:convert';


import '../app_storage.dart';
import '../core/env.dart';
import '../domain/models.dart';
import '../supabase_service.dart';

/// Business Member with User attribution and assigned SaaS Role
class BusinessMember {
  final String id;
  final String businessId;
  final String userId;
  final String email;
  final SaaSRole role;
  final DateTime joinedAt;

  const BusinessMember({
    required this.id,
    required this.businessId,
    required this.userId,
    required this.email,
    required this.role,
    required this.joinedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'businessId': businessId,
        'userId': userId,
        'email': email,
        'role': role.name,
        'joinedAt': joinedAt.toIso8601String(),
      };

  factory BusinessMember.fromJson(Map<String, dynamic> json) => BusinessMember(
        id: json['id'] as String? ?? '',
        businessId: json['businessId'] as String? ?? '',
        userId: json['userId'] as String? ?? '',
        email: json['email'] as String? ?? '',
        role: SaaSRole.values.firstWhere(
          (r) => r.name == json['role'],
          orElse: () => SaaSRole.employee,
        ),
        joinedAt: json['joinedAt'] != null
            ? DateTime.tryParse(json['joinedAt'] as String) ?? DateTime.now()
            : DateTime.now(),
      );
}

/// Core Multi-Tenant Business & RBAC Context Manager
class MultiTenantService {
  static final MultiTenantService instance = MultiTenantService._internal();

  MultiTenantService._internal();

  final AppStorage _storage = createAppStorage();

  Business? _activeBusiness;
  final List<Business> _userBusinesses = [];
  final List<BusinessMember> _activeMembers = [];
  SaaSRole _activeRole = SaaSRole.owner;

  Business? get activeBusiness => _activeBusiness;
  List<Business> get userBusinesses => List.unmodifiable(_userBusinesses);
  List<BusinessMember> get activeMembers => List.unmodifiable(_activeMembers);
  SaaSRole get activeRole => _activeRole;

  bool get isOwner => _activeRole == SaaSRole.owner;
  bool get isAdmin => _activeRole == SaaSRole.owner || _activeRole == SaaSRole.admin;
  bool get canManageSettings => isAdmin;
  bool get canModifyFinancials =>
      _activeRole == SaaSRole.owner ||
      _activeRole == SaaSRole.admin ||
      _activeRole == SaaSRole.accountant;
  bool get canCreateInvoices => _activeRole.canCreateInvoices;
  bool get canDeleteInvoices => _activeRole.canDeleteInvoices;

  /// Initialize Multi-Tenant state from local persistence or Supabase
  Future<void> init() async {
    try {
      final dataStr = await _storage.readText('multi_tenant_state.json');
      if (dataStr != null && dataStr.isNotEmpty) {
        final data = json.decode(dataStr) as Map<String, dynamic>;
        final bizList = (data['businesses'] as List?) ?? [];
        _userBusinesses.clear();
        for (var b in bizList) {
          _userBusinesses.add(Business.fromJson(b as Map<String, dynamic>));
        }

        final activeId = data['activeBusinessId'] as String?;
        if (_userBusinesses.isNotEmpty) {
          _activeBusiness = _userBusinesses.firstWhere(
            (b) => b.id == activeId,
            orElse: () => _userBusinesses.first,
          );
        }

        final roleStr = data['activeRole'] as String?;
        _activeRole = SaaSRole.values.firstWhere(
          (r) => r.name == roleStr,
          orElse: () => SaaSRole.owner,
        );

        final membersList = (data['members'] as List?) ?? [];
        _activeMembers.clear();
        for (var m in membersList) {
          _activeMembers.add(BusinessMember.fromJson(m as Map<String, dynamic>));
        }
      }

      // If no business exists yet, create default seed business for current user
      if (_activeBusiness == null) {
        await _createDefaultSeedBusiness();
      }
    } catch (e) {
      AppLogger.error('Error initializing MultiTenantService: $e');
      await _createDefaultSeedBusiness();
    }
  }

  Future<void> _createDefaultSeedBusiness() async {
    final currentSession = SupabaseService.instance.currentSession;
    final userId = currentSession?.id ?? 'admin_default';
    final userEmail = currentSession?.email ?? 'admin@billingpro.com';

    const defaultBiz = Business(
      id: 'biz_default_001',
      name: 'Billing Pro Enterprise',
      legalName: 'Billing Pro Technologies Pvt Ltd',
      gstin: '32AABCB1234A1Z1',
      pan: 'AABCB1234A',
      state: 'Kerala',
      stateCode: '32',
      address: 'Suite 402, Infopark, Kochi, Kerala, India',
      phone: '+91 7356946847',
      whatsapp: '7356946847',
      email: 'contact@billingpro.com',
      bankName: 'State Bank of India',
      accountNumber: '98765432101',
      ifsc: 'SBIN0001234',
      upiId: 'billingpro@sbi',
      currency: '₹',
      invoicePrefix: 'INV-',
    );

    _userBusinesses.clear();
    _userBusinesses.add(defaultBiz);
    _activeBusiness = defaultBiz;
    _activeRole = SaaSRole.owner;

    _activeMembers.clear();
    _activeMembers.add(
      BusinessMember(
        id: 'mem_owner_01',
        businessId: defaultBiz.id,
        userId: userId,
        email: userEmail,
        role: SaaSRole.owner,
        joinedAt: DateTime.now(),
      ),
    );

    await _saveState();
  }

  /// Switch active business workspace
  Future<bool> switchBusiness(String businessId) async {
    final found = _userBusinesses.firstWhere(
      (b) => b.id == businessId,
      orElse: () => _activeBusiness!,
    );

    if (found.id != businessId) {
      AppLogger.warn('Unauthorized attempt to switch to business: $businessId');
      return false;
    }

    _activeBusiness = found;

    // Resolve user's role in the switched business
    final member = _activeMembers.firstWhere(
      (m) => m.businessId == businessId,
      orElse: () => BusinessMember(
        id: 'mem_fallback',
        businessId: businessId,
        userId: SupabaseService.instance.currentSession?.id ?? 'usr',
        email: SupabaseService.instance.currentSession?.email ?? '',
        role: SaaSRole.owner,
        joinedAt: DateTime.now(),
      ),
    );

    _activeRole = member.role;
    await _saveState();
    return true;
  }

  /// Create a new Business workspace
  Future<Business> createBusiness({
    required String name,
    String legalName = '',
    String gstin = '',
    String pan = '',
    String state = 'Kerala',
    String stateCode = '32',
    String address = '',
    String phone = '+91 7356946847',
    String whatsapp = '7356946847',
    String email = '',
    String bankName = '',
    String accountNumber = '',
    String ifsc = '',
    String upiId = '',
    String currency = '₹',
    String invoicePrefix = 'INV-',
  }) async {
    final newId = 'biz_${DateTime.now().millisecondsSinceEpoch}';
    final newBiz = Business(
      id: newId,
      name: name.trim(),
      legalName: legalName.trim(),
      gstin: gstin.trim().toUpperCase(),
      pan: pan.trim().toUpperCase(),
      state: state,
      stateCode: stateCode,
      address: address.trim(),
      phone: phone.trim(),
      whatsapp: whatsapp.trim(),
      email: email.trim(),
      bankName: bankName.trim(),
      accountNumber: accountNumber.trim(),
      ifsc: ifsc.trim().toUpperCase(),
      upiId: upiId.trim(),
      currency: currency,
      invoicePrefix: invoicePrefix.trim().toUpperCase(),
    );

    _userBusinesses.add(newBiz);
    _activeBusiness = newBiz;
    _activeRole = SaaSRole.owner;

    final currentSession = SupabaseService.instance.currentSession;
    _activeMembers.add(
      BusinessMember(
        id: 'mem_${DateTime.now().millisecondsSinceEpoch}',
        businessId: newId,
        userId: currentSession?.id ?? 'usr',
        email: currentSession?.email ?? 'admin@company.com',
        role: SaaSRole.owner,
        joinedAt: DateTime.now(),
      ),
    );

    await _saveState();

    // Sync to Supabase if configured
    await _syncBusinessToSupabase(newBiz, SaaSRole.owner);
    return newBiz;
  }

  /// Update active business profile (restricted to Owner & Admin)
  Future<bool> updateBusinessProfile(Business updated) async {
    if (!isAdmin) {
      AppLogger.warn('Unauthorized attempt to update business profile by non-admin role: $_activeRole');
      return false;
    }

    final index = _userBusinesses.indexWhere((b) => b.id == updated.id);
    if (index >= 0) {
      _userBusinesses[index] = updated;
    }
    _activeBusiness = updated;
    await _saveState();

    await _syncBusinessToSupabase(updated, _activeRole);
    return true;
  }

  /// Invite or add a member to the active business (restricted to Owner & Admin)
  Future<bool> addMember({
    required String email,
    required SaaSRole role,
    String? userId,
  }) async {
    if (!isAdmin) {
      AppLogger.warn('Unauthorized attempt to add member by role: $_activeRole');
      return false;
    }

    final newMember = BusinessMember(
      id: 'mem_${DateTime.now().millisecondsSinceEpoch}',
      businessId: _activeBusiness!.id,
      userId: userId ?? 'usr_${DateTime.now().millisecondsSinceEpoch}',
      email: email.trim().toLowerCase(),
      role: role,
      joinedAt: DateTime.now(),
    );

    _activeMembers.add(newMember);
    await _saveState();
    return true;
  }

  /// Update a member's role (strictly restricted to Owner)
  Future<bool> updateMemberRole({
    required String memberId,
    required SaaSRole newRole,
  }) async {
    if (!isOwner) {
      AppLogger.warn('Only the business Owner can change member roles');
      return false;
    }

    final index = _activeMembers.indexWhere((m) => m.id == memberId);
    if (index >= 0) {
      final existing = _activeMembers[index];
      _activeMembers[index] = BusinessMember(
        id: existing.id,
        businessId: existing.businessId,
        userId: existing.userId,
        email: existing.email,
        role: newRole,
        joinedAt: existing.joinedAt,
      );
      await _saveState();
      return true;
    }
    return false;
  }

  /// Remove a member (strictly restricted to Owner)
  Future<bool> removeMember(String memberId) async {
    if (!isOwner) {
      AppLogger.warn('Only the business Owner can remove members');
      return false;
    }

    _activeMembers.removeWhere((m) => m.id == memberId);
    await _saveState();
    return true;
  }

  Future<void> _saveState() async {
    final payload = {
      'activeBusinessId': _activeBusiness?.id,
      'activeRole': _activeRole.name,
      'businesses': _userBusinesses.map((b) => b.toJson()).toList(),
      'members': _activeMembers.map((m) => m.toJson()).toList(),
    };
    await _storage.writeText('multi_tenant_state.json', json.encode(payload));
  }

  Future<void> _syncBusinessToSupabase(Business biz, SaaSRole role) async {
    final client = SupabaseService.instance.client;
    if (client == null) return;

    try {
      await client.from('businesses').upsert({
        'id': biz.id,
        'name': biz.name,
        'legal_name': biz.legalName,
        'gstin': biz.gstin,
        'pan': biz.pan,
        'state': biz.state,
        'state_code': biz.stateCode,
        'address': biz.address,
        'phone': biz.phone,
        'whatsapp': biz.whatsapp,
        'email': biz.email,
        'website': biz.website,
        'bank_name': biz.bankName,
        'account_number': biz.accountNumber,
        'ifsc': biz.ifsc,
        'upi_id': biz.upiId,
        'currency': biz.currency,
        'invoice_prefix': biz.invoicePrefix,
      });

      final userId = client.auth.currentUser?.id;
      if (userId != null) {
        await client.from('business_members').upsert({
          'business_id': biz.id,
          'user_id': userId,
          'role': role.name,
        }, onConflict: 'business_id, user_id');
      }
    } catch (e) {
      AppLogger.error('Error syncing business to Supabase: $e');
    }
  }
}
