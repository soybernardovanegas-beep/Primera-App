-- Lector EPUB: esquema de base de datos y políticas de seguridad
-- Ejecutar en Supabase Dashboard -> SQL Editor -> New query

create extension if not exists "pgcrypto";

-- Biblioteca: un libro identificado por el hash de su contenido, para que
-- el mismo EPUB importado por separado en Android y Windows se reconozca
-- como "el mismo libro" sin necesidad de subir el archivo en sí.
create table if not exists public.books (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  hash text not null,
  title text not null,
  author text,
  added_at timestamptz not null default now(),
  unique (user_id, hash)
);

-- Progreso de lectura por libro y usuario.
create table if not exists public.reading_progress (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  book_id uuid not null references public.books (id) on delete cascade,
  location text,
  percentage double precision not null default 0,
  updated_at timestamptz not null default now(),
  unique (user_id, book_id)
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

drop trigger if exists reading_progress_set_updated_at on public.reading_progress;
create trigger reading_progress_set_updated_at
  before update on public.reading_progress
  for each row execute function public.set_updated_at();

alter table public.books enable row level security;
alter table public.reading_progress enable row level security;

drop policy if exists "Users manage their own books" on public.books;
create policy "Users manage their own books"
  on public.books
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users manage their own reading progress" on public.reading_progress;
create policy "Users manage their own reading progress"
  on public.reading_progress
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
