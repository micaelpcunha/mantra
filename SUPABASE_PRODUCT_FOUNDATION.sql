-- Product foundation draft for turning asset_app into a reusable multi-company app.
-- This script is intentionally additive and backward compatible with the current app.
-- It does not replace the active RLS policies yet.

begin;

create extension if not exists pgcrypto;

-- ============================================================================
-- Companies
-- ============================================================================

create table if not exists public.companies (
  id uuid primary key default gen_random_uuid(),
  slug text unique,
  display_name text not null,
  legal_name text,
  status text not null default 'active',
  onboarding_status text not null default 'legacy_imported',
  default_locale text not null default 'pt-PT',
  default_timezone text not null default 'Europe/Lisbon',
  plan_code text not null default 'starter',
  settings jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint companies_status_check
    check (status in ('active', 'suspended', 'archived')),
  constraint companies_onboarding_status_check
    check (onboarding_status in ('draft', 'active', 'legacy_imported'))
);

-- If `companies` already exists from an earlier draft/manual attempt,
-- make sure the expected columns also exist.
alter table if exists public.companies
  add column if not exists slug text;

alter table if exists public.companies
  add column if not exists display_name text not null default 'Empresa Principal';

alter table if exists public.companies
  add column if not exists legal_name text;

alter table if exists public.companies
  add column if not exists status text not null default 'active';

alter table if exists public.companies
  add column if not exists onboarding_status text not null default 'legacy_imported';

alter table if exists public.companies
  add column if not exists default_locale text not null default 'pt-PT';

alter table if exists public.companies
  add column if not exists default_timezone text not null default 'Europe/Lisbon';

alter table if exists public.companies
  add column if not exists plan_code text not null default 'starter';

alter table if exists public.companies
  add column if not exists settings jsonb not null default '{}'::jsonb;

alter table if exists public.companies
  add column if not exists created_at timestamptz not null default timezone('utc', now());

alter table if exists public.companies
  add column if not exists updated_at timestamptz not null default timezone('utc', now());

update public.companies
set
  display_name = coalesce(nullif(trim(display_name), ''), 'Empresa Principal'),
  status = coalesce(nullif(trim(status), ''), 'active'),
  onboarding_status = coalesce(nullif(trim(onboarding_status), ''), 'legacy_imported'),
  default_locale = coalesce(nullif(trim(default_locale), ''), 'pt-PT'),
  default_timezone = coalesce(nullif(trim(default_timezone), ''), 'Europe/Lisbon'),
  plan_code = coalesce(nullif(trim(plan_code), ''), 'starter'),
  settings = coalesce(settings, '{}'::jsonb),
  created_at = coalesce(created_at, timezone('utc', now())),
  updated_at = coalesce(updated_at, timezone('utc', now()))
where
  display_name is null
  or nullif(trim(display_name), '') is null
  or status is null
  or nullif(trim(status), '') is null
  or onboarding_status is null
  or nullif(trim(onboarding_status), '') is null
  or default_locale is null
  or nullif(trim(default_locale), '') is null
  or default_timezone is null
  or nullif(trim(default_timezone), '') is null
  or plan_code is null
  or nullif(trim(plan_code), '') is null
  or settings is null
  or created_at is null
  or updated_at is null;

-- Create one default company for the current legacy dataset.
do $$
declare
  default_company_id uuid;
  inferred_name text;
begin
  select c.id
  into default_company_id
  from public.companies c
  order by c.created_at
  limit 1;

  if default_company_id is null then
    select coalesce(nullif(trim(cp.name), ''), 'Empresa Principal')
    into inferred_name
    from public.company_profile cp
    order by cp.created_at
    limit 1;

    insert into public.companies (
      slug,
      display_name,
      onboarding_status,
      settings
    )
    values (
      'empresa-principal',
      coalesce(inferred_name, 'Empresa Principal'),
      'legacy_imported',
      jsonb_build_object(
        'branding_mode', 'custom',
        'product_ready', true
      )
    )
    returning id into default_company_id;
  end if;
end
$$;

-- ============================================================================
-- Company ownership on current tables
-- ============================================================================

alter table if exists public.profiles
  add column if not exists company_id uuid;

