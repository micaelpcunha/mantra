begin;

alter table if exists public.work_orders
  add column if not exists audio_note_url text;

comment on column public.work_orders.audio_note_url is
  'Caminho privado no Storage ou URL assinada para a nota audio associada a ordem.';

commit;
