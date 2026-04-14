-- Supabase security hardening draft for asset_app
-- Review carefully before applying in production.
-- This script assumes the tables and columns used by the Flutter app exist.

begin;

-- ============================================================================
-- Helper functions
-- ============================================================================

create or replace function public.current_user_profile()
returns public.profiles
language sql
stable
security definer
set search_path = public
as $$
  select p.*
  from public.profiles p
  where p.id = auth.uid()
  limit 1
$$;

create or replace function public.current_user_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((public.current_user_profile()).role, '')
$$;

create or replace function public.current_user_technician_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select nullif((public.current_user_profile()).technician_id::text, '')::uuid
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.current_user_role() = 'admin'
$$;

create or replace function public.is_technician()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.current_user_role() = 'technician'
$$;

create or replace function public.is_client()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.current_user_role() = 'client'
$$;

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

create or replace function public.client_can_access_asset(asset_id text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    public.is_admin()
    or (
      public.is_client()
      and (
        asset_id::uuid = any(coalesce((public.current_user_profile()).client_asset_ids, '{}'::uuid[]))
        or exists (
          select 1
          from public.assets a
          where a.id::text = asset_id
            and a.location_id = any(
              coalesce((public.current_user_profile()).client_location_ids, '{}'::uuid[])
            )
        )
      )
    )
$$;

create or replace function public.client_can_access_location(location_id text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    public.is_admin()
    or (
      public.is_client()
      and (
        location_id::uuid = any(coalesce((public.current_user_profile()).client_location_ids, '{}'::uuid[]))
        or exists (
          select 1
          from public.assets a
          where a.location_id::text = location_id
            and a.id = any(
              coalesce((public.current_user_profile()).client_asset_ids, '{}'::uuid[])
            )
        )
      )
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
      limit 1
    ),
    false
  )
$$;

create or replace function public.can_access_assets_scope()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_admin()
      or (public.is_technician() and public.profile_flag('can_access_assets') and public.technician_record_allows('can_access_assets'))
      or public.is_client()
$$;

create or replace function public.can_access_locations_scope()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_admin()
      or (public.is_technician() and public.profile_flag('can_access_locations') and public.technician_record_allows('can_access_locations'))
      or public.is_client()
$$;

create or replace function public.can_access_work_orders_scope()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_admin()
      or (public.is_technician() and public.profile_flag('can_access_work_orders') and public.technician_record_allows('can_access_work_orders'))
      or public.is_client()
$$;

-- ============================================================================
-- Enable RLS
-- ============================================================================

alter table if exists public.profiles enable row level security;
alter table if exists public.technicians enable row level security;
alter table if exists public.assets enable row level security;
alter table if exists public.locations enable row level security;
alter table if exists public.work_orders enable row level security;
alter table if exists public.company_profile enable row level security;
alter table if exists public.admin_notifications enable row level security;

-- ============================================================================
-- Profiles
-- ============================================================================

drop policy if exists "profiles_select_self_or_admin" on public.profiles;
create policy "profiles_select_self_or_admin"
on public.profiles
for select
to authenticated
using (
  public.is_admin() or id = auth.uid()
);

drop policy if exists "profiles_insert_admin_only" on public.profiles;
create policy "profiles_insert_admin_only"
on public.profiles
for insert
to authenticated
with check (
  public.is_admin()
);

drop policy if exists "profiles_update_admin_only" on public.profiles;
create policy "profiles_update_admin_only"
on public.profiles
for update
to authenticated
using (
  public.is_admin()
)
with check (
  public.is_admin()
);

drop policy if exists "profiles_delete_admin_only" on public.profiles;
create policy "profiles_delete_admin_only"
on public.profiles
for delete
to authenticated
using (
  public.is_admin()
);

-- ============================================================================
-- Technicians
-- ============================================================================

drop policy if exists "technicians_select_admin_or_self" on public.technicians;
create policy "technicians_select_admin_or_self"
on public.technicians
for select
to authenticated
using (
  public.is_admin()
  or id = public.current_user_technician_id()
);

drop policy if exists "technicians_insert_admin_only" on public.technicians;
create policy "technicians_insert_admin_only"
on public.technicians
for insert
to authenticated
with check (
  public.is_admin()
);

drop policy if exists "technicians_update_admin_only" on public.technicians;
create policy "technicians_update_admin_only"
on public.technicians
for update
to authenticated
using (
  public.is_admin()
)
with check (
  public.is_admin()
);

drop policy if exists "technicians_delete_admin_only" on public.technicians;
create policy "technicians_delete_admin_only"
on public.technicians
for delete
to authenticated
using (
  public.is_admin()
);

-- ============================================================================
-- Assets
-- ============================================================================

drop policy if exists "assets_select_scoped" on public.assets;
create policy "assets_select_scoped"
on public.assets
for select
to authenticated
using (
  public.is_admin()
  or (
    public.is_technician()
    and public.can_access_assets_scope()
  )
  or (
    public.is_client()
    and public.client_can_access_asset(id::text)
  )
);

drop policy if exists "assets_insert_admin_or_editor" on public.assets;
create policy "assets_insert_admin_or_editor"
on public.assets
for insert
to authenticated
with check (
  public.is_admin()
  or (
    public.is_technician()
    and public.profile_flag('can_edit_assets')
    and public.technician_record_allows('can_edit_assets')
  )
);

drop policy if exists "assets_update_admin_or_editor" on public.assets;
create policy "assets_update_admin_or_editor"
on public.assets
for update
to authenticated
using (
  public.is_admin()
  or (
    public.is_technician()
    and public.profile_flag('can_edit_assets')
    and public.technician_record_allows('can_edit_assets')
  )
)
with check (
  public.is_admin()
  or (
    public.is_technician()
    and public.profile_flag('can_edit_assets')
    and public.technician_record_allows('can_edit_assets')
  )
);

drop policy if exists "assets_delete_admin_only" on public.assets;
create policy "assets_delete_admin_only"
on public.assets
for delete
to authenticated
using (
  public.is_admin()
);

-- ============================================================================
-- Locations
-- ============================================================================

drop policy if exists "locations_select_scoped" on public.locations;
create policy "locations_select_scoped"
on public.locations
for select
to authenticated
using (
  public.is_admin()
  or (
    public.is_technician()
    and public.can_access_locations_scope()
  )
  or (
    public.is_client()
    and public.client_can_access_location(id::text)
  )
);

drop policy if exists "locations_insert_admin_or_editor" on public.locations;
create policy "locations_insert_admin_or_editor"
on public.locations
for insert
to authenticated
with check (
  public.is_admin()
  or (
    public.is_technician()
    and public.profile_flag('can_edit_locations')
    and public.technician_record_allows('can_edit_locations')
  )
);

drop policy if exists "locations_update_admin_or_editor" on public.locations;
create policy "locations_update_admin_or_editor"
on public.locations
for update
to authenticated
using (
  public.is_admin()
  or (
    public.is_technician()
    and public.profile_flag('can_edit_locations')
    and public.technician_record_allows('can_edit_locations')
  )
)
with check (
  public.is_admin()
  or (
    public.is_technician()
    and public.profile_flag('can_edit_locations')
    and public.technician_record_allows('can_edit_locations')
  )
);

drop policy if exists "locations_delete_admin_only" on public.locations;
create policy "locations_delete_admin_only"
on public.locations
for delete
to authenticated
using (
  public.is_admin()
);

-- ============================================================================
-- Work orders
-- ============================================================================

drop policy if exists "work_orders_select_scoped" on public.work_orders;
create policy "work_orders_select_scoped"
on public.work_orders
for select
to authenticated
using (
  public.is_admin()
  or (
    public.is_technician()
    and public.can_access_work_orders_scope()
    and (
      (
        public.profile_flag('can_view_all_work_orders')
        and public.technician_record_allows('can_view_all_work_orders')
      )
      or technician_id = public.current_user_technician_id()
    )
  )
  or (
    public.is_client()
    and (
      public.client_can_access_asset(asset_id::text)
      or public.client_can_access_location(location_id::text)
    )
  )
);

drop policy if exists "work_orders_insert_admin_or_creator" on public.work_orders;
create policy "work_orders_insert_admin_or_creator"
on public.work_orders
for insert
to authenticated
with check (
  public.is_admin()
  or (
    public.is_technician()
    and public.profile_flag('can_create_work_orders')
    and public.technician_record_allows('can_create_work_orders')
    and (
      technician_id is null
      or technician_id = public.current_user_technician_id()
      or (
        public.profile_flag('can_view_all_work_orders')
        and public.technician_record_allows('can_view_all_work_orders')
      )
    )
  )
);

drop policy if exists "work_orders_update_admin_or_editor" on public.work_orders;
create policy "work_orders_update_admin_or_editor"
on public.work_orders
for update
to authenticated
using (
  public.is_admin()
  or (
    public.is_technician()
    and public.profile_flag('can_edit_work_orders')
    and public.technician_record_allows('can_edit_work_orders')
    and (
      technician_id = public.current_user_technician_id()
      or (
        public.profile_flag('can_view_all_work_orders')
        and public.technician_record_allows('can_view_all_work_orders')
      )
    )
  )
)
with check (
  public.is_admin()
  or (
    public.is_technician()
    and public.profile_flag('can_edit_work_orders')
    and public.technician_record_allows('can_edit_work_orders')
    and (
      technician_id = public.current_user_technician_id()
      or (
        public.profile_flag('can_view_all_work_orders')
        and public.technician_record_allows('can_view_all_work_orders')
      )
    )
  )
);

drop policy if exists "work_orders_delete_admin_only" on public.work_orders;
create policy "work_orders_delete_admin_only"
on public.work_orders
for delete
to authenticated
using (
  public.is_admin()
);

-- ============================================================================
-- Company profile
-- ============================================================================

drop policy if exists "company_profile_select_admin_only" on public.company_profile;
create policy "company_profile_select_admin_only"
on public.company_profile
for select
to authenticated
using (
  public.is_admin()
);

drop policy if exists "company_profile_insert_admin_only" on public.company_profile;
create policy "company_profile_insert_admin_only"
on public.company_profile
for insert
to authenticated
with check (
  public.is_admin()
);

drop policy if exists "company_profile_update_admin_only" on public.company_profile;
create policy "company_profile_update_admin_only"
on public.company_profile
for update
to authenticated
using (
  public.is_admin()
)
with check (
  public.is_admin()
);

drop policy if exists "company_profile_delete_admin_only" on public.company_profile;
create policy "company_profile_delete_admin_only"
on public.company_profile
for delete
to authenticated
using (
  public.is_admin()
);

-- ============================================================================
-- Admin notifications
-- ============================================================================

drop policy if exists "admin_notifications_select_scoped" on public.admin_notifications;
create policy "admin_notifications_select_scoped"
on public.admin_notifications
for select
to authenticated
using (
  public.is_admin()
  or (
    public.is_technician()
    and public.profile_flag('can_view_alerts')
    and public.technician_record_allows('can_view_alerts')
  )
);

drop policy if exists "admin_notifications_write_admin_only" on public.admin_notifications;
create policy "admin_notifications_write_admin_only"
on public.admin_notifications
for insert
to authenticated
with check (
  public.is_admin()
);

drop policy if exists "admin_notifications_update_admin_only" on public.admin_notifications;
create policy "admin_notifications_update_admin_only"
on public.admin_notifications
for update
to authenticated
using (
  public.is_admin()
)
with check (
  public.is_admin()
);

drop policy if exists "admin_notifications_delete_admin_only" on public.admin_notifications;
create policy "admin_notifications_delete_admin_only"
on public.admin_notifications
for delete
to authenticated
using (
  public.is_admin()
);

-- ============================================================================
-- Storage notes
-- ============================================================================

-- Recommended operational changes:
-- 1. Keep `technician-documents` private.
-- 2. Keep `work-order-attachments` private.
-- 3. Prefer signed URLs for sensitive files.
-- 4. Avoid `public = true` for internal operational documents.

commit;