alter table if exists public.technicians
  add column if not exists company_id uuid;

alter table if exists public.profiles
  add column if not exists can_edit_asset_devices boolean not null default false;

alter table if exists public.technicians
  add column if not exists can_edit_asset_devices boolean not null default false;

alter table if exists public.assets
  add column if not exists company_id uuid;

alter table if exists public.locations
  add column if not exists company_id uuid;

alter table if exists public.work_orders
  add column if not exists company_id uuid;

alter table if exists public.company_profile
  add column if not exists company_id uuid;

alter table if exists public.admin_notifications
  add column if not exists company_id uuid;

alter table if exists public.notes
  add column if not exists company_id uuid;

do $$
declare
  default_company_id uuid;
begin
  select c.id
  into default_company_id
  from public.companies c
  order by c.created_at
  limit 1;

  update public.profiles
  set company_id = default_company_id
  where company_id is null;

  update public.technicians
  set company_id = default_company_id
  where company_id is null;

  update public.profiles
  set can_edit_asset_devices = coalesce(can_edit_assets, false)
  where can_edit_asset_devices is distinct from coalesce(can_edit_assets, false);

  update public.technicians
  set can_edit_asset_devices = coalesce(can_edit_assets, false)
  where can_edit_asset_devices is distinct from coalesce(can_edit_assets, false);

  update public.assets
  set company_id = default_company_id
  where company_id is null;

  update public.locations
  set company_id = default_company_id
  where company_id is null;

  update public.work_orders
  set company_id = default_company_id
  where company_id is null;

  update public.company_profile
  set company_id = default_company_id
  where company_id is null;

  if to_regclass('public.admin_notifications') is not null then
    update public.admin_notifications
    set company_id = default_company_id
    where company_id is null;
  end if;

  if to_regclass('public.notes') is not null then
    update public.notes
    set company_id = default_company_id
    where company_id is null;
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'profiles_company_id_fkey'
  ) then
    alter table public.profiles
      add constraint profiles_company_id_fkey
      foreign key (company_id) references public.companies(id) on delete restrict;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'technicians_company_id_fkey'
  ) then
    alter table public.technicians
      add constraint technicians_company_id_fkey
      foreign key (company_id) references public.companies(id) on delete restrict;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'assets_company_id_fkey'
  ) then
    alter table public.assets
      add constraint assets_company_id_fkey
      foreign key (company_id) references public.companies(id) on delete restrict;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'locations_company_id_fkey'
  ) then
    alter table public.locations
      add constraint locations_company_id_fkey
      foreign key (company_id) references public.companies(id) on delete restrict;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'work_orders_company_id_fkey'
  ) then
    alter table public.work_orders
      add constraint work_orders_company_id_fkey
      foreign key (company_id) references public.companies(id) on delete restrict;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'company_profile_company_id_fkey'
  ) then
    alter table public.company_profile
      add constraint company_profile_company_id_fkey
      foreign key (company_id) references public.companies(id) on delete cascade;
  end if;

  if to_regclass('public.admin_notifications') is not null and not exists (
    select 1
    from pg_constraint
    where conname = 'admin_notifications_company_id_fkey'
  ) then
    alter table public.admin_notifications
      add constraint admin_notifications_company_id_fkey
      foreign key (company_id) references public.companies(id) on delete restrict;
  end if;

  if to_regclass('public.notes') is not null and not exists (
    select 1
    from pg_constraint
    where conname = 'notes_company_id_fkey'
  ) then
    alter table public.notes
      add constraint notes_company_id_fkey
      foreign key (company_id) references public.companies(id) on delete cascade;
  end if;
end
$$;

create unique index if not exists company_profile_company_id_key
  on public.company_profile (company_id)
  where company_id is not null;

create index if not exists profiles_company_id_idx on public.profiles (company_id);
create index if not exists technicians_company_id_idx on public.technicians (company_id);
create index if not exists assets_company_id_idx on public.assets (company_id);
create index if not exists locations_company_id_idx on public.locations (company_id);
create index if not exists work_orders_company_id_idx on public.work_orders (company_id);

