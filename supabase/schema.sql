-- Green Lake — esquema de la base de datos para /admin
-- Ejecutar en Supabase: Project → SQL Editor → New query → pegar y ejecutar

-- ============================================================
-- TABLAS
-- ============================================================

create table if not exists public.clients (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null,
  tax_id text,
  person_type text not null check (person_type in ('fisica','juridica')),
  residency text not null check (residency in ('residente','no_residente')),
  has_pe boolean not null default false, -- establecimiento permanente en España (solo relevante si juridica + no_residente)
  is_self boolean not null default false, -- true para tu propia ficha como autónomo
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists public.obligation_types (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  code text not null,
  name text not null,
  description text,
  category text not null default 'General', -- IRPF, IVA, IS, IRNR, Retenciones, Informativo, Patrimonio, Formal
  periodicity text not null default 'anual', -- mensual, trimestral, anual, puntual
  applies_fisica_residente boolean not null default false,
  applies_fisica_no_residente boolean not null default false,
  applies_juridica_residente boolean not null default false,
  applies_juridica_no_residente boolean not null default false,
  created_at timestamptz not null default now(),
  unique (user_id, code)
);

create table if not exists public.client_obligations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  client_id uuid not null references public.clients(id) on delete cascade,
  obligation_type_id uuid not null references public.obligation_types(id) on delete cascade,
  active boolean not null default true,
  status text not null default 'pendiente', -- pendiente, al_dia, atrasado
  notes text,
  created_at timestamptz not null default now(),
  unique (client_id, obligation_type_id)
);

-- ============================================================
-- SEGURIDAD: Row Level Security — cada usuario solo ve sus propios datos
-- ============================================================

alter table public.clients enable row level security;
alter table public.obligation_types enable row level security;
alter table public.client_obligations enable row level security;

create policy "clients_owner_all" on public.clients
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "obligation_types_owner_all" on public.obligation_types
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "client_obligations_owner_all" on public.client_obligations
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ============================================================
-- ÍNDICES
-- ============================================================

create index if not exists idx_clients_user on public.clients(user_id);
create index if not exists idx_obligation_types_user on public.obligation_types(user_id);
create index if not exists idx_client_obligations_client on public.client_obligations(client_id);
create index if not exists idx_client_obligations_user on public.client_obligations(user_id);
