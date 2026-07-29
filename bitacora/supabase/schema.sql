-- Bitácora: esquema de base de datos y políticas de seguridad
-- Ejecutar en Supabase Dashboard -> SQL Editor -> New query
-- Usa el MISMO proyecto de Supabase que ya tienes (comparte usuarios con
-- el lector EPUB), solo agrega estas dos tablas nuevas.

create extension if not exists "pgcrypto";

-- Pendientes/tareas agendados en un día concreto.
create table if not exists public.agenda_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  item_date date not null,
  text text not null,
  done boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists agenda_items_user_date_idx
  on public.agenda_items (user_id, item_date);

-- Notas libres (una por usuario), como el bloc de notas general de la app.
create table if not exists public.agenda_notes (
  user_id uuid primary key default auth.uid() references auth.users (id) on delete cascade,
  content text not null default '',
  updated_at timestamptz not null default now()
);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists agenda_notes_set_updated_at on public.agenda_notes;
create trigger agenda_notes_set_updated_at
  before update on public.agenda_notes
  for each row execute function public.set_updated_at();

alter table public.agenda_items enable row level security;
alter table public.agenda_notes enable row level security;

drop policy if exists "Users manage their own agenda items" on public.agenda_items;
create policy "Users manage their own agenda items"
  on public.agenda_items
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users manage their own agenda notes" on public.agenda_notes;
create policy "Users manage their own agenda notes"
  on public.agenda_notes
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
