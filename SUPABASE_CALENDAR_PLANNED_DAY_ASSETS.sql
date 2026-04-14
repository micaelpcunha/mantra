-- Calendar support for planning assets on a day even without linked work orders.
-- Stores extra asset visits per day/technician so admins can edit an existing
-- daily plan without creating placeholder work orders.

begin;

create extension if not exists pgcrypto;

create table if not exists public.planned_day_assets (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null,
  technician_id uuid not null,
  asset_id uuid not null,
  planned_for date not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

alter table if exists public.planned_day_assets
  add column if not exists company_id uuid;

alter table if exists public.planned_day_assets
  add column if not exists technician_id uuid;

alter table if exists public.planned_day_assets
  add column if not exists asset_id uuid;

alter table if exists public.planned_day_assets
  add column if not exists planned_for date;

alter table if exists public.planned_day_assets
  add column if not exists created_at timestamptz not null default timezone('utc', now());

alter table if exists public.planned_day_assets
  add column if not exists updated_at timestamptz not null default timezone('utc', now());

comment on table public.planned_day_assets is
  'Ativos planeados num determinado dia/tecnico sem obrigar a criar uma ordem de trabalho.';

comment on column public.planned_day_assets.planned_for is
  'Data do planeamento diario do ativo.';

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'planned_day_assets_company_id_fkey'
  ) then
    alter table public.planned_day_assets
      add constraint planned_day_assets_company_id_fkey
      foreign key (company_id)
      references public.companies(id);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'planned_day_assets_technician_id_fkey'
  ) then
    alter table public.planned_day_assets
      add constraint planned_day_assets_technician_id_fkey
      foreign key (technician_id)
      references public.technicians(id);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'planned_day_assets_asset_id_fkey'
  ) then
    alter table public.planned_day_assets
      add constraint planned_day_assets_asset_id_fkey
      foreign key (asset_id)
      references public.assets(id);
  end if;
end
$$;

create unique index if not exists planned_day_assets_company_day_tech_asset_key
  on public.planned_day_assets (company_id, planned_for, technician_id, asset_id);

create index if not exists planned_day_assets_company_day_idx
  on public.planned_day_assets (company_id, planned_for);

create index if not exists planned_day_assets_technician_day_idx
  on public.planned_day_assets (technician_id, planned_for);

create index if not exists planned_day_assets_asset_day_idx
  on public.planned_day_assets (asset_id, planned_for);

create or replace function public.sync_planned_day_asset_company_id()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  resolved_company_id uuid;
  technician_company_id uuid;
begin
  if new.asset_id is null then
    raise exception 'asset_id is required for planned_day_assets';
  end if;

  if new.technician_id is null then
    raise exception 'technician_id is required for planned_day_assets';
  end if;

  select company_id
  into resolved_company_id
  from public.assets
  where id = new.asset_id;

  if resolved_company_id is null then
    raise exception 'Invalid asset_id for planned_day_assets: %', new.asset_id;
  end if;

  select company_id
  into technician_company_id
  from public.technicians
  where id = new.technician_id;

  if technician_company_id is null then
    raise exception 'Invalid technician_id for planned_day_assets: %', new.technician_id;
  end if;

  if technician_company_id <> resolved_company_id then
    raise exception 'The selected technician does not belong to the same company as the asset';
  end if;

  new.company_id = resolved_company_id;
  return new;
end
$$;

create or replace function public.touch_planned_day_assets_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end
$$;

drop trigger if exists set_planned_day_assets_company_id
on public.planned_day_assets;

create trigger set_planned_day_assets_company_id
before insert or update of asset_id, technician_id
on public.planned_day_assets
for each row
execute function public.sync_planned_day_asset_company_id();

drop trigger if exists touch_planned_day_assets_updated_at
on public.planned_day_assets;

create trigger touch_planned_day_assets_updated_at
before update
on public.planned_day_assets
for each row
execute function public.touch_planned_day_assets_updated_at();

alter table if exists public.planned_day_assets enable row level security;

drop policy if exists "planned_day_assets_select_scoped"
on public.planned_day_assets;
create policy "planned_day_assets_select_scoped"
on public.planned_day_assets
for select
to authenticated
using (
  public.belongs_to_current_company(company_id)
  and (
    public.is_admin()
    or (
      public.is_technician()
      and public.can_access_assets_scope()
      and technician_id = public.current_user_technician_id()
    )
  )
);

drop policy if exists "planned_day_assets_insert_admin_only"
on public.planned_day_assets;
create policy "planned_day_assets_insert_admin_only"
on public.planned_day_assets
for insert
to authenticated
with check (
  public.is_admin()
  and public.belongs_to_current_company(company_id)
);

drop policy if exists "planned_day_assets_update_admin_only"
on public.planned_day_assets;
create policy "planned_day_assets_update_admin_only"
on public.planned_day_assets
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

drop policy if exists "planned_day_assets_delete_admin_only"
on public.planned_day_assets;
create policy "planned_day_assets_delete_admin_only"
on public.planned_day_assets
for delete
to authenticated
using (
  public.is_admin()
  and public.belongs_to_current_company(company_id)
);

commit;
