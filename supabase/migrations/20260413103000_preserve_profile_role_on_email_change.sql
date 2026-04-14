begin;

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

update auth.users u
set
  raw_user_meta_data = jsonb_strip_nulls(
    coalesce(u.raw_user_meta_data, '{}'::jsonb) || jsonb_build_object(
      'full_name', nullif(trim(coalesce(p.full_name, '')), ''),
      'role', case
        when lower(trim(coalesce(p.role, ''))) in ('admin', 'technician', 'client')
          then lower(trim(p.role))
        else null
      end,
      'company_id', case
        when p.company_id is null then null
        else p.company_id::text
      end,
      'technician_id', case
        when p.technician_id is null then null
        else p.technician_id::text
      end
    )
  ),
  updated_at = timezone('utc', now())
from public.profiles p
where p.id = u.id
  and (
    coalesce(trim(u.raw_user_meta_data ->> 'full_name'), '') is distinct from
      coalesce(trim(p.full_name), '')
    or coalesce(lower(trim(u.raw_user_meta_data ->> 'role')), '') is distinct from
      coalesce(lower(trim(p.role)), '')
    or coalesce(trim(u.raw_user_meta_data ->> 'company_id'), '') is distinct from
      coalesce(p.company_id::text, '')
    or coalesce(trim(u.raw_user_meta_data ->> 'technician_id'), '') is distinct from
      coalesce(p.technician_id::text, '')
  );

do $$
declare
  v_target_user_id uuid;
  v_target_company_id uuid;
begin
  select c.created_by, c.company_id
  into v_target_user_id, v_target_company_id
  from public.company_email_connections c
  where lower(trim(coalesce(c.email, ''))) = 'pintadooceano@gmail.com'
    and c.created_by is not null
  order by c.created_at asc
  limit 1;

  if v_target_user_id is null then
    select p.id, p.company_id
    into v_target_user_id, v_target_company_id
    from public.profiles p
    where lower(trim(coalesce(p.email, ''))) = 'pintadooceano@gmail.com'
    order by p.created_at asc
    limit 1;
  end if;

  if v_target_user_id is null then
    select u.id
    into v_target_user_id
    from auth.users u
    where lower(trim(coalesce(u.email, ''))) = 'pintadooceano@gmail.com'
    order by u.created_at asc
    limit 1;
  end if;

  if v_target_user_id is not null and v_target_company_id is null then
    select p.company_id
    into v_target_company_id
    from public.profiles p
    where p.id = v_target_user_id;
  end if;

  if v_target_user_id is not null then
    update public.profiles p
    set
      email = coalesce(
        (select u.email from auth.users u where u.id = p.id),
        p.email
      ),
      role = 'admin',
      technician_id = null,
      company_id = coalesce(p.company_id, v_target_company_id)
    where p.id = v_target_user_id;

    update auth.users u
    set
      raw_user_meta_data = jsonb_strip_nulls(
        coalesce(u.raw_user_meta_data, '{}'::jsonb) || jsonb_build_object(
          'full_name', coalesce(
            (select nullif(trim(p.full_name), '') from public.profiles p where p.id = u.id),
            nullif(trim(coalesce(u.raw_user_meta_data ->> 'full_name', '')), '')
          ),
          'role', 'admin',
          'company_id', case
            when coalesce(
              (select p.company_id from public.profiles p where p.id = u.id),
              v_target_company_id
            ) is null then null
            else coalesce(
              (select p.company_id from public.profiles p where p.id = u.id),
              v_target_company_id
            )::text
          end,
          'technician_id', null
        )
      ),
      updated_at = timezone('utc', now())
    where u.id = v_target_user_id;

    update public.profiles p
    set email = coalesce(
      (select u.email from auth.users u where u.id = p.id),
      p.email
    )
    where p.id = v_target_user_id;
  end if;
end;
$$;

commit;
