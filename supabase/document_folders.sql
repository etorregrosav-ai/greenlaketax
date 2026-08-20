-- Green Lake /admin — carpetas de documentos por cliente (KYC, Declaraciones, etc.)
-- Ejecutar una sola vez en el SQL Editor de Supabase.

create table if not exists public.document_folders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  client_id uuid not null references public.clients(id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now(),
  unique (client_id, name)
);

alter table public.document_folders enable row level security;

create policy "document_folders_owner_all" on public.document_folders
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create index if not exists idx_document_folders_client on public.document_folders(client_id);
create index if not exists idx_document_folders_user on public.document_folders(user_id);

-- Cada documento pasa a pertenecer (opcionalmente) a una carpeta.
-- Los documentos ya subidos antes de este cambio se quedan con folder_id = null
-- y aparecerán bajo la carpeta virtual "Sin carpeta" en la ficha del cliente.
alter table public.documents add column if not exists folder_id uuid references public.document_folders(id) on delete set null;

create index if not exists idx_documents_folder on public.documents(folder_id);
