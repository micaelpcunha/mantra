begin;

create table if not exists public.company_email_connection_credentials (
  connection_id uuid primary key,
  provider text not null,
  refresh_token text not null,
  access_token text,
  token_type text,
  id_token text,
  expires_at timestamptz,
  access_scope text[] not null default '{}'::text[],
  raw_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint company_email_connection_credentials_provider_check
    check (provider in ('google', 'microsoft'))
);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'company_email_connection_credentials_connection_id_fkey'
  ) then
    alter table public.company_email_connection_credentials
      add constraint company_email_connection_credentials_connection_id_fkey
      foreign key (connection_id)
      references public.company_email_connections(id)
      on delete cascade;
  end if;
end
$$;

create index if not exists company_email_connection_credentials_expires_at_idx
  on public.company_email_connection_credentials (expires_at);

create or replace function public.touch_company_email_connection_credentials_updated_at()
returns trigger
language plpgsql
as $function$
begin
  new.updated_at := timezone('utc', now());
  return new;
end;
$function$;

drop trigger if exists touch_company_email_connection_credentials_updated_at
on public.company_email_connection_credentials;

create trigger touch_company_email_connection_credentials_updated_at
before update on public.company_email_connection_credentials
for each row
execute function public.touch_company_email_connection_credentials_updated_at();

alter table if exists public.company_email_connection_credentials
  enable row level security;

revoke all on public.company_email_connection_credentials from anon;
revoke all on public.company_email_connection_credentials from authenticated;
revoke all on public.company_email_connection_credentials from public;

commit;
