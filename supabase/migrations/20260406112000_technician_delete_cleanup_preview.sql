begin;

create or replace function public.admin_preview_technician_delete(p_technician_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $function$
declare
  v_technician public.technicians;
  v_linked_user_count integer := 0;
  v_work_order_count integer := 0;
  v_default_asset_count integer := 0;
  v_planned_day_asset_count integer := 0;
begin
  if auth.uid() is null then
    raise exception 'Sessao invalida.';
  end if;

  if p_technician_id is null then
    raise exception 'O tecnico a eliminar e obrigatorio.';
  end if;

  if not public.can_manage_technician_records() then
    raise exception 'Nao tens permissao para eliminar tecnicos.';
  end if;

  select t.*
  into v_technician
  from public.technicians t
  where t.id = p_technician_id
    and public.belongs_to_current_company(t.company_id)
  limit 1;

  if not found then
    raise exception 'Nao foi encontrado um tecnico desta empresa.';
  end if;

  select count(*)::integer
  into v_linked_user_count
  from public.profiles p
  where p.technician_id = p_technician_id
    and public.belongs_to_current_company(p.company_id);

  select count(*)::integer
  into v_work_order_count
  from public.work_orders wo
  where wo.technician_id = p_technician_id
    and public.belongs_to_current_company(wo.company_id);

  select count(*)::integer
  into v_default_asset_count
  from public.assets a
  where a.default_technician_id = p_technician_id
    and public.belongs_to_current_company(a.company_id);

  if to_regclass('public.planned_day_assets') is not null then
    execute
      'select count(*)::integer
       from public.planned_day_assets
       where technician_id = $1
         and public.belongs_to_current_company(company_id)'
    into v_planned_day_asset_count
    using p_technician_id;
  end if;

  return jsonb_build_object(
    'linked_user_count', v_linked_user_count,
    'work_order_count', v_work_order_count,
    'default_asset_count', v_default_asset_count,
    'planned_day_asset_count', v_planned_day_asset_count
  );
end;
$function$;

drop function if exists public.admin_delete_technician_bundle(uuid);

create or replace function public.admin_delete_technician_bundle(p_technician_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $function$
declare
  v_technician public.technicians;
  v_linked_user_ids uuid[];
  v_preview jsonb;
  v_linked_user_count integer := 0;
  v_default_asset_count integer := 0;
  v_planned_day_asset_count integer := 0;
begin
  if auth.uid() is null then
    raise exception 'Sessao invalida.';
  end if;

  if p_technician_id is null then
    raise exception 'O tecnico a eliminar e obrigatorio.';
  end if;

  if not public.can_manage_technician_records() then
    raise exception 'Nao tens permissao para eliminar tecnicos.';
  end if;

  select t.*
  into v_technician
  from public.technicians t
  where t.id = p_technician_id
    and public.belongs_to_current_company(t.company_id)
  limit 1;

  if not found then
    raise exception 'Nao foi encontrado um tecnico desta empresa.';
  end if;

  v_preview := public.admin_preview_technician_delete(p_technician_id);
  v_linked_user_count := coalesce((v_preview ->> 'linked_user_count')::integer, 0);
  v_default_asset_count := coalesce((v_preview ->> 'default_asset_count')::integer, 0);
  v_planned_day_asset_count := coalesce((v_preview ->> 'planned_day_asset_count')::integer, 0);

  select coalesce(array_agg(p.id), '{}'::uuid[])
  into v_linked_user_ids
  from public.profiles p
  where p.technician_id = p_technician_id
    and public.belongs_to_current_company(p.company_id);

  if auth.uid() = any(v_linked_user_ids) then
    raise exception 'Nao podes eliminar o teu proprio acesso tecnico.';
  end if;

  if coalesce(array_length(v_linked_user_ids, 1), 0) > 0
     and not public.can_manage_user_accounts() then
    raise exception 'Nao tens permissao para eliminar o acesso associado a este tecnico.';
  end if;

  update public.work_orders
  set technician_id = null
  where technician_id = p_technician_id
    and public.belongs_to_current_company(company_id);

  if v_default_asset_count > 0 then
    update public.assets
    set default_technician_id = null
    where default_technician_id = p_technician_id
      and public.belongs_to_current_company(company_id);
  end if;

  if v_planned_day_asset_count > 0
     and to_regclass('public.planned_day_assets') is not null then
    execute
      'delete from public.planned_day_assets
       where technician_id = $1
         and public.belongs_to_current_company(company_id)'
    using p_technician_id;
  end if;

  if v_linked_user_count > 0 then
    delete from public.profiles
    where technician_id = p_technician_id
      and public.belongs_to_current_company(company_id);

    delete from auth.users
    where id = any(v_linked_user_ids);
  end if;

  delete from public.technicians
  where id = p_technician_id
    and public.belongs_to_current_company(company_id);

  if not found then
    raise exception 'Nao foi possivel remover o tecnico.';
  end if;

  return v_preview;
end;
$function$;

grant execute on function public.admin_preview_technician_delete(uuid) to authenticated;
grant execute on function public.admin_delete_technician_bundle(uuid) to authenticated;

commit;
