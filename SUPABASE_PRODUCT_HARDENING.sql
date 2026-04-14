-- Product-level hardening patch for multi-company rollout.
-- Focus: protect new product tables that were introduced during the
-- multi-company migration but were not yet included in the RLS rollout.

begin;

alter table if exists public.companies enable row level security;
alter table if exists public.custom_field_definitions enable row level security;
alter table if exists public.custom_field_values enable row level security;

-- Companies are readable within the current company and writable by admins of
-- that same company. Company creation should stay in privileged onboarding
-- flows, so no authenticated INSERT policy is added here.
drop policy if exists "companies_select_scoped" on public.companies;
create policy "companies_select_scoped"
on public.companies
for select
to authenticated
using (
  public.belongs_to_current_company(id)
);

drop policy if exists "companies_update_admin_only" on public.companies;
create policy "companies_update_admin_only"
on public.companies
for update
to authenticated
using (
  public.is_admin()
  and public.belongs_to_current_company(id)
)
with check (
  public.is_admin()
  and public.belongs_to_current_company(id)
);

drop policy if exists "companies_delete_admin_only" on public.companies;
create policy "companies_delete_admin_only"
on public.companies
for delete
to authenticated
using (
  public.is_admin()
  and public.belongs_to_current_company(id)
);

-- Custom fields are currently an admin-only configuration surface until the
-- app starts rendering them per entity with visibility rules.
drop policy if exists "custom_field_definitions_select_admin_only" on public.custom_field_definitions;
create policy "custom_field_definitions_select_admin_only"
on public.custom_field_definitions
for select
to authenticated
using (
  public.is_admin()
  and public.belongs_to_current_company(company_id)
);

drop policy if exists "custom_field_definitions_insert_admin_only" on public.custom_field_definitions;
create policy "custom_field_definitions_insert_admin_only"
on public.custom_field_definitions
for insert
to authenticated
with check (
  public.is_admin()
  and public.belongs_to_current_company(company_id)
);

drop policy if exists "custom_field_definitions_update_admin_only" on public.custom_field_definitions;
create policy "custom_field_definitions_update_admin_only"
on public.custom_field_definitions
for update
to authenticated
using (
  public.is_admin()
  and public.belongs_to_current_company(company_id)
)
with check (
  public.is_admin()
  and public.belongs_to_current_company(company_id)
);

drop policy if exists "custom_field_definitions_delete_admin_only" on public.custom_field_definitions;
create policy "custom_field_definitions_delete_admin_only"
on public.custom_field_definitions
for delete
to authenticated
using (
  public.is_admin()
  and public.belongs_to_current_company(company_id)
);

drop policy if exists "custom_field_values_select_admin_only" on public.custom_field_values;
create policy "custom_field_values_select_admin_only"
on public.custom_field_values
for select
to authenticated
using (
  public.is_admin()
  and public.belongs_to_current_company(company_id)
);

drop policy if exists "custom_field_values_insert_admin_only" on public.custom_field_values;
create policy "custom_field_values_insert_admin_only"
on public.custom_field_values
for insert
to authenticated
with check (
  public.is_admin()
  and public.belongs_to_current_company(company_id)
);

drop policy if exists "custom_field_values_update_admin_only" on public.custom_field_values;
create policy "custom_field_values_update_admin_only"
on public.custom_field_values
for update
to authenticated
using (
  public.is_admin()
  and public.belongs_to_current_company(company_id)
)
with check (
  public.is_admin()
  and public.belongs_to_current_company(company_id)
);

drop policy if exists "custom_field_values_delete_admin_only" on public.custom_field_values;
create policy "custom_field_values_delete_admin_only"
on public.custom_field_values
for delete
to authenticated
using (
  public.is_admin()
  and public.belongs_to_current_company(company_id)
);

commit;