do $$
begin
  if to_regclass('public.admin_notifications') is not null then
    execute '
      create index if not exists admin_notifications_company_id_idx
      on public.admin_notifications (company_id)
    ';
  end if;

  if to_regclass('public.notes') is not null then
    execute '
      create index if not exists notes_company_id_idx
      on public.notes (company_id)
    ';
  end if;
end
$$;

-- ============================================================================
-- Helper functions for multi-company foundation
-- ============================================================================

create or replace function public.current_user_company_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select p.company_id
  from public.profiles p
  where p.id = auth.uid()
  limit 1
$$;

create or replace function public.belongs_to_current_company(target_company_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select target_company_id is not null
    and target_company_id = public.current_user_company_id()
$$;

-- ============================================================================
-- Automatic company scoping on insert
-- ============================================================================

create or replace function public.apply_current_company_id()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.company_id is null then
    new.company_id := public.current_user_company_id();
  end if;

  return new;
end
$$;

drop trigger if exists set_profiles_company_id on public.profiles;
create trigger set_profiles_company_id
before insert on public.profiles
for each row
execute function public.apply_current_company_id();

drop trigger if exists set_technicians_company_id on public.technicians;
create trigger set_technicians_company_id
before insert on public.technicians
for each row
execute function public.apply_current_company_id();

drop trigger if exists set_assets_company_id on public.assets;
create trigger set_assets_company_id
before insert on public.assets
for each row
execute function public.apply_current_company_id();

drop trigger if exists set_locations_company_id on public.locations;
create trigger set_locations_company_id
before insert on public.locations
for each row
execute function public.apply_current_company_id();

drop trigger if exists set_work_orders_company_id on public.work_orders;
create trigger set_work_orders_company_id
before insert on public.work_orders
for each row
execute function public.apply_current_company_id();

drop trigger if exists set_company_profile_company_id on public.company_profile;
create trigger set_company_profile_company_id
before insert on public.company_profile
for each row
execute function public.apply_current_company_id();

do $$
begin
  if to_regclass('public.admin_notifications') is not null then
    execute '
      drop trigger if exists set_admin_notifications_company_id on public.admin_notifications
    ';
    execute '
      create trigger set_admin_notifications_company_id
      before insert on public.admin_notifications
      for each row
      execute function public.apply_current_company_id()
    ';
  end if;

  if to_regclass('public.notes') is not null then
    execute '
      drop trigger if exists set_notes_company_id on public.notes
    ';
    execute '
      create trigger set_notes_company_id
      before insert on public.notes
      for each row
      execute function public.apply_current_company_id()
    ';
  end if;
end
$$;

-- ============================================================================
-- Product-level personalization foundation
-- ============================================================================

create table if not exists public.custom_field_definitions (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  entity_type text not null,
  field_key text not null,
  label text not null,
  field_type text not null,
  help_text text,
  placeholder text,
  is_required boolean not null default false,
  is_active boolean not null default true,
  sort_order integer not null default 0,
  options jsonb not null default '[]'::jsonb,
  settings jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint custom_field_definitions_entity_type_check
    check (entity_type in ('asset', 'work_order', 'location', 'technician', 'client')),
  constraint custom_field_definitions_field_type_check
    check (
      field_type in ('text', 'multiline', 'number', 'date', 'datetime', 'boolean', 'select', 'multiselect', 'email', 'url')
    ),
  constraint custom_field_definitions_company_entity_key_key
    unique (company_id, entity_type, field_key)
);

create index if not exists custom_field_definitions_company_entity_idx
  on public.custom_field_definitions (company_id, entity_type, sort_order, label);

create table if not exists public.custom_field_values (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  definition_id uuid not null references public.custom_field_definitions(id) on delete cascade,
  entity_type text not null,
  entity_id text not null,
  value_text text,
  value_number numeric,
  value_boolean boolean,
  value_date date,
  value_datetime timestamptz,
  value_json jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint custom_field_values_company_definition_entity_key
    unique (company_id, definition_id, entity_id),
  constraint custom_field_values_entity_type_check
    check (entity_type in ('asset', 'work_order', 'location', 'technician', 'client'))
);

create index if not exists custom_field_values_lookup_idx
  on public.custom_field_values (company_id, entity_type, entity_id);

commit;
