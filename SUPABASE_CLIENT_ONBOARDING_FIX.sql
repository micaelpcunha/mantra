-- Fix client onboarding when auth.users auto-creates a profile without company_id.
-- This keeps the multi-tenant guardrails but lets an admin claim an orphan
-- profile row that still has company_id = null.

begin;

drop policy if exists "profiles_select_self_or_admin" on public.profiles;
create policy "profiles_select_self_or_admin"
on public.profiles
for select
to authenticated
using (
  (
    id = auth.uid()
    and public.belongs_to_current_company(company_id)
  )
  or (
    public.is_admin()
    and (
      public.belongs_to_current_company(company_id)
      or company_id is null
    )
  )
);

drop policy if exists "profiles_update_admin_only" on public.profiles;
create policy "profiles_update_admin_only"
on public.profiles
for update
to authenticated
using (
  public.is_admin()
  and (
    public.belongs_to_current_company(company_id)
    or company_id is null
  )
)
with check (
  public.is_admin()
  and public.belongs_to_current_company(company_id)
);

commit;
