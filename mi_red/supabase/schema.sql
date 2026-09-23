-- Mi Red: CRM de network marketing
-- Ejecutar en Supabase Dashboard -> SQL Editor -> New query
-- Puede usar el MISMO proyecto de Supabase que el lector EPUB y Bitácora
-- (comparte usuarios); solo agrega estas tablas nuevas.

create extension if not exists "pgcrypto";

-- Prospectos, clientes y socios. Un mismo registro avanza por las etapas
-- del embudo (stage). sponsor_id indica quién lo patrocina dentro de tu
-- equipo; si es null y es socio, es de tu primera línea.
create table if not exists public.crm_contacts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name text not null,
  phone text not null default '',
  email text not null default '',
  city text not null default '',
  source text not null default '',
  interest text not null default 'cliente'
    check (interest in ('cliente', 'socio', 'ambos')),
  stage text not null default 'nuevo'
    check (stage in ('nuevo', 'contactado', 'presentacion', 'seguimiento',
                     'cliente', 'socio', 'descartado')),
  sponsor_id uuid references public.crm_contacts (id) on delete set null,
  notes text not null default '',
  next_follow_up date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists crm_contacts_user_stage_idx
  on public.crm_contacts (user_id, stage);
create index if not exists crm_contacts_user_follow_up_idx
  on public.crm_contacts (user_id, next_follow_up);

-- Historial de contacto con cada persona (llamadas, mensajes, reuniones).
create table if not exists public.crm_interactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  contact_id uuid not null references public.crm_contacts (id) on delete cascade,
  kind text not null default 'llamada'
    check (kind in ('llamada', 'whatsapp', 'reunion', 'presentacion', 'otro')),
  note text not null default '',
  occurred_at timestamptz not null default now()
);

create index if not exists crm_interactions_contact_idx
  on public.crm_interactions (contact_id, occurred_at desc);

-- Ventas / pedidos, con monto y puntos de volumen (PV).
create table if not exists public.crm_sales (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  contact_id uuid references public.crm_contacts (id) on delete set null,
  product text not null,
  amount numeric(12, 2) not null default 0,
  points numeric(12, 2) not null default 0,
  sale_date date not null default current_date,
  created_at timestamptz not null default now()
);

create index if not exists crm_sales_user_date_idx
  on public.crm_sales (user_id, sale_date);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists crm_contacts_set_updated_at on public.crm_contacts;
create trigger crm_contacts_set_updated_at
  before update on public.crm_contacts
  for each row execute function public.set_updated_at();

alter table public.crm_contacts enable row level security;
alter table public.crm_interactions enable row level security;
alter table public.crm_sales enable row level security;

drop policy if exists "Users manage their own crm contacts" on public.crm_contacts;
create policy "Users manage their own crm contacts"
  on public.crm_contacts
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users manage their own crm interactions" on public.crm_interactions;
create policy "Users manage their own crm interactions"
  on public.crm_interactions
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users manage their own crm sales" on public.crm_sales;
create policy "Users manage their own crm sales"
  on public.crm_sales
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
