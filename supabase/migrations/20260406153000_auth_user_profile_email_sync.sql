begin;

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

commit;
