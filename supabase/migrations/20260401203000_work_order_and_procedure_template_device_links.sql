begin;

alter table if exists public.work_orders
  add column if not exists asset_device_id uuid;

alter table if exists public.work_orders
  add column if not exists asset_device_name text;

alter table if exists public.procedure_templates
  add column if not exists asset_id uuid;

alter table if exists public.procedure_templates
  add column if not exists asset_device_id uuid;

alter table if exists public.procedure_templates
  add column if not exists asset_device_name text;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'work_orders_asset_device_id_fkey'
  ) then
    alter table public.work_orders
      add constraint work_orders_asset_device_id_fkey
      foreign key (asset_device_id)
      references public.asset_devices(id)
      on delete set null;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'procedure_templates_asset_id_fkey'
  ) then
    alter table public.procedure_templates
      add constraint procedure_templates_asset_id_fkey
      foreign key (asset_id)
      references public.assets(id)
      on delete set null;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'procedure_templates_asset_device_id_fkey'
  ) then
    alter table public.procedure_templates
      add constraint procedure_templates_asset_device_id_fkey
      foreign key (asset_device_id)
      references public.asset_devices(id)
      on delete set null;
  end if;
end
$$;

create index if not exists work_orders_asset_device_id_idx
  on public.work_orders (asset_device_id);

create index if not exists procedure_templates_asset_id_idx
  on public.procedure_templates (asset_id);

create index if not exists procedure_templates_asset_device_id_idx
  on public.procedure_templates (asset_device_id);

create or replace function public.sync_work_order_asset_device_snapshot()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  resolved_asset_id uuid;
  resolved_device_name text;
begin
  if new.asset_device_id is null then
    return new;
  end if;

  select asset_id, name
  into resolved_asset_id, resolved_device_name
  from public.asset_devices
  where id = new.asset_device_id;

  if resolved_asset_id is null then
    raise exception 'Nao foi possivel encontrar o dispositivo associado a ordem.';
  end if;

  if new.asset_id is not null and new.asset_id is distinct from resolved_asset_id then
    raise exception 'O dispositivo selecionado nao pertence ao ativo desta ordem.';
  end if;

  new.asset_id = coalesce(new.asset_id, resolved_asset_id);
  new.asset_device_name = nullif(trim(resolved_device_name), '');
  return new;
end
$$;

create or replace function public.sync_procedure_template_asset_device_snapshot()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  resolved_asset_id uuid;
  resolved_device_name text;
begin
  if new.asset_device_id is null then
    return new;
  end if;

  select asset_id, name
  into resolved_asset_id, resolved_device_name
  from public.asset_devices
  where id = new.asset_device_id;

  if resolved_asset_id is null then
    raise exception 'Nao foi possivel encontrar o dispositivo associado ao procedimento.';
  end if;

  if new.asset_id is not null and new.asset_id is distinct from resolved_asset_id then
    raise exception 'O dispositivo selecionado nao pertence ao ativo escolhido para o procedimento.';
  end if;

  new.asset_id = resolved_asset_id;
  new.asset_device_name = nullif(trim(resolved_device_name), '');
  return new;
end
$$;

update public.work_orders work_order
set asset_device_name = nullif(trim(device.name), '')
from public.asset_devices device
where device.id = work_order.asset_device_id
  and work_order.asset_device_name is distinct from nullif(trim(device.name), '');

update public.procedure_templates template
set
  asset_id = device.asset_id,
  asset_device_name = nullif(trim(device.name), '')
from public.asset_devices device
where device.id = template.asset_device_id
  and (
    template.asset_id is distinct from device.asset_id
    or template.asset_device_name is distinct from nullif(trim(device.name), '')
  );

drop trigger if exists sync_work_order_asset_device_snapshot
on public.work_orders;

create trigger sync_work_order_asset_device_snapshot
before insert or update of asset_id, asset_device_id
on public.work_orders
for each row
execute function public.sync_work_order_asset_device_snapshot();

drop trigger if exists sync_procedure_template_asset_device_snapshot
on public.procedure_templates;

create trigger sync_procedure_template_asset_device_snapshot
before insert or update of asset_id, asset_device_id
on public.procedure_templates
for each row
execute function public.sync_procedure_template_asset_device_snapshot();

commit;
