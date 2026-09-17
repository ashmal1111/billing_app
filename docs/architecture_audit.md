# Architecture Audit & Technical Discovery Document

**Project**: Billing App Pro (Invoice Management SaaS)  
**Date**: September 16, 2026  
**Auditor**: Senior Software Architect, Security & QA Engineering Team  
**Phase**: Phase 0 — Project Audit & Discovery  

---

## 1. Current Technology Stack
* **Client Framework**: Flutter 3.x (Dart 3.0+ with Sound Null Safety)
* **Target Platforms**: Linux Desktop (active development), Android, iOS, Web, macOS, Windows
* **Backend Database & BaaS**: Supabase (PostgreSQL 15+, PostgREST, Supabase Auth, Row Level Security)
* **Local Persistence Layer**: Platform-abstracted file storage (`AppStorage`) backing JSON configuration, session state, and settings
* **Document Processing & Export**: `package:pdf` (v3.10.4) and `package:printing` (v5.11.1)
* **Communication & Protocols**: `url_launcher` (URI schemes for WhatsApp, email, tel)

---

## 2. Directory & Project Structure
```
/home/mohammed-ashmal-p-k/billing_app
├── analysis_options.yaml            # Dart static analysis & lint configurations
├── pubspec.yaml                     # Dependencies and asset declarations
├── lib/
│   ├── main.dart                    # Application root, state, navigation, form & dashboard
│   ├── admin_income_dashboard.dart  # Admin financial analytics & revenue breakdowns
│   ├── invoice_templates.dart       # 5 visual invoice presentation templates
│   ├── login_dialog.dart            # Authentication modal (Email/Password, Roles, Demo)
│   ├── security_service.dart        # SecurityValidator: sanitization, validation & RLS prep
│   ├── supabase_service.dart        # Supabase client singleton, auth, cloud sync & SQL schema
│   ├── app_storage.dart             # Storage abstraction factory
│   ├── app_storage_base.dart        # Base storage contract
│   ├── app_storage_io.dart          # Local file IO implementation (Linux, Desktop, Mobile)
│   ├── app_storage_web.dart         # Web localStorage implementation
│   ├── app_storage_stub.dart        # Conditional compilation fallback
│   └── domain/                      # Canonical domain models & engines
│       ├── money.dart               # High-precision integer-paise financial arithmetic
│       ├── gst_engine.dart          # Indian GST statutory logic (37 State Codes, Intra/Inter)
│       ├── models.dart              # Canonical models: Business, Customer, Product, Invoice
│       └── calculation_engine.dart  # Deterministic financial calculation single-source-of-truth
├── test/
│   ├── widget_test.dart             # Main UI widget & security validator test suite
│   └── financial_calculation_test.dart # Financial & Indian GST calculation test suite
├── linux/                           # Linux desktop native runner & bundle build files
├── android/, ios/, macos/, windows/, web/ # Cross-platform runner harnesses
└── docs/                            # Production documentation & architectural specs
```

---

## 3. Existing Pages & Navigation
The application currently implements an `IndexedStack` navigation bar with 7 primary views:
1. **Dashboard** (`_buildDashboard()`): Executive statistics, Quick Actions, recent invoices.
2. **Create Invoice** (`_buildInvoiceForm()`): Form with client details, multi-item line table, tax, discounts, notes.
3. **Preview** (`_buildInvoicePreview()`): Interactive preview with 5 visual template themes, WhatsApp sharing, text download.
4. **History** (`_buildSavedInvoices()`): Filterable invoice list with details dialog, status badges, download, delete.
5. **Income Dashboard** (`AdminIncomeDashboard`): Restricted to Administrator; displays realized income, collection rates, payment breakdown, client leaderboard.
6. **Alerts / Notifications** (`_buildNotifications()`): Activity feed of created invoices, overdue payment alerts, system events.
7. **Settings** (`_buildSettings()`): Business profile, phone, WhatsApp helpline (`7356946847`), Supabase credentials, dark mode.

---

