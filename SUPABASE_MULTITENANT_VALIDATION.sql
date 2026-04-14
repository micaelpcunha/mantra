-- Validation queries for the multi-company migration.
-- Run after `SUPABASE_PRODUCT_FOUNDATION.sql`
-- and again after `SUPABASE_MULTITENANT_RLS.sql`.

-- ============================================================================
-- 1. Confirm required tables exist
-- ============================================================================

select table_schema, table_name
from information_schema.tables
where table_schema = 'public'
  and table_name in (
    'companies',
    'profiles',
    'technicians',
    'assets',
    'asset_devices',
    'locations',
    'work_orders',
    'company_profile',
    'custom_field_definitions',
    'custom_field_values'
  )
order by table_name;

-- Expected:
-- - every table above should be present

-- ============================================================================
-- 2. Confirm `company_id` exists on the operational tables
-- ============================================================================

select table_name, column_name, data_type, is_nullable
from information_schema.columns
where table_schema = 'public'
  and table_name in (
    'profiles',
    'technicians',
    'assets',
    'asset_devices',
    'locations',
    'work_orders',
    'company_profile'
  )
  and column_name = 'company_id'
order by table_name;

-- Expected:
-- - one row per table above

-- ============================================================================
-- 3. Review seeded companies
-- ============================================================================

select
  c.column_name,
  c.data_type,
  c.is_nullable
from information_schema.columns c
where c.table_schema = 'public'
  and c.table_name = 'companies'
  and c.column_name in (
    'id',
    'slug',
    'display_name',
    'status',
    'onboarding_status',
    'created_at'
  )
order by c.column_name;

-- Expected:
-- - the six columns above should all exist

select *
from public.companies
order by 1
limit 20;

-- Expected:
-- - at least one company exists
-- - legacy datasets should already be linked to one company

-- ============================================================================
-- 4. Check for missing `company_id`
-- ============================================================================

select 'profiles' as table_name, count(*) as total_rows, count(*) filter (where company_id is null) as missing_company_id
from public.profiles
union all
select 'technicians' as table_name, count(*) as total_rows, count(*) filter (where company_id is null) as missing_company_id
from public.technicians
union all
select 'assets' as table_name, count(*) as total_rows, count(*) filter (where company_id is null) as missing_company_id
from public.assets
union all
select 'asset_devices' as table_name, count(*) as total_rows, count(*) filter (where company_id is null) as missing_company_id
from public.asset_devices
union all
select 'locations' as table_name, count(*) as total_rows, count(*) filter (where company_id is null) as missing_company_id
from public.locations
union all
select 'work_orders' as table_name, count(*) as total_rows, count(*) filter (where company_id is null) as missing_company_id
from public.work_orders
union all
select 'company_profile' as table_name, count(*) as total_rows, count(*) filter (where company_id is null) as missing_company_id
from public.company_profile
order by table_name;

-- Expected:
-- - `missing_company_id` should be 0 on all rows

-- ============================================================================
-- 5. Check company distribution
-- ============================================================================

select 'profiles' as table_name, company_id, count(*) as row_count
from public.profiles
group by company_id
union all
select 'technicians' as table_name, company_id, count(*) as row_count
from public.technicians
group by company_id
union all
select 'assets' as table_name, company_id, count(*) as row_count
from public.assets
group by company_id
union all
select 'asset_devices' as table_name, company_id, count(*) as row_count
from public.asset_devices
group by company_id
union all
select 'locations' as table_name, company_id, count(*) as row_count
from public.locations
group by company_id
union all
select 'work_orders' as table_name, company_id, count(*) as row_count
from public.work_orders
group by company_id
union all
select 'company_profile' as table_name, company_id, count(*) as row_count
from public.company_profile
group by company_id
order by table_name, company_id;

-- Expected:
-- - counts should make sense per company
-- - `company_profile` should normally have one row per company

-- ============================================================================
-- 6. Confirm `company_profile` uniqueness by company
-- ============================================================================

select company_id, count(*) as profile_count
from public.company_profile
group by company_id
having count(*) > 1;

-- Expected:
-- - zero rows returned

-- ============================================================================
-- 7. Confirm automatic triggers for `company_id`
-- ============================================================================

select event_object_table as table_name, trigger_name, action_timing, event_manipulation
from information_schema.triggers
where trigger_schema = 'public'
  and trigger_name like 'set\_%\_company_id' escape '\'
order by event_object_table, trigger_name;

-- Expected:
-- - triggers exist for the core operational tables

-- ============================================================================
-- 8. Confirm helper functions exist
-- ============================================================================

select routine_name, routine_type
from information_schema.routines
where specific_schema = 'public'
  and routine_name in (
    'current_user_company_id',
    'belongs_to_current_company',
    'apply_current_company_id',
    'client_can_access_asset',
    'client_can_access_location'
  )
order by routine_name;

-- Expected:
-- - every routine above should exist

-- ============================================================================
-- 9. Review active RLS policies after the multi-tenant script
-- ============================================================================

select tablename, policyname, cmd
from pg_policies
where schemaname = 'public'
  and tablename in (
    'companies',
    'custom_field_definitions',
    'custom_field_values',
    'profiles',
    'technicians',
    'assets',
    'asset_devices',
    'locations',
    'work_orders',
    'company_profile',
    'admin_notifications'
  )
order by tablename, cmd, policyname;

-- Expected after `SUPABASE_MULTITENANT_RLS.sql`:
-- - each table should have the expected policies recreated

-- ============================================================================
-- 10. Confirm RLS is enabled on product-level tables
-- ============================================================================

select c.relname as table_name, c.relrowsecurity as rls_enabled
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relkind = 'r'
  and c.relname in (
    'companies',
    'custom_field_definitions',
    'custom_field_values',
    'asset_devices'
  )
order by c.relname;

-- Expected:
-- - `rls_enabled` should be true on all rows above

-- ============================================================================
-- 11. Review custom-field foundation
-- ============================================================================

select table_name, count(*) as row_count
from (
  select 'custom_field_definitions' as table_name from public.custom_field_definitions
  union all
  select 'custom_field_values' as table_name from public.custom_field_values
) source
group by table_name
order by table_name;

-- Expected:
-- - both tables exist
-- - row count may still be 0 at this stage

-- ============================================================================
-- 12. Review storage buckets relevant to the migration
-- ============================================================================

select id, public, file_size_limit, allowed_mime_types
from storage.buckets
where id in (
  'work-order-photos',
  'work-order-attachments',
  'technician-profile-photos',
  'technician-documents',
  'asset-profile-photos',
  'location-photos',
  'company-media',
  'note-images'
)
order by id;

-- Expected:
-- - `work-order-attachments` should be private
-- - `technician-documents` should be private
-- - `note-images` should be private
-- - `company-media` should normally be private once the app resolves signed URLs
