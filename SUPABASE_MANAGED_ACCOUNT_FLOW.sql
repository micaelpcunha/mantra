begin;

create extension if not exists pgcrypto;

create or replace function public.can_manage_user_accounts()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_admin()
    or (
      public.is_technician()
      and public.profile_flag('can_manage_users')
      and public.technician_record_allows('can_manage_users')
    )
$$;

create or replace function public.can_manage_technician_records()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_admin()
    or (
      public.is_technician()
      and public.profile_flag('can_manage_technicians')
      and public.technician_record_allows('can_manage_technicians')
    )
$$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_existing_profile public.profiles%rowtype;
  v_role text;
  v_role_from_metadata text;
  v_company_id uuid;
  v_technician_id uuid;
  v_full_name text;
begin
  select *
  into v_existing_profile
  from public.profiles
  where id = new.id;

  v_role_from_metadata := lower(trim(coalesce(new.raw_user_meta_data ->> 'role', '')));
  if v_role_from_metadata in ('admin', 'technician', 'client') then
    v_role := v_role_from_metadata;
  else
    v_role := lower(trim(coalesce(v_existing_profile.role, 'technician')));
  end if;

  if v_role not in ('admin', 'technician', 'client') then
    v_role := 'technician';
  end if;

  if coalesce(new.raw_user_meta_data ? 'company_id', false) then
    begin
      v_company_id := nullif(trim(coalesce(new.raw_user_meta_data ->> 'company_id', '')), '')::uuid;
    exception
      when others then
        v_company_id := v_existing_profile.company_id;
    end;
  else
    v_company_id := v_existing_profile.company_id;
  end if;

  if coalesce(new.raw_user_meta_data ? 'technician_id', false) then
    begin
      v_technician_id := nullif(trim(coalesce(new.raw_user_meta_data ->> 'technician_id', '')), '')::uuid;
    exception
      when others then
        v_technician_id := v_existing_profile.technician_id;
    end;
  else
    v_technician_id := v_existing_profile.technician_id;
  end if;

  v_full_name := nullif(trim(coalesce(new.raw_user_meta_data ->> 'full_name', '')), '');
  if v_full_name is null then
    v_full_name := nullif(trim(coalesce(v_existing_profile.full_name, '')), '');
  end if;

  if v_role <> 'technician' then
    v_technician_id := null;
  end if;

  insert into public.profiles (
    id,
    email,
    full_name,
    role,
    technician_id,
    company_id
  )
  values (
    new.id,
    new.email,
    v_full_name,
    v_role,
    v_technician_id,
    v_company_id
  )
  on conflict (id) do update
  set
    email = excluded.email,
    full_name = coalesce(excluded.full_name, public.profiles.full_name),
    role = excluded.role,
    technician_id = excluded.technician_id,
    company_id = coalesce(excluded.company_id, public.profiles.company_id);

  return new;
end;
$function$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

drop trigger if exists on_auth_user_profile_updated on auth.users;
create trigger on_auth_user_profile_updated
after update of email, raw_user_meta_data on auth.users
for each row
when (
  old.email is distinct from new.email
  or old.raw_user_meta_data is distinct from new.raw_user_meta_data
)
execute procedure public.handle_new_user();