## 4. Existing Components
* `InvoiceTemplateView`: Renders 5 graphical invoice templates (`Modern Gradient`, `Classic Corporate`, `Minimal Clean`, `Emerald Creative`, `Thermal POS Receipt`).
* `LoginDialog`: Modal supporting user login, registration, role selection (`Administrator` vs `Staff`), and demo switching.
* `AdminIncomeDashboard`: Dedicated analytics view with KPI cards, period filters (`all`, `this_month`, `last_30_days`), payment method progress indicators, and top clients leaderboard.
* `SecurityValidator`: Client-side input cleansing, path traversal prevention, and RFC format validators.

---

## 5. Existing Database Schema
Defined in `SupabaseService.supabaseSqlSchema`:
* `public.invoices`:
  - `id uuid primary key default gen_random_uuid()`
  - `user_id uuid references auth.users(id)`
  - `invoice_number varchar(50) unique`
  - `client_name varchar(100) not null`, `client_email`, `client_phone`, `client_address`, `client_gst`
  - `subtotal`, `tax_rate`, `tax_amount`, `discount_percent`, `discount_amount`, `total` with range CHECK constraints
  - `status varchar(20)` check (`paid`, `pending`, `overdue`, `cancelled`)
  - `payment_method`, `template`, `notes`, `created_at`, `updated_at`
* `public.invoice_audit_logs`:
  - `id uuid primary key`, `invoice_id uuid`, `invoice_number`, `changed_by uuid`, `action` (`INSERT`, `UPDATE`, `DELETE`), `old_data jsonb`, `new_data jsonb`, `changed_at`
* Automatic Audit Trigger: `tr_invoice_audit` capturing all changes to `public.invoices`.
* Row Level Security (RLS) policies: Admin view all / delete; Staff view own / create / update own.

---

## 6. Existing Supabase Configuration
* Configured in `SupabaseService`: reads URL and anonKey from local `supabase_config.json`.
* Fallback mechanism: If Supabase credentials are not entered or network is offline, gracefully degrades to local storage while preserving the exact same role-based permissions (`AppUserSession`).

---

## 7. Existing Authentication
* Integrated with Supabase Auth (`client.auth.signInWithPassword`, `client.auth.signUp`).
* Metadata-based role assignment (`admin` vs `staff`).
* Local demo session provider for testing without live Supabase cloud dependencies.

---

## 8. Existing API / Service Layer
* `SupabaseService`: Singleton managing client lifecycle, authentication sessions, and `syncInvoiceToCloud`.
* `AppStorage`: Platform-agnostic file IO and text/JSON persistence.
* `SecurityValidator`: Input sanitization and format validation.
* `FinancialCalculationEngine`: Deterministic paise-based math and statutory GST calculations.

---

## 9. Existing Invoice Functionality
* Full invoice draft creation with dynamic multi-item additions and removals.
* Discount handling (percentage-based).
* Local persistence in `invoices.json` and cloud sync to Supabase.
* Formatted document downloads.
* WhatsApp integration with business helpline `+91 7356946847` and pre-filled customer download links.

---

## 10. Existing Dependencies
* `supabase_flutter: ^2.8.0`
* `printing: ^5.11.1`
* `pdf: ^3.10.4`
* `intl: ^0.18.1`
* `path_provider: ^2.1.1`
* `share_plus: ^7.2.1`
* `url_launcher: ^6.3.2`
* `flutter_lints: ^3.0.0` (dev)

---

## 11. Existing Tests
* `test/widget_test.dart`: Smoke tests, navigation checks, role-based access checks, and SecurityValidator test cases.
* `test/financial_calculation_test.dart`: Integer paise arithmetic, Indian GST engine, Intra/Inter-state splits, and boundary edge cases.

---

## 12. Existing Bugs Identified
1. **Type Cast Sensitivity**: Legacy invoice JSON records with string numbers could cause `_TypeError: String is not a subtype of num` if not parsed via `num.tryParse`. Guarded in recent hotfixes.
2. **Client-Side Invoice Number Collision**: Invoice numbers generated by local sequence count (`INV-00X`) risk collision when multiple users create invoices simultaneously.
3. **Hard-Coded Single Tax Rate**: Flat tax rate in UI rather than statutory line-item GST splitting.

