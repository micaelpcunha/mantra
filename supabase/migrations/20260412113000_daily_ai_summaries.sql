-- Daily operational summaries generated manually by admins.
-- Stores a single summary per company/day with source stats and the payload
-- used to render the dashboard card.

begin;

create extension if not exists pgcrypto;

create table if not exists public.daily_ai_summaries (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null,
  summary_date date not null,
  status text not null default 'ready',
  summary_payload jsonb not null default '{}'::jsonb,
  summary_text text,
  source_payload jsonb not null default '{}'::jsonb,
  source_stats jsonb not null default '{}'::jsonb,
  generation_mode text not null default 'heuristic',
  model text,
  error_message text,
  generated_by uuid,
  generated_at timestamptz not null default timezone('utc', now()),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

alter table if exists public.daily_ai_summaries
  add column if not exists company_id uuid;

alter table if exists public.daily_ai_summaries
  add column if not exists summary_date date;

alter table if exists public.daily_ai_summaries
  add column if not exists status text not null default 'ready';

alter table if exists public.daily_ai_summaries
  add column if not exists summary_payload jsonb not null default '{}'::jsonb;

alter table if exists public.daily_ai_summaries
  add column if not exists summary_text text;

alter table if exists public.daily_ai_summaries
  add column if not exists source_payload jsonb not null default '{}'::jsonb;

alter table if exists public.daily_ai_summaries
  add column if not exists source_stats jsonb not null default '{}'::jsonb;

alter table if exists public.daily_ai_summaries
  add column if not exists generation_mode text not null default 'heuristic';

alter table if exists public.daily_ai_summaries
  add column if not exists model text;

alter table if exists public.daily_ai_summaries
  add column if not exists error_message text;

alter table if exists public.daily_ai_summaries
  add column if not exists generated_by uuid;

alter table if exists public.daily_ai_summaries
  add column if not exists generated_at timestamptz not null default timezone('utc', now());

alter table if exists public.daily_ai_summaries
  add column if not exists created_at timestamptz not null default timezone('utc', now());

alter table if exists public.daily_ai_summaries
  add column if not exists updated_at timestamptz not null default timezone('utc', now());

comment on table public.daily_ai_summaries is
  'Resumo operacional diario gerado manualmente pelo admin para a empresa atual.';

comment on column public.daily_ai_summaries.summary_payload is
  'Payload estruturado com headline e listas para o dashboard.';

comment on column public.daily_ai_summaries.source_payload is
  'Snapshot de contexto usado para gerar o resumo do dia.';

comment on column public.daily_ai_summaries.generation_mode is
  'Modo usado para gerar o resumo: heuristic ou openai.';

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'daily_ai_summaries_company_id_fkey'
  ) then
    alter table public.daily_ai_summaries
      add constraint daily_ai_summaries_company_id_fkey
      foreign key (company_id)
      references public.companies(id)
      on delete cascade;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'daily_ai_summaries_generated_by_fkey'
  ) then
    alter table public.daily_ai_summaries
      add constraint daily_ai_summaries_generated_by_fkey
      foreign key (generated_by)
      references public.profiles(id)
      on delete set null;
  end if;
end
$$;

alter table public.daily_ai_summaries
  drop constraint if exists daily_ai_summaries_status_check;

alter table public.daily_ai_summaries
  add constraint daily_ai_summaries_status_check
  check (status = any (array['ready', 'failed']));

alter table public.daily_ai_summaries
  drop constraint if exists daily_ai_summaries_generation_mode_check;

alter table public.daily_ai_summaries
  add constraint daily_ai_summaries_generation_mode_check
  check (generation_mode = any (array['heuristic', 'openai']));

create unique index if not exists daily_ai_summaries_company_day_key
  on public.daily_ai_summaries (company_id, summary_date);

create index if not exists daily_ai_summaries_company_generated_idx
  on public.daily_ai_summaries (company_id, generated_at desc);

create or replace function public.touch_daily_ai_summaries_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at := timezone('utc', now());
  return new;
end
$$;

drop trigger if exists set_daily_ai_summaries_company_id
on public.daily_ai_summaries;

do $$
begin
  if to_regprocedure('public.apply_current_company_id()') is not null then
    execute '
      create trigger set_daily_ai_summaries_company_id
      before insert
      on public.daily_ai_summaries
      for each row
      execute function public.apply_current_company_id()
    ';
  end if;
end
$$;

drop trigger if exists touch_daily_ai_summaries_updated_at
on public.daily_ai_summaries;

create trigger touch_daily_ai_summaries_updated_at
before update
on public.daily_ai_summaries
for each row
execute function public.touch_daily_ai_summaries_updated_at();

alter table if exists public.daily_ai_summaries enable row level security;

drop policy if exists "daily_ai_summaries_select_admin_only"
on public.daily_ai_summaries;
create policy "daily_ai_summaries_select_admin_only"
on public.daily_ai_summaries
for select
to authenticated
using (
  public.is_admin()
  and public.belongs_to_current_company(company_id)
);

drop policy if exists "daily_ai_summaries_insert_admin_only"
on public.daily_ai_summaries;
create policy "daily_ai_summaries_insert_admin_only"
on public.daily_ai_summaries
for insert
to authenticated
with check (
  public.is_admin()
  and public.belongs_to_current_company(company_id)
);

drop policy if exists "daily_ai_summaries_update_admin_only"
on public.daily_ai_summaries;
create policy "daily_ai_summaries_update_admin_only"
on public.daily_ai_summaries
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

drop policy if exists "daily_ai_summaries_delete_admin_only"
on public.daily_ai_summaries;
create policy "daily_ai_summaries_delete_admin_only"
on public.daily_ai_summaries
for delete
to authenticated
using (
  public.is_admin()
  and public.belongs_to_current_company(company_id)
);

commit;