create or replace function public.admin_create_auth_user(
  p_email text,
  p_password text,
  p_role text default 'technician',
  p_full_name text default null,
  p_technician_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public, auth, extensions
as $function$
declare
  v_company_id uuid := public.current_user_company_id();
  v_email text := lower(trim(coalesce(p_email, '')));
  v_password text := coalesce(p_password, '');
  v_role text := lower(trim(coalesce(p_role, 'technician')));
  v_full_name text := nullif(trim(coalesce(p_full_name, '')), '');
  v_technician_id uuid := p_technician_id;
  v_existing_user_id uuid;
  v_existing_profile_id uuid;
  v_user_id uuid := gen_random_uuid();
  v_metadata jsonb;
begin
  if auth.uid() is null then
    raise exception 'Sessao invalida.';
  end if;

  if not public.can_manage_user_accounts() then
    raise exception 'Nao tens permissao para criar acessos.';
  end if;

  if v_company_id is null then
    raise exception 'Nao foi possivel identificar a empresa atual.';
  end if;

  if v_email = '' then
    raise exception 'O email e obrigatorio.';
  end if;

  if position('@' in v_email) = 0 then
    raise exception 'Indica um email valido.';
  end if;

  if char_length(v_password) < 8 then
    raise exception 'A password tem de ter pelo menos 8 caracteres.';
  end if;

  if v_role not in ('admin', 'technician', 'client') then
    raise exception 'Perfil invalido.';
  end if;

  if v_role <> 'technician' then
    v_technician_id := null;
  end if;

  if v_role = 'technician' and v_technician_id is null then
    raise exception 'Escolhe primeiro o tecnico associado.';
  end if;

  if v_role = 'technician' then
    perform 1
    from public.technicians t
    where t.id = v_technician_id
      and public.belongs_to_current_company(t.company_id);

    if not found then
      raise exception 'O tecnico associado nao pertence a esta empresa.';
    end if;
  end if;

  select u.id
  into v_existing_user_id
  from auth.users u
  where lower(coalesce(u.email, '')) = v_email
    and u.deleted_at is null
  limit 1;

  if v_existing_user_id is not null then
    raise exception 'Ja existe uma conta de acesso com esse email.';
  end if;

  select p.id
  into v_existing_profile_id
  from public.profiles p
  where lower(coalesce(p.email, '')) = v_email
  limit 1;

  if v_existing_profile_id is not null then
    raise exception 'Ja existe um perfil com esse email.';
  end if;

  v_metadata := jsonb_strip_nulls(
    jsonb_build_object(
      'full_name', v_full_name,
      'role', v_role,
      'company_id', v_company_id::text,
      'technician_id', case when v_technician_id is null then null else v_technician_id::text end,
      'email_verified', true
    )
  );

  insert into auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    confirmation_token,
    recovery_token,
    email_change_token_new,
    email_change,
    raw_app_meta_data,
    raw_user_meta_data,
    phone_change,
    phone_change_token,
    email_change_token_current,
    reauthentication_token,
    created_at,
    updated_at,
    is_sso_user,
    is_anonymous
  )
  values (
    '00000000-0000-0000-0000-000000000000',
    v_user_id,
    'authenticated',
    'authenticated',
    v_email,
    extensions.crypt(v_password, extensions.gen_salt('bf', 10)),
    timezone('utc', now()),
    '',
    '',
    '',
    '',
    jsonb_build_object('provider', 'email', 'providers', jsonb_build_array('email')),
    v_metadata,
    '',
    '',
    '',
    '',
    timezone('utc', now()),
    timezone('utc', now()),
    false,
    false
  );

  insert into auth.identities (
    id,
    provider_id,
    user_id,
    identity_data,
    provider,
    created_at,
    updated_at
  )
  values (
    gen_random_uuid(),
    v_user_id::text,
    v_user_id,
    jsonb_build_object(
      'sub', v_user_id::text,
      'email', v_email,
      'email_verified', false,
      'phone_verified', false
    ),
    'email',
    timezone('utc', now()),
    timezone('utc', now())
  );

  insert into public.profiles (
    id,
    email,
    full_name,
    role,
    technician_id,
    company_id
  )
  values (
    v_user_id,
    v_email,
    v_full_name,
    v_role,
    v_technician_id,
    v_company_id
  )
  on conflict (id) do update
  set
    email = excluded.email,
    full_name = excluded.full_name,
    role = excluded.role,
    technician_id = excluded.technician_id,
    company_id = excluded.company_id;

  return v_user_id;
end;
$function$;

create or replace function public.admin_delete_auth_user(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public, auth
as $function$
declare
  v_target_profile public.profiles;
begin
  if auth.uid() is null then
    raise exception 'Sessao invalida.';
  end if;

  if p_user_id is null then
    raise exception 'O utilizador a eliminar e obrigatorio.';
  end if;

  if p_user_id = auth.uid() then
    raise exception 'Nao podes eliminar o teu proprio acesso.';
  end if;

  if not public.can_manage_user_accounts() then
    raise exception 'Nao tens permissao para eliminar acessos.';
  end if;

  select p.*
  into v_target_profile
  from public.profiles p
  where p.id = p_user_id
    and public.belongs_to_current_company(p.company_id)
  limit 1;

  if not found then
    raise exception 'Nao foi encontrado um utilizador desta empresa.';
  end if;

  delete from public.profiles
  where id = p_user_id
    and public.belongs_to_current_company(company_id);

  delete from auth.users
  where id = p_user_id;

  if not found then
    raise exception 'Nao foi possivel remover a conta de acesso.';
  end if;
end;
$function$;

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

grant execute on function public.can_manage_user_accounts() to authenticated;
grant execute on function public.can_manage_technician_records() to authenticated;
grant execute on function public.admin_create_auth_user(text, text, text, text, uuid) to authenticated;
grant execute on function public.admin_delete_auth_user(uuid) to authenticated;
grant execute on function public.admin_preview_technician_delete(uuid) to authenticated;
grant execute on function public.admin_delete_technician_bundle(uuid) to authenticated;

commit;
