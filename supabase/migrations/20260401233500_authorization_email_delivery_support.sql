begin;

alter table if exists public.company_profile
  add column if not exists authorization_email_send_mode text;

alter table if exists public.company_profile
  add column if not exists authorization_email_signature text;

alter table if exists public.company_profile
  add column if not exists authorization_sender_email text;

alter table if exists public.company_profile
  alter column authorization_email_send_mode set default 'manual';

update public.company_profile
set authorization_email_send_mode = coalesce(
  nullif(trim(authorization_email_send_mode), ''),
  'manual'
)
where authorization_email_send_mode is null
   or nullif(trim(authorization_email_send_mode), '') is null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'company_profile_authorization_email_send_mode_check'
  ) then
    alter table public.company_profile
      add constraint company_profile_authorization_email_send_mode_check
      check (
        authorization_email_send_mode in ('manual', 'automatico')
      );
  end if;
end
$$;

create table if not exists public.authorization_email_delivery_logs (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null,
  connection_id uuid,
  asset_id uuid,
  planned_for date,
  recipient_email text not null,
  subject text not null,
  status text not null,
  provider_message_id text,
  error_message text,
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid,
  created_at timestamptz not null default timezone('utc', now()),
  constraint authorization_email_delivery_logs_status_check
    check (status in ('sent', 'failed'))
);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'authorization_email_delivery_logs_company_id_fkey'
  ) then
    alter table public.authorization_email_delivery_logs
      add constraint authorization_email_delivery_logs_company_id_fkey
      foreign key (company_id)
      references public.companies(id)
      on delete cascade;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'authorization_email_delivery_logs_connection_id_fkey'
  ) then
    alter table public.authorization_email_delivery_logs
      add constraint authorization_email_delivery_logs_connection_id_fkey
      foreign key (connection_id)
      references public.company_email_connections(id)
      on delete set null;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'authorization_email_delivery_logs_asset_id_fkey'
  ) then
    alter table public.authorization_email_delivery_logs
      add constraint authorization_email_delivery_logs_asset_id_fkey
      foreign key (asset_id)
      references public.assets(id)
      on delete set null;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'authorization_email_delivery_logs_created_by_fkey'
  ) then
    alter table public.authorization_email_delivery_logs
      add constraint authorization_email_delivery_logs_created_by_fkey
      foreign key (created_by)
      references public.profiles(id)
      on delete set null;
  end if;
end
$$;

create index if not exists authorization_email_delivery_logs_company_id_idx
  on public.authorization_email_delivery_logs (company_id);

create index if not exists authorization_email_delivery_logs_planned_for_idx
  on public.authorization_email_delivery_logs (planned_for);

create index if not exists authorization_email_delivery_logs_connection_id_idx
  on public.authorization_email_delivery_logs (connection_id);

create index if not exists authorization_email_delivery_logs_status_idx
  on public.authorization_email_delivery_logs (status);

alter table if exists public.authorization_email_delivery_logs
  enable row level security;

drop policy if exists "authorization_email_delivery_logs_select_admin_only"
on public.authorization_email_delivery_logs;
create policy "authorization_email_delivery_logs_select_admin_only"
on public.authorization_email_delivery_logs
for select
to authenticated
using (
  public.is_admin()
  and public.belongs_to_current_company(company_id)
);

drop policy if exists "authorization_email_delivery_logs_insert_admin_only"
on public.authorization_email_delivery_logs;
create policy "authorization_email_delivery_logs_insert_admin_only"
on public.authorization_email_delivery_logs
for insert
to authenticated
with check (
  public.is_admin()
  and public.belongs_to_current_company(company_id)
);

commit;
