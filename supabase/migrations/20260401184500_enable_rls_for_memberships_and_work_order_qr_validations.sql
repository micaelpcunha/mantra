-- Catch up RLS for legacy public tables that were corrected live first.

begin;

alter table if exists public.memberships
  enable row level security;

alter table if exists public.work_order_qr_validations
  enable row level security;

commit;
