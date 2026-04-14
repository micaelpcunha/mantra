-- Work order procedures and reusable checklist templates.
-- Apply after the current multi-company foundation/helpers are available,
-- namely `public.companies`, `public.current_user_company_id()`,
-- `public.belongs_to_current_company(...)` and the work-order access helpers.

begin;

create extension if not exists pgcrypto;

create table if not exists public.procedure_templates (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null,
  name text not null,
  description text,
  steps jsonb not null default '[]'::jsonb,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint procedure_templates_steps_is_array
    check (jsonb_typeof(steps) = 'array')
);

alter table if exists public.work_orders
  add column if not exists procedure_template_id uuid;

alter table if exists public.work_orders
  add column if not exists procedure_name text;

alter table if exists public.work_orders
  add column if not exists procedure_steps jsonb not null default '[]'::jsonb;

update public.work_orders
set procedure_steps = '[]'::jsonb
where procedure_steps is null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'procedure_templates_company_id_fkey'
  ) then
    alter table public.procedure_templates
      add constraint procedure_templates_company_id_fkey
      foreign key (company_id)
      references public.companies(id)
      on delete cascade;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'work_orders_procedure_template_id_fkey'
  ) then
    alter table public.work_orders
      add constraint work_orders_procedure_template_id_fkey
      foreign key (procedure_template_id)
      references public.procedure_templates(id)
      on delete set null;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'work_orders_procedure_steps_is_array'
  ) then
    alter table public.work_orders
      add constraint work_orders_procedure_steps_is_array
      check (jsonb_typeof(procedure_steps) = 'array');
  end if;
end
$$;

create index if not exists procedure_templates_company_id_idx
  on public.procedure_templates (company_id);

create index if not exists procedure_templates_company_name_idx
  on public.procedure_templates (company_id, name);

create index if not exists work_orders_procedure_template_id_idx
  on public.work_orders (procedure_template_id);

create or replace function public.touch_procedure_templates_updated_at()
returns trigger
language plpgsql
as $function$
begin
  new.updated_at := timezone('utc', now());
  return new;
end;
$function$;

drop trigger if exists touch_procedure_templates_updated_at
on public.procedure_templates;

create trigger touch_procedure_templates_updated_at
before update on public.procedure_templates
for each row
execute function public.touch_procedure_templates_updated_at();

do $$
begin
  if exists (
    select 1
    from pg_proc
    where proname = 'apply_current_company_id'
      and pg_function_is_visible(oid)
  ) then
    execute '
      drop trigger if exists set_procedure_templates_company_id
      on public.procedure_templates
    ';
    execute '
      create trigger set_procedure_templates_company_id
      before insert on public.procedure_templates
      for each row
      execute function public.apply_current_company_id()
    ';
  end if;
end
$$;

alter table if exists public.procedure_templates enable row level security;

drop policy if exists "procedure_templates_select_scoped"
on public.procedure_templates;
create policy "procedure_templates_select_scoped"
on public.procedure_templates
for select
to authenticated
using (
  public.belongs_to_current_company(company_id)
  and (
    public.is_admin()
    or (
      public.is_technician()
      and public.can_access_work_orders_scope()
    )
  )
);

drop policy if exists "procedure_templates_insert_admin_only"
on public.procedure_templates;
create policy "procedure_templates_insert_admin_only"
on public.procedure_templates
for insert
to authenticated
with check (
  public.is_admin()
  and public.belongs_to_current_company(company_id)
);

drop policy if exists "procedure_templates_update_admin_only"
on public.procedure_templates;
create policy "procedure_templates_update_admin_only"
on public.procedure_templates
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

drop policy if exists "procedure_templates_delete_admin_only"
on public.procedure_templates;
create policy "procedure_templates_delete_admin_only"
on public.procedure_templates
for delete
to authenticated
using (
  public.is_admin()
  and public.belongs_to_current_company(company_id)
);

commit;
