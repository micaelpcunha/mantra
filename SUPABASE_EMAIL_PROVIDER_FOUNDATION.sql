begin;

create extension if not exists pgcrypto;

alter table if exists public.company_profile
  add column if not exists authorization_email_provider text;

alter table if exists public.company_profile
  add column if not exists authorization_email_connection_id uuid;

alter table if exists public.company_profile
  add column if not exists authorization_email_send_mode text;

alter table if exists public.company_profile
  add column if not exists authorization_email_signature text;

alter table if exists public.company_profile
  add column if not exists authorization_sender_email text;

alter table if exists public.company_profile
  alter column authorization_email_provider set default 'manual';

alter table if exists public.company_profile
  alter column authorization_email_send_mode set default 'manual';

update public.company_profile
set authorization_email_provider = coalesce(
  nullif(trim(authorization_email_provider), ''),
  'manual'
)
where authorization_email_provider is null
   or nullif(trim(authorization_email_provider), '') is null;

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
    where conname = 'company_profile_authorization_email_provider_check'
  ) then
    alter table public.company_profile
      add constraint company_profile_authorization_email_provider_check
      check (
        authorization_email_provider in ('manual', 'google', 'microsoft')
      );
  end if;

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

create table if not exists public.company_email_connections (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null,
  provider text not null,
  email text not null,
  display_name text,
  status text not null default 'pending_setup',
  external_account_id text,
  access_scope text[] not null default '{}'::text[],
  connected_at timestamptz,
  last_sync_at timestamptz,
  last_test_at timestamptz,
  last_error text,
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint company_email_connections_provider_check
    check (provider in ('google', 'microsoft')),
  constraint company_email_connections_status_check
    check (
      status in (
        'pending_setup',
        'connected',
        'needs_reauth',
        'revoked',
        'error'
      )
    )
);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'company_email_connections_company_id_fkey'
  ) then
    alter table public.company_email_connections
      add constraint company_email_connections_company_id_fkey
      foreign key (company_id)
      references public.companies(id)
      on delete cascade;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'company_email_connections_created_by_fkey'
  ) then
    alter table public.company_email_connections
      add constraint company_email_connections_created_by_fkey
      foreign key (created_by)
      references public.profiles(id)
      on delete set null;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'company_profile_authorization_email_connection_id_fkey'
  ) then
    alter table public.company_profile
      add constraint company_profile_authorization_email_connection_id_fkey
      foreign key (authorization_email_connection_id)
      references public.company_email_connections(id)
      on delete set null;
  end if;
end
$$;

create unique index if not exists company_email_connections_company_provider_email_key
  on public.company_email_connections (company_id, provider, email);

create index if not exists company_email_connections_company_id_idx
  on public.company_email_connections (company_id);

create index if not exists company_email_connections_status_idx
  on public.company_email_connections (status);

create or replace function public.touch_company_email_connections_updated_at()
returns trigger
language plpgsql
as $function$
begin
  new.updated_at := timezone('utc', now());
  return new;
end;
$function$;

drop trigger if exists touch_company_email_connections_updated_at
on public.company_email_connections;

create trigger touch_company_email_connections_updated_at
before update on public.company_email_connections
for each row
execute function public.touch_company_email_connections_updated_at();

alter table if exists public.company_email_connections enable row level security;

drop policy if exists "company_email_connections_select_admin_only"
on public.company_email_connections;
create policy "company_email_connections_select_admin_only"
on public.company_email_connections
for select
to authenticated
using (
  public.is_admin()
  and public.belongs_to_current_company(company_id)
);

drop policy if exists "company_email_connections_insert_admin_only"
on public.company_email_connections;
create policy "company_email_connections_insert_admin_only"
on public.company_email_connections
for insert
to authenticated
with check (
  public.is_admin()
  and public.belongs_to_current_company(company_id)
);

drop policy if exists "company_email_connections_update_admin_only"
on public.company_email_connections;
create policy "company_email_connections_update_admin_only"
on public.company_email_connections
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

drop policy if exists "company_email_connections_delete_admin_only"
on public.company_email_connections;
create policy "company_email_connections_delete_admin_only"
on public.company_email_connections
for delete
to authenticated
using (
  public.is_admin()
  and public.belongs_to_current_company(company_id)
);

create or replace function public.delete_company_email_connection(
  p_connection_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_connection public.company_email_connections%rowtype;
  v_profile public.company_profile%rowtype;
  v_deleted_active_connection boolean := false;
  v_sender_email text;
begin
  if auth.uid() is null then
    raise exception 'Utilizador nao autenticado.';
  end if;

  if p_connection_id is null then
    raise exception 'Indica a conta ligada a eliminar.';
  end if;

  if not public.is_admin() then
    raise exception 'Apenas administradores podem eliminar contas ligadas.';
  end if;

  select *
  into v_connection
  from public.company_email_connections
  where id = p_connection_id
    and public.belongs_to_current_company(company_id)
  limit 1;

  if not found then
    raise exception 'A conta ligada indicada nao foi encontrada na empresa atual.';
  end if;

  select *
  into v_profile
  from public.company_profile
  where company_id = v_connection.company_id
  order by created_at
  limit 1
  for update;

  if found and v_profile.authorization_email_connection_id = v_connection.id then
    v_deleted_active_connection := true;
    v_sender_email := nullif(trim(v_profile.authorization_sender_email), '');

    update public.company_profile
    set authorization_email_send_mode = 'manual',
        authorization_email_provider = 'manual',
        authorization_email_connection_id = null,
        authorization_sender_email = case
          when v_sender_email is not null
            and lower(v_sender_email) = lower(v_connection.email)
            then null
          else authorization_sender_email
        end
    where id = v_profile.id;
  end if;

  delete from public.company_email_connections
  where id = v_connection.id;

  return jsonb_build_object(
    'deleted_connection_id', v_connection.id,
    'deleted_provider', v_connection.provider,
    'deleted_email', v_connection.email,
    'deleted_active_connection', v_deleted_active_connection
  );
end;
$function$;

revoke all
on function public.delete_company_email_connection(uuid)
from public;

grant execute
on function public.delete_company_email_connection(uuid)
to authenticated;

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
