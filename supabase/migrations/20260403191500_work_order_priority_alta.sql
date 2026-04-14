begin;

alter table if exists public.work_orders
  drop constraint if exists work_orders_priority_check;

alter table if exists public.work_orders
  add constraint work_orders_priority_check
  check (
    priority is null or
    priority = any (
      array[
        'baixa'::text,
        'normal'::text,
        'alta'::text,
        'urgente'::text
      ]
    )
  );

commit;
