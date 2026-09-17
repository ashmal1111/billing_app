/// Production Database Migrations & Multi-Tenant Schema Architecture
class DatabaseMigrations {
  static const int currentSchemaVersion = 1;

  /// Full production-hardened PostgreSQL migration script for Phase 1
  static const String migrationV1InitialSchema = '''
-- ============================================================================
-- BILLING APP PRO SAAS - PHASE 1 FOUNDATION MIGRATION (V1)
-- Multi-Tenant Business Architecture, RBAC & Row Level Security (RLS)
-- ============================================================================

-- 1. Enable pgcrypto for UUID generation
create extension if not exists "pgcrypto";

-- 2. Multi-Tenant Businesses Table
create table if not exists public.businesses (
  id uuid primary key default gen_random_uuid(),
  name varchar(150) not null check (char_length(trim(name)) > 0),
  legal_name varchar(150),
  gstin varchar(15),
  pan varchar(10),
  state varchar(50) not null default 'Kerala',
  state_code varchar(2) not null default '32',
  address text,
  phone varchar(25) default '+91 7356946847',
  whatsapp varchar(25) default '7356946847',
  email varchar(255),
  website varchar(255),
  bank_name varchar(100),
  account_number varchar(50),
  ifsc varchar(20),
  upi_id varchar(100),
  currency varchar(10) not null default '₹',
  invoice_prefix varchar(20) not null default 'INV-',
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now()
);

create index if not exists idx_businesses_state_code on public.businesses(state_code);

-- 3. Business Members & Role-Based Access Control (RBAC) Table
create table if not exists public.business_members (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role varchar(20) not null check (role in ('owner', 'admin', 'accountant', 'employee', 'viewer')),
  created_at timestamp with time zone not null default now(),
  unique(business_id, user_id)
);

create index if not exists idx_business_members_user on public.business_members(user_id);
create index if not exists idx_business_members_business on public.business_members(business_id);

-- 4. Helper Function to Extract Current User Role in a Business
create or replace function public.get_user_business_role(target_biz_id uuid)
returns varchar
language sql
security definer
stable
as \$\$
  select role from public.business_members
  where business_id = target_biz_id and user_id = auth.uid()
  limit 1;
\$\$;

-- 5. Helper Function to Check if User is Member of a Business
create or replace function public.is_business_member(target_biz_id uuid)
returns boolean
language sql
security definer
stable
as \$\$
  select exists (
    select 1 from public.business_members
    where business_id = target_biz_id and user_id = auth.uid()
  );
\$\$;

-- 6. Enable and Force Row Level Security (RLS) on Multi-Tenant Tables
alter table public.businesses enable row level security;
alter table public.businesses force row level security;

alter table public.business_members enable row level security;
alter table public.business_members force row level security;

-- 7. RLS Policies: public.businesses
drop policy if exists "businesses_select_member" on public.businesses;
create policy "businesses_select_member"
  on public.businesses for select
  to authenticated
  using (
    public.is_business_member(id)
  );

drop policy if exists "businesses_insert_authenticated" on public.businesses;
create policy "businesses_insert_authenticated"
  on public.businesses for insert
  to authenticated
  with check (true);

drop policy if exists "businesses_update_owner_admin" on public.businesses;
create policy "businesses_update_owner_admin"
  on public.businesses for update
  to authenticated
  using (
    public.get_user_business_role(id) in ('owner', 'admin')
  )
  with check (
    public.get_user_business_role(id) in ('owner', 'admin')
  );

drop policy if exists "businesses_delete_owner" on public.businesses;
create policy "businesses_delete_owner"
  on public.businesses for delete
  to authenticated
  using (
    public.get_user_business_role(id) = 'owner'
  );

-- 8. RLS Policies: public.business_members
drop policy if exists "members_select_coworkers" on public.business_members;
create policy "members_select_coworkers"
  on public.business_members for select
  to authenticated
  using (
    public.is_business_member(business_id)
  );

drop policy if exists "members_insert_owner_admin" on public.business_members;
create policy "members_insert_owner_admin"
  on public.business_members for insert
  to authenticated
  with check (
    public.get_user_business_role(business_id) in ('owner', 'admin')
    or not exists (select 1 from public.business_members where business_id = business_members.business_id)
  );

drop policy if exists "members_update_owner_admin" on public.business_members;
create policy "members_update_owner_admin"
  on public.business_members for update
  to authenticated
  using (
    public.get_user_business_role(business_id) in ('owner', 'admin')
  )
  with check (
    public.get_user_business_role(business_id) in ('owner', 'admin')
  );

drop policy if exists "members_delete_owner" on public.business_members;
create policy "members_delete_owner"
  on public.business_members for delete
  to authenticated
  using (
    public.get_user_business_role(business_id) = 'owner'
  );

-- 9. Customers Master Table
create table if not exists public.customers (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  name varchar(150) not null check (char_length(trim(name)) > 0),
  company_name varchar(150),
  phone varchar(25),
  email varchar(255),
  gstin varchar(15),
  pan varchar(10),
  gst_type varchar(30) not null default 'registered' check (gst_type in ('registered', 'unregistered', 'composition', 'consumer', 'overseas')),
  billing_address text,
  shipping_address text,
  state varchar(50) not null default 'Kerala',
  state_code varchar(2) not null default '32',
  credit_limit numeric(12, 2) not null default 0 check (credit_limit >= 0),
  payment_terms varchar(50) default 'Due on Receipt',
  notes text,
  is_archived boolean not null default false,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now()
);

create index if not exists idx_customers_business on public.customers(business_id);
create index if not exists idx_customers_gstin on public.customers(gstin);

alter table public.customers enable row level security;
alter table public.customers force row level security;

-- Customers RLS: members can select customers in their business
drop policy if exists "customers_select_member" on public.customers;
create policy "customers_select_member"
  on public.customers for select
  to authenticated
  using (
    public.is_business_member(business_id)
  );

-- Customers RLS: operational roles (owner, admin, accountant, employee) can insert
drop policy if exists "customers_insert_member" on public.customers;
create policy "customers_insert_member"
  on public.customers for insert
  to authenticated
  with check (
    public.get_user_business_role(business_id) in ('owner', 'admin', 'accountant', 'employee')
  );

-- Customers RLS: operational roles can update
drop policy if exists "customers_update_member" on public.customers;
create policy "customers_update_member"
  on public.customers for update
  to authenticated
  using (
    public.get_user_business_role(business_id) in ('owner', 'admin', 'accountant', 'employee')
  )
  with check (
    public.get_user_business_role(business_id) in ('owner', 'admin', 'accountant', 'employee')
  );

-- Customers RLS: only owner and admin can delete / archive
drop policy if exists "customers_delete_admin" on public.customers;
create policy "customers_delete_admin"
  on public.customers for delete
  to authenticated
  using (
    public.get_user_business_role(business_id) in ('owner', 'admin')
  );

-- 10. Products & Services Master Table
create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  name varchar(200) not null check (char_length(trim(name)) > 0),
  sku varchar(100),
  description text,
  category varchar(100) not null default 'General',
  hsn_sac varchar(20) not null,
  unit varchar(20) not null default 'Pcs',
  cost_price numeric(12, 2) not null default 0 check (cost_price >= 0),
  selling_price numeric(12, 2) not null check (selling_price >= 0),
  gst_rate numeric(5, 2) not null default 18.0 check (gst_rate in (0.0, 5.0, 12.0, 18.0, 28.0)),
  is_tax_inclusive boolean not null default false,
  stock_quantity numeric(10, 2) not null default 0,
  low_stock_threshold numeric(10, 2) not null default 5,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now()
);

create index if not exists idx_products_business on public.products(business_id);
create index if not exists idx_products_category on public.products(category);
create index if not exists idx_products_hsn_sac on public.products(hsn_sac);

alter table public.products enable row level security;
alter table public.products force row level security;

-- Products RLS: members can select products in their business
drop policy if exists "products_select_member" on public.products;
create policy "products_select_member"
  on public.products for select
  to authenticated
  using (
    public.is_business_member(business_id)
  );

-- Products RLS: operational roles can insert
drop policy if exists "products_insert_member" on public.products;
create policy "products_insert_member"
  on public.products for insert
  to authenticated
  with check (
    public.get_user_business_role(business_id) in ('owner', 'admin', 'accountant', 'employee')
  );

-- Products RLS: operational roles can update
drop policy if exists "products_update_member" on public.products;
create policy "products_update_member"
  on public.products for update
  to authenticated
  using (
    public.get_user_business_role(business_id) in ('owner', 'admin', 'accountant', 'employee')
  )
  with check (
    public.get_user_business_role(business_id) in ('owner', 'admin', 'accountant', 'employee')
  );

-- Products RLS: only owner and admin can delete products
drop policy if exists "products_delete_admin" on public.products;
create policy "products_delete_admin"
  on public.products for delete
  to authenticated
  using (
    public.get_user_business_role(business_id) in ('owner', 'admin')
  );
''';
}
