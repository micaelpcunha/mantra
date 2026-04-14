-- Asset devices inside assets, with QR and attached documentation.
-- Apply after the current multi-company foundation/helpers are available,
-- namely `public.companies`, `public.assets`, `public.current_user_company_id()`,
-- `public.belongs_to_current_company(...)` and the role/permission helpers.

begin;

create extension if not exists pgcrypto;

alter table if exists public.profiles
  add column if not exists can_edit_asset_devices boolean not null default false;

alter table if exists public.technicians
  add column if not exists can_edit_asset_devices boolean not null default false;

update public.profiles
set can_edit_asset_devices = coalesce(can_edit_assets, false)
where can_edit_asset_devices is distinct from coalesce(can_edit_assets, false);

update public.technicians
set can_edit_asset_devices = coalesce(can_edit_assets, false)
where can_edit_asset_devices is distinct from coalesce(can_edit_assets, false);

create or replace function public.profile_flag(flag_name text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    case flag_name
      when 'can_access_assets' then (public.current_user_profile()).can_access_assets
      when 'can_access_locations' then (public.current_user_profile()).can_access_locations
      when 'can_access_work_orders' then (public.current_user_profile()).can_access_work_orders
      when 'can_create_work_orders' then (public.current_user_profile()).can_create_work_orders
      when 'can_view_all_work_orders' then (public.current_user_profile()).can_view_all_work_orders
      when 'can_close_work_orders' then (public.current_user_profile()).can_close_work_orders
      when 'can_edit_work_orders' then (public.current_user_profile()).can_edit_work_orders
      when 'can_edit_assets' then (public.current_user_profile()).can_edit_assets
      when 'can_edit_asset_devices' then (public.current_user_profile()).can_edit_asset_devices
      when 'can_edit_locations' then (public.current_user_profile()).can_edit_locations
      when 'can_view_alerts' then (public.current_user_profile()).can_view_alerts
      when 'can_manage_technicians' then (public.current_user_profile()).can_manage_technicians
      when 'can_manage_users' then (public.current_user_profile()).can_manage_users
      else false
    end,
    false
  )
$$;

create or replace function public.technician_record_allows(flag_name text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (
      select case flag_name
        when 'can_access_assets' then t.can_access_assets
        when 'can_access_locations' then t.can_access_locations
        when 'can_access_work_orders' then t.can_access_work_orders
        when 'can_create_work_orders' then t.can_create_work_orders
        when 'can_view_all_work_orders' then t.can_view_all_work_orders
        when 'can_close_work_orders' then t.can_close_work_orders
        when 'can_edit_work_orders' then t.can_edit_work_orders
        when 'can_edit_assets' then t.can_edit_assets
        when 'can_edit_asset_devices' then t.can_edit_asset_devices
        when 'can_edit_locations' then t.can_edit_locations
        when 'can_view_alerts' then t.can_view_alerts
        when 'can_manage_technicians' then t.can_manage_technicians
        when 'can_manage_users' then t.can_manage_users
        else false
      end
      from public.technicians t
      where t.id = public.current_user_technician_id()
        and public.belongs_to_current_company(t.company_id)
      limit 1
    ),
    false
  )
$$;

