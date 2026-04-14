begin;

insert into public.profiles (
  id,
  email,
  full_name,
  role,
  technician_id,
  company_id
)
select
  u.id,
  u.email,
  coalesce(
    nullif(trim(coalesce(u.raw_user_meta_data ->> 'full_name', '')), ''),
    p.full_name
  ) as full_name,
  case
    when lower(trim(coalesce(u.raw_user_meta_data ->> 'role', ''))) in ('admin', 'technician', 'client')
      then lower(trim(u.raw_user_meta_data ->> 'role'))
    when lower(trim(coalesce(p.role, ''))) in ('admin', 'technician', 'client')
      then lower(trim(p.role))
    else 'technician'
  end as role,
  case
    when lower(trim(coalesce(u.raw_user_meta_data ->> 'role', ''))) = 'technician'
         and trim(coalesce(u.raw_user_meta_data ->> 'technician_id', '')) ~* '^[0-9a-f-]{36}$'
      then (trim(u.raw_user_meta_data ->> 'technician_id'))::uuid
    when lower(trim(coalesce(p.role, ''))) = 'technician'
      then p.technician_id
    else null
  end as technician_id,
  case
    when trim(coalesce(u.raw_user_meta_data ->> 'company_id', '')) ~* '^[0-9a-f-]{36}$'
      then (trim(u.raw_user_meta_data ->> 'company_id'))::uuid
    else p.company_id
  end as company_id
from auth.users u
left join public.profiles p
  on p.id = u.id
where p.id is not null
   or trim(coalesce(u.raw_user_meta_data ->> 'company_id', '')) <> ''
   or lower(trim(coalesce(u.raw_user_meta_data ->> 'role', ''))) in ('admin', 'technician', 'client')
on conflict (id) do update
set
  email = excluded.email,
  full_name = coalesce(excluded.full_name, public.profiles.full_name),
  role = excluded.role,
  technician_id = excluded.technician_id,
  company_id = coalesce(excluded.company_id, public.profiles.company_id);

do $$
declare
  v_company_id uuid;
  v_user_id uuid;
  v_full_name text;
begin
  select c.company_id
  into v_company_id
  from public.company_email_connections c
  where lower(trim(coalesce(c.email, ''))) in (
    'pintadooceano@gmail.com',
    'pintadooceano@hotmail.com'
  )
  order by c.created_at asc
  limit 1;

  if v_company_id is null then
    select p.company_id
    into v_company_id
    from public.profiles p
    where lower(trim(coalesce(p.email, ''))) in (
      'pintadooceano@gmail.com',
      'pintadooceano@hotmail.com'
    )
      and p.company_id is not null
    order by p.created_at asc
    limit 1;
  end if;

  select candidate.id, candidate.full_name
  into v_user_id, v_full_name
  from (
    select
      u.id,
      coalesce(
        nullif(trim(coalesce(p.full_name, '')), ''),
        nullif(trim(coalesce(u.raw_user_meta_data ->> 'full_name', '')), ''),
        'Pinta do Oceano'
      ) as full_name,
      u.created_at
    from auth.users u
    left join public.profiles p
      on p.id = u.id
    where lower(trim(coalesce(u.email, ''))) = 'pintadooceano@hotmail.com'

    union all

    select
      p.id,
      coalesce(nullif(trim(coalesce(p.full_name, '')), ''), 'Pinta do Oceano'),
      p.created_at
    from public.profiles p
    where lower(trim(coalesce(p.email, ''))) = 'pintadooceano@hotmail.com'
  ) as candidate
  order by candidate.created_at asc nulls last
  limit 1;

  if v_user_id is not null then
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
      'pintadooceano@hotmail.com',
      v_full_name,
      'admin',
      null,
      v_company_id
    )
    on conflict (id) do update
    set
      email = excluded.email,
      full_name = coalesce(excluded.full_name, public.profiles.full_name),
      role = 'admin',
      technician_id = null,
      company_id = coalesce(excluded.company_id, public.profiles.company_id);

    update auth.users u
    set
      raw_user_meta_data = jsonb_strip_nulls(
        coalesce(u.raw_user_meta_data, '{}'::jsonb) || jsonb_build_object(
          'full_name', v_full_name,
          'role', 'admin',
          'company_id', case
            when v_company_id is null then null
            else v_company_id::text
          end,
          'technician_id', null
        )
      ),
      updated_at = timezone('utc', now())
    where u.id = v_user_id;
  end if;
end;
$$;

commit;
