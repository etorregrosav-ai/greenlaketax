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
  -- Plazos AEAT (norma general; ver nota en admin/deadlines.js sobre ajustes por año)
  quarterly_q4_extended boolean not null default false, -- T4 con plazo ampliado hasta el 30 de enero (p.ej. IVA 303, pagos fraccionados 130/131)
  deadline_start_month int,  -- solo periodicidad "anual": mes de inicio de la ventana de presentación (1-12)
  deadline_start_day int,
  deadline_end_month int,    -- mes límite de presentación
  deadline_end_day int,
  domiciliacion_offset_days int, -- días antes del fin de presentación en que cierra la domiciliación; NULL = no domiciliable (solo NRC)
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

create table if not exists public.obligation_filings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  client_id uuid not null references public.clients(id) on delete cascade,
  obligation_type_id uuid not null references public.obligation_types(id) on delete cascade,
  period_label text not null, -- p.ej. "1ºT 2026" o "2026", igual que period_label en admin/deadlines.js
  filed boolean not null default false,
  filed_date date,
  created_at timestamptz not null default now(),
  unique (client_id, obligation_type_id, period_label)
);

create table if not exists public.documents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  client_id uuid not null references public.clients(id) on delete cascade,
  obligation_type_id uuid references public.obligation_types(id) on delete set null,
  storage_path text not null, -- ruta dentro del bucket "client-documents"
  file_name text not null,
  category text not null default 'otro', -- factura, modelo_presentado, otro
  amount numeric, -- importe opcional, para poder graficar sin depender de leer el PDF
  doc_date date,  -- fecha del documento (emisión de la factura, presentación del modelo...)
  notes text,
  uploaded_at timestamptz not null default now()
);

-- ============================================================
-- SEGURIDAD: Row Level Security — cada usuario solo ve sus propios datos
-- ============================================================

alter table public.clients enable row level security;
alter table public.obligation_types enable row level security;
alter table public.client_obligations enable row level security;
alter table public.obligation_filings enable row level security;
alter table public.documents enable row level security;

create policy "clients_owner_all" on public.clients
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "obligation_types_owner_all" on public.obligation_types
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "client_obligations_owner_all" on public.client_obligations
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "obligation_filings_owner_all" on public.obligation_filings
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "documents_owner_all" on public.documents
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ============================================================
-- ÍNDICES
-- ============================================================

create index if not exists idx_clients_user on public.clients(user_id);
create index if not exists idx_obligation_types_user on public.obligation_types(user_id);
create index if not exists idx_client_obligations_client on public.client_obligations(client_id);
create index if not exists idx_client_obligations_user on public.client_obligations(user_id);
create index if not exists idx_documents_client on public.documents(client_id);
create index if not exists idx_documents_user on public.documents(user_id);
create index if not exists idx_obligation_filings_client on public.obligation_filings(client_id);
create index if not exists idx_obligation_filings_user on public.obligation_filings(user_id);

-- ============================================================
-- ALMACENAMIENTO: bucket "client-documents" (crear primero desde
-- el Dashboard → Storage → New bucket → nombre "client-documents",
-- privado/no público) y luego ejecutar estas políticas:
-- ============================================================

create policy "documents_storage_select" on storage.objects
  for select using (bucket_id = 'client-documents' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "documents_storage_insert" on storage.objects
  for insert with check (bucket_id = 'client-documents' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "documents_storage_update" on storage.objects
  for update using (bucket_id = 'client-documents' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "documents_storage_delete" on storage.objects
  for delete using (bucket_id = 'client-documents' and (storage.foldername(name))[1] = auth.uid()::text);