---

## 13. Technical Debt
* Monolithic UI file: `lib/main.dart` is ~2,700 lines containing both screen views, form state, and dialogs. Needs modularization into feature packages.
* Invoices currently downloaded as `.txt` files rather than true vector `.pdf` files using the pre-installed `pdf` package.
* Flat user ownership instead of multi-tenant `business_id` scoping.

---

## 14. Missing Features (Gap Analysis against SaaS Contract)
* Multi-tenant Business management (`businesses`, `business_members`, roles: Owner, Admin, Accountant, Employee, Viewer).
* Normalized Customer catalog (`customers`) with credit limits, state codes, and GST types.
* Normalized Product catalog (`products`) with HSN/SAC, units, and tax rates.
* Double-entry payment ledger (`payments`) supporting partial payments and payment history.
* Quotations/Estimates workflow with 1-click conversion to invoice.
* Credit Notes and Debit Notes.
* Expenses tracking module.
* True vector PDF generator matching all 5 templates.

---

## 15. Security Risks & Mitigations
* **Tenant Isolation**: Must strictly scope all tables with `business_id` and enforce Supabase RLS.
* **Client-Side Calculation Tampering**: All totals must be recalculated server-side or validated via canonical domain engine.
* **Data Finalization**: Finalized invoices must be immutable; financial adjustments must occur strictly via Credit/Debit Notes.
* **Public Document Links**: Avoid exposing permanent public URLs; use signed tokens.

---

## 16. Recommended Production Architecture
Adopt a Clean Layered Architecture:
```
Presentation Layer (Flutter UI, Modular Feature Screens, Responsive Layouts)
  ↓
Application / Service Layer (Auth, Business Context, Invoicing, Payments, Storage)
  ↓
Domain Layer (Money, GST Engine, Canonical Models, FinancialCalculationEngine)
  ↓
Data Access Layer (Supabase PostgREST, AppStorage, RLS Enforcement)
  ↓
Database Layer (PostgreSQL 15+, Multi-Tenant Schema, Audit Triggers)
```

---

## 17. Implementation Roadmap (Phases 1 — 23)
* **Phase 1**: Foundation & Architecture (Layered folder structure, base models, database migrations)
* **Phase 2**: Authentication & Multi-Tenant Business Management (RBAC, Business switching)
* **Phase 3**: Customer Management (Normalized CRM, GST types, balances)
* **Phase 4**: Product & Service Catalog (HSN/SAC, stock, autofill)
* **Phase 5**: Financial Calculation Engine (Comprehensive precision engine verification)
* **Phase 6**: GST Engine (Statutory Intra/Inter-state determination, CGST/SGST/IGST)
* **Phase 7**: Invoice Core Lifecycle (Draft, Finalization, Concurrency-safe sequencing)
* **Phase 8**: Payment Ledger (Partial payments, balance tracking, status derivation)
* **Phase 9**: Vector PDF Generation & Templates (A4, A5, Thermal 80mm/58mm)
* **Phase 10**: WhatsApp & Email Distribution (Safe encoded URLs, verified helpline)
* **Phase 11**: Estimates & Quotations (Quotation lifecycle, 1-click conversion)
* **Phase 12**: Credit Notes & Debit Notes (Statutory adjustments)
* **Phase 13**: Expenses Module (Expense categories, vendor tracking)
* **Phase 14**: Recurring Invoices (Scheduled billing engine)
* **Phase 15**: Customer Portal (Secure tokenized viewing)
* **Phase 16**: Executive Dashboard & Reports (Visual charts, financial exports)
* **Phase 17**: Inventory & Purchases (Stock movements, supplier tracking)
* **Phase 18**: Notifications Engine (Lifecycle alerts, overdue warnings)
* **Phase 19**: Audit & Compliance (Immutable tamper-proof event logs)
* **Phase 20**: Security Hardening & Penetration Testing (RLS audit, input defense)
* **Phase 21**: Performance Optimization (Indexing, pagination, caching)
* **Phase 22**: Full Automated & E2E Testing Suite
* **Phase 23**: Final Production Readiness Review
