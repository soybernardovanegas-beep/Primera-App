-- Lector EPUB: funciones estilo Kindle (ejecutar DESPUÉS de schema.sql)
-- Ejecutar en Supabase Dashboard -> SQL Editor -> New query

-- Preferencias de lectura (una fila por usuario, aplica a todos sus libros).
create table if not exists public.reading_settings (
  user_id uuid primary key default auth.uid() references auth.users (id) on delete cascade,
  font_size double precision not null default 16,
  font_family text not null default 'Default',
  line_height double precision not null default 1.25,
  theme text not null default 'light', -- 'light' | 'dark' | 'sepia'
  updated_at timestamptz not null default now()
);

-- Marcadores: posición guardada dentro de un libro.
create table if not exists public.bookmarks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  book_id uuid not null references public.books (id) on delete cascade,
  cfi text not null,
  label text,
  created_at timestamptz not null default now()
);

-- Resaltados y notas sobre pasajes de texto.
create table if not exists public.highlights (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  book_id uuid not null references public.books (id) on delete cascade,
  cfi text not null,
  snippet text not null,
  color text not null default 'yellow',
  note text,
  created_at timestamptz not null default now()
);

-- Sesiones de lectura, usadas para estadísticas (tiempo total, racha de días).
create table if not exists public.reading_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  book_id uuid not null references public.books (id) on delete cascade,
  read_on date not null default current_date,
  seconds integer not null,
  created_at timestamptz not null default now()
);

-- Colecciones para organizar la biblioteca (equivalente a "Collections" de Kindle).
create table if not exists public.collections (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now(),
  unique (user_id, name)
);

create table if not exists public.book_collections (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  book_id uuid not null references public.books (id) on delete cascade,
  collection_id uuid not null references public.collections (id) on delete cascade,
  primary key (book_id, collection_id)
);

alter table public.reading_settings enable row level security;
alter table public.bookmarks enable row level security;
alter table public.highlights enable row level security;
alter table public.reading_sessions enable row level security;
alter table public.collections enable row level security;
alter table public.book_collections enable row level security;

drop policy if exists "Users manage their own reading settings" on public.reading_settings;
create policy "Users manage their own reading settings"
  on public.reading_settings for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "Users manage their own bookmarks" on public.bookmarks;
create policy "Users manage their own bookmarks"
  on public.bookmarks for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "Users manage their own highlights" on public.highlights;
create policy "Users manage their own highlights"
  on public.highlights for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "Users manage their own reading sessions" on public.reading_sessions;
create policy "Users manage their own reading sessions"
  on public.reading_sessions for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "Users manage their own collections" on public.collections;
create policy "Users manage their own collections"
  on public.collections for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "Users manage their own book collections" on public.book_collections;
create policy "Users manage their own book collections"
  on public.book_collections for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
