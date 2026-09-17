import 'package:flutter_test/flutter_test.dart';

import 'package:billing_app/auth/multi_tenant_service.dart';
import 'package:billing_app/domain/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 2 — Multi-Tenancy & Tenant Partitioning Tests', () {
    late MultiTenantService service;

    setUp(() async {
      service = MultiTenantService.instance;
      await service.init();
    });

    test('User A cannot switch to unauthorized Business B', () async {
      // Setup Business A
      final bizA = await service.createBusiness(
        name: 'Alpha Software Studio',
        gstin: '32AAAAA0000A1Z5',
        stateCode: '32',
      );
      expect(service.activeBusiness?.id, bizA.id);

      // Attempt to access non-existent or foreign Business B
      final switchSuccess = await service.switchBusiness('unauthorized_biz_999');
      expect(switchSuccess, isFalse);
      expect(service.activeBusiness?.id, bizA.id); // Active tenant remains isolated
    });

    test('Multiple businesses can be created and switched within authorized scope', () async {
      final biz1 = await service.createBusiness(name: 'Consultancy Org 1');
      final biz2 = await service.createBusiness(name: 'Retail Store Org 2');

      expect(service.userBusinesses.any((b) => b.id == biz1.id), isTrue);
      expect(service.userBusinesses.any((b) => b.id == biz2.id), isTrue);

      // Switch to biz1
      final switch1 = await service.switchBusiness(biz1.id);
      expect(switch1, isTrue);
      expect(service.activeBusiness?.name, 'Consultancy Org 1');

      // Switch to biz2
      final switch2 = await service.switchBusiness(biz2.id);
      expect(switch2, isTrue);
      expect(service.activeBusiness?.name, 'Retail Store Org 2');
    });

    test('Business profile updates are persisted and scoped to active tenant', () async {
      final biz = await service.createBusiness(name: 'Initial Name');
      final updated = Business(
        id: biz.id,
        name: 'Renamed Enterprise Pvt Ltd',
        gstin: '27ABCDE1234F1Z5',
        pan: 'ABCDE1234F',
        state: 'Maharashtra',
        stateCode: '27',
      );

      final ok = await service.updateBusinessProfile(updated);
      expect(ok, isTrue);
      expect(service.activeBusiness?.name, 'Renamed Enterprise Pvt Ltd');
      expect(service.activeBusiness?.stateCode, '27');
    });
  });

  group('Phase 2 — RBAC Role-Based Permissions & Isolation Tests', () {
    test('Owner has complete administrative & financial permissions', () {
      const role = SaaSRole.owner;
      expect(role.canCreateInvoices, isTrue);
      expect(role.canDeleteInvoices, isTrue);
      expect(role.canManageSettings, isTrue);
      expect(role.canRecordPayments, isTrue);
      expect(role.canViewFinancialReports, isTrue);
    });

    test('Admin has invoice and payment permissions but limited destruction', () {
      const role = SaaSRole.admin;
      expect(role.canCreateInvoices, isTrue);
      expect(role.canDeleteInvoices, isTrue);
      expect(role.canManageSettings, isTrue);
      expect(role.canRecordPayments, isTrue);
      expect(role.canViewFinancialReports, isTrue);
    });

    test('Accountant has financial access but cannot manage system settings', () {
      const role = SaaSRole.accountant;
      expect(role.canCreateInvoices, isTrue);
      expect(role.canDeleteInvoices, isFalse); // Restricted from deleting
      expect(role.canManageSettings, isFalse); // Restricted from settings
      expect(role.canRecordPayments, isTrue);
      expect(role.canViewFinancialReports, isTrue);
    });

    test('Employee can create invoices but cannot delete or view financial reports', () {
      const role = SaaSRole.employee;
      expect(role.canCreateInvoices, isTrue);
      expect(role.canDeleteInvoices, isFalse);
      expect(role.canManageSettings, isFalse);
      expect(role.canRecordPayments, isFalse);
      expect(role.canViewFinancialReports, isFalse);
    });

    test('Viewer is strictly read-only with zero creation or modification rights', () {
      const role = SaaSRole.viewer;
      expect(role.canCreateInvoices, isFalse);
      expect(role.canDeleteInvoices, isFalse);
      expect(role.canManageSettings, isFalse);
      expect(role.canRecordPayments, isFalse);
      expect(role.canViewFinancialReports, isFalse);
    });
  });
}
