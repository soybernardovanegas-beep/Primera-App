-- Mi Red v2: calificación, recordatorios múltiples, perfil y guías.
-- Ejecutar DESPUÉS de schema.sql, en Supabase Dashboard -> SQL Editor.
-- Solo agrega columnas y tablas; no borra datos. Se puede ejecutar más de
-- una vez sin problema.

-- ---------- Contactos: calificación y datos extra ----------

alter table public.crm_contacts
  add column if not exists referred_by text not null default '',
  add column if not exists tags text[] not null default '{}',
  add column if not exists temperature text not null default 'frio',
  add column if not exists favorite boolean not null default false,
  -- Respuestas del cuestionario de calificación (null = sin calificar).
  add column if not exists score_age smallint,
  add column if not exists score_credibility smallint,
  add column if not exists score_solvency smallint,
  add column if not exists score_social smallint,
  -- "Su Porqué": lo que mueve a la persona, para la presentación.
  add column if not exists why_income text not null default '',
  add column if not exists why_health text not null default '',
  -- "Contactar después": oculto del proceso hasta esta fecha.
  add column if not exists snoozed_until date;

alter table public.crm_contacts
  drop constraint if exists crm_contacts_temperature_check;
alter table public.crm_contacts
  add constraint crm_contacts_temperature_check
  check (temperature in ('frio', 'caliente'));

-- Puntaje total (máximo 20). Null mientras no se haya calificado.
alter table public.crm_contacts
  add column if not exists score smallint generated always as (
    case
      when score_age is null or score_credibility is null
        or score_solvency is null or score_social is null then null
      else score_age + score_credibility + score_solvency + score_social
    end
  ) stored;

-- ---------- Recordatorios (varios por contacto) ----------

create table if not exists public.crm_reminders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  contact_id uuid not null references public.crm_contacts (id) on delete cascade,
  due_at timestamptz not null,
  note text not null default '',
  done boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists crm_reminders_user_due_idx
  on public.crm_reminders (user_id, done, due_at);

-- Pasa los "próximo seguimiento" de la versión 1 a recordatorios (9:00 a.m.
-- hora de Colombia) y limpia la columna vieja para no duplicarlos.
insert into public.crm_reminders (user_id, contact_id, due_at, note)
select user_id, id,
       (next_follow_up + time '09:00') at time zone 'America/Bogota',
       'Seguimiento'
from public.crm_contacts
where next_follow_up is not null;

update public.crm_contacts set next_follow_up = null
where next_follow_up is not null;

-- ---------- Perfil del usuario ----------

create table if not exists public.crm_profile (
  user_id uuid primary key default auth.uid() references auth.users (id) on delete cascade,
  display_name text not null default '',
  my_why text not null default '',
  ideal_goal smallint not null default 20,
  updated_at timestamptz not null default now()
);

drop trigger if exists crm_profile_set_updated_at on public.crm_profile;
create trigger crm_profile_set_updated_at
  before update on public.crm_profile
  for each row execute function public.set_updated_at();

-- ---------- Guías editadas por el usuario ----------
-- La app trae textos por defecto; aquí solo se guardan los que edites.

create table if not exists public.crm_guides (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  key text not null,
  content text not null,
  updated_at timestamptz not null default now(),
  primary key (user_id, key)
);

-- ---------- Seguridad ----------

alter table public.crm_reminders enable row level security;
alter table public.crm_profile enable row level security;
alter table public.crm_guides enable row level security;

drop policy if exists "Users manage their own crm reminders" on public.crm_reminders;
create policy "Users manage their own crm reminders"
  on public.crm_reminders
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users manage their own crm profile" on public.crm_profile;
create policy "Users manage their own crm profile"
  on public.crm_profile
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users manage their own crm guides" on public.crm_guides;
create policy "Users manage their own crm guides"
  on public.crm_guides
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
