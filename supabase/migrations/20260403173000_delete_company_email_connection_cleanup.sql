begin;

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

commit;