create table if not exists public.asset_devices (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null,
  asset_id uuid not null,
  name text not null,
  description text,
  manufacturer_reference text,
  internal_reference text,
  qr_code text,
  documentation jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

alter table if exists public.asset_devices
  add column if not exists company_id uuid;

alter table if exists public.asset_devices
  add column if not exists asset_id uuid;

alter table if exists public.asset_devices
  add column if not exists name text;

alter table if exists public.asset_devices
  add column if not exists description text;

alter table if exists public.asset_devices
  add column if not exists manufacturer_reference text;

alter table if exists public.asset_devices
  add column if not exists internal_reference text;

alter table if exists public.asset_devices
  add column if not exists qr_code text;

alter table if exists public.asset_devices
  add column if not exists documentation jsonb not null default '[]'::jsonb;

alter table if exists public.asset_devices
  add column if not exists created_at timestamptz not null default timezone('utc', now());

alter table if exists public.asset_devices
  add column if not exists updated_at timestamptz not null default timezone('utc', now());

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'asset_devices'
      and column_name = 'notes'
  ) then
    execute '
      update public.asset_devices
      set description = coalesce(description, nullif(trim(notes), ''''))
      where (description is null or nullif(trim(description), '''') is null)
        and nullif(trim(notes), '''') is not null
    ';
  end if;

  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'asset_devices'
      and column_name = 'reference'
  ) then
    execute '
      update public.asset_devices
      set internal_reference = coalesce(internal_reference, nullif(trim(reference), ''''))
      where (internal_reference is null or nullif(trim(internal_reference), '''') is null)
        and nullif(trim(reference), '''') is not null
    ';
  end if;

  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'asset_devices'
      and column_name = 'serial_number'
  ) then
    execute '
      update public.asset_devices
      set manufacturer_reference = coalesce(manufacturer_reference, nullif(trim(serial_number), ''''))
      where (manufacturer_reference is null or nullif(trim(manufacturer_reference), '''') is null)
        and nullif(trim(serial_number), '''') is not null
    ';
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'asset_devices_company_id_fkey'
  ) then
    alter table public.asset_devices
      add constraint asset_devices_company_id_fkey
      foreign key (company_id)
      references public.companies(id)
      on delete cascade;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'asset_devices_asset_id_fkey'
  ) then
    alter table public.asset_devices
      add constraint asset_devices_asset_id_fkey
      foreign key (asset_id)
      references public.assets(id)
      on delete cascade;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'asset_devices_name_not_blank'
  ) then
    alter table public.asset_devices
      add constraint asset_devices_name_not_blank
      check (nullif(trim(name), '') is not null);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'asset_devices_documentation_is_array'
  ) then
    alter table public.asset_devices
      add constraint asset_devices_documentation_is_array
      check (jsonb_typeof(documentation) = 'array');
  end if;
end
$$;

update public.asset_devices d
set
  company_id = a.company_id,
  documentation = case
    when d.documentation is null then '[]'::jsonb
    when jsonb_typeof(d.documentation) = 'array' then d.documentation
    else '[]'::jsonb
  end,
  created_at = coalesce(d.created_at, timezone('utc', now())),
  updated_at = coalesce(d.updated_at, timezone('utc', now())),
  qr_code = nullif(trim(d.qr_code), '')
from public.assets a
where a.id = d.asset_id
  and (
    d.company_id is distinct from a.company_id
    or d.documentation is null
    or jsonb_typeof(d.documentation) <> 'array'
    or d.created_at is null
    or d.updated_at is null
    or (d.qr_code is not null and nullif(trim(d.qr_code), '') is null)
  );

create index if not exists asset_devices_company_id_idx
  on public.asset_devices (company_id);

create index if not exists asset_devices_asset_id_idx
  on public.asset_devices (asset_id);

create index if not exists asset_devices_company_asset_name_idx
  on public.asset_devices (company_id, asset_id, name);

create unique index if not exists asset_devices_company_qr_code_key
  on public.asset_devices (company_id, qr_code)
  where qr_code is not null and nullif(trim(qr_code), '') is not null;

create or replace function public.sync_asset_device_company_id()
returns trigger
language plpgsql
security definer
set search_path = public
as $function$
declare
  resolved_company_id uuid;
begin
  if new.asset_id is null then
    raise exception 'asset_id is required for asset_devices';
  end if;

  select a.company_id
  into resolved_company_id
  from public.assets a
  where a.id = new.asset_id
  limit 1;

  if resolved_company_id is null then
    raise exception 'Nao foi possivel resolver a empresa do dispositivo a partir do ativo.';
  end if;

  new.company_id := resolved_company_id;
  return new;
end;
$function$;

create or replace function public.touch_asset_devices_updated_at()
returns trigger
language plpgsql
as $function$
begin
  new.updated_at := timezone('utc', now());
  return new;
end;
$function$;

drop trigger if exists set_asset_devices_company_id
on public.asset_devices;

create trigger set_asset_devices_company_id
before insert or update of asset_id, company_id
on public.asset_devices
for each row
execute function public.sync_asset_device_company_id();

drop trigger if exists touch_asset_devices_updated_at
on public.asset_devices;

create trigger touch_asset_devices_updated_at
before update
on public.asset_devices
for each row
execute function public.touch_asset_devices_updated_at();

alter table if exists public.asset_devices enable row level security;

drop policy if exists "asset_devices_select_scoped"
on public.asset_devices;
create policy "asset_devices_select_scoped"
on public.asset_devices
for select
to authenticated
using (
  public.belongs_to_current_company(company_id)
  and (
    public.is_admin()
    or (
      public.is_technician()
      and public.can_access_assets_scope()
    )
    or (
      public.is_client()
      and public.client_can_access_asset(asset_id::text)
    )
  )
);

drop policy if exists "asset_devices_insert_admin_or_editor"
on public.asset_devices;
create policy "asset_devices_insert_admin_or_editor"
on public.asset_devices
for insert
to authenticated
with check (
  public.belongs_to_current_company(company_id)
  and (
    public.is_admin()
    or (
      public.is_technician()
      and public.can_access_assets_scope()
      and public.profile_flag('can_edit_asset_devices')
      and public.technician_record_allows('can_edit_asset_devices')
    )
  )
);

drop policy if exists "asset_devices_update_admin_or_editor"
on public.asset_devices;
create policy "asset_devices_update_admin_or_editor"
on public.asset_devices
for update
to authenticated
using (
  public.belongs_to_current_company(company_id)
  and (
    public.is_admin()
    or (
      public.is_technician()
      and public.can_access_assets_scope()
      and public.profile_flag('can_edit_asset_devices')
      and public.technician_record_allows('can_edit_asset_devices')
    )
  )
)
with check (
  public.belongs_to_current_company(company_id)
  and (
    public.is_admin()
    or (
      public.is_technician()
      and public.can_access_assets_scope()
      and public.profile_flag('can_edit_asset_devices')
      and public.technician_record_allows('can_edit_asset_devices')
    )
  )
);

drop policy if exists "asset_devices_delete_admin_only"
on public.asset_devices;
create policy "asset_devices_delete_admin_only"
on public.asset_devices
for delete
to authenticated
using (
  public.is_admin()
  and public.belongs_to_current_company(company_id)
);

commit;
