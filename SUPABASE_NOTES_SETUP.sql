create extension if not exists pgcrypto;

create table if not exists public.notes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null default '',
  content text not null default '',
  image_paths text[] not null default '{}'::text[],
  content_blocks jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

alter table public.notes add column if not exists content text not null default '';
alter table public.notes add column if not exists image_paths text[] not null default '{}'::text[];
alter table public.notes add column if not exists content_blocks jsonb not null default '[]'::jsonb;

update public.notes
set content_blocks = (
  coalesce(
    (
      select jsonb_agg(item)
      from (
        select jsonb_build_object(
          'id', gen_random_uuid()::text,
          'type', 'text',
          'text', content,
          'image_path', ''
        ) as item
        where coalesce(trim(content), '') <> ''
        union all
        select jsonb_build_object(
          'id', gen_random_uuid()::text,
          'type', 'image',
          'text', '',
          'image_path', image_path
        )
        from unnest(coalesce(image_paths, '{}'::text[])) as image_path
        where coalesce(trim(image_path), '') <> ''
      ) source
    ),
    '[]'::jsonb
  )
)
where coalesce(jsonb_array_length(content_blocks), 0) = 0;

alter table public.notes enable row level security;

drop policy if exists "notes_select_own" on public.notes;
create policy "notes_select_own"
on public.notes
for select
to authenticated
using (
  user_id = auth.uid()
  and not public.is_client()
);

drop policy if exists "notes_insert_own" on public.notes;
create policy "notes_insert_own"
on public.notes
for insert
to authenticated
with check (
  user_id = auth.uid()
  and not public.is_client()
);

drop policy if exists "notes_update_own" on public.notes;
create policy "notes_update_own"
on public.notes
for update
to authenticated
using (
  user_id = auth.uid()
  and not public.is_client()
)
with check (
  user_id = auth.uid()
  and not public.is_client()
);

drop policy if exists "notes_delete_own" on public.notes;
create policy "notes_delete_own"
on public.notes
for delete
to authenticated
using (
  user_id = auth.uid()
  and not public.is_client()
);

insert into storage.buckets (id, name, public)
values ('note-images', 'note-images', false)
on conflict (id) do update set public = excluded.public;

drop policy if exists "note_images_select_own" on storage.objects;
create policy "note_images_select_own"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'note-images'
  and split_part(name, '/', 1) = auth.uid()::text
  and not public.is_client()
);

drop policy if exists "note_images_insert_own" on storage.objects;
create policy "note_images_insert_own"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'note-images'
  and split_part(name, '/', 1) = auth.uid()::text
  and not public.is_client()
);

drop policy if exists "note_images_update_own" on storage.objects;
create policy "note_images_update_own"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'note-images'
  and split_part(name, '/', 1) = auth.uid()::text
  and not public.is_client()
)
with check (
  bucket_id = 'note-images'
  and split_part(name, '/', 1) = auth.uid()::text
  and not public.is_client()
);

drop policy if exists "note_images_delete_own" on storage.objects;
create policy "note_images_delete_own"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'note-images'
  and split_part(name, '/', 1) = auth.uid()::text
  and not public.is_client()
);
