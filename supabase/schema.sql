-- ================================================================
-- 4D SISTEMI INFORMATICI — Schema database
-- Esegui questo file nel Supabase SQL Editor
-- ================================================================

-- TABELLA PROFILI UTENTE
create table if not exists public.profiles (
  id uuid references auth.users(id) on delete cascade primary key,
  email text not null unique,
  full_name text not null default '',
  role text not null default 'contributor'
    check (role in ('viewer', 'contributor', 'admin')),
  created_at timestamptz default now()
);

-- TABELLA CELLE DELLA MATRICE
create table if not exists public.matrix_cells (
  id text primary key,                          -- es: 'sec-0', 'con-2'
  sector_id text not null,                      -- sec | con | wor | inf | man
  activity_index integer not null,              -- 0..4
  coverage text not null default 'gap'
    check (coverage in ('full', 'partial', 'gap')),
  label text not null,
  items jsonb not null default '[]'::jsonb,
  updated_at timestamptz default now(),
  updated_by uuid references public.profiles(id)
);

-- TABELLA SUGGERIMENTI
create table if not exists public.suggestions (
  id uuid default gen_random_uuid() primary key,
  cell_id text not null references public.matrix_cells(id) on delete cascade,
  suggested_by uuid not null references public.profiles(id) on delete cascade,
  suggestion_type text not null
    check (suggestion_type in ('add_item', 'change_coverage', 'change_label', 'general_note')),
  content jsonb not null default '{}'::jsonb,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  review_note text,
  reviewed_by uuid references public.profiles(id),
  reviewed_at timestamptz,
  created_at timestamptz default now()
);

-- ================================================================
-- ROW LEVEL SECURITY
-- ================================================================
alter table public.profiles enable row level security;
alter table public.matrix_cells enable row level security;
alter table public.suggestions enable row level security;

-- PROFILES
create policy "Utenti autenticati vedono tutti i profili"
  on public.profiles for select
  using (auth.role() = 'authenticated');

create policy "Utenti possono inserire il proprio profilo"
  on public.profiles for insert
  with check (auth.uid() = id);

create policy "Utenti possono aggiornare il proprio profilo"
  on public.profiles for update
  using (auth.uid() = id);

create policy "Solo admin può cambiare i ruoli"
  on public.profiles for update
  using (
    auth.uid() = id or
    exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  );

-- MATRIX_CELLS
create policy "Utenti autenticati vedono tutte le celle"
  on public.matrix_cells for select
  using (auth.role() = 'authenticated');

create policy "Solo admin può modificare le celle"
  on public.matrix_cells for update
  using (
    exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  );

create policy "Solo admin può inserire celle"
  on public.matrix_cells for insert
  with check (
    exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  );

-- SUGGESTIONS
create policy "Utenti vedono i propri suggerimenti, admin vede tutto"
  on public.suggestions for select
  using (
    suggested_by = auth.uid() or
    exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  );

create policy "Contributor e admin possono inviare suggerimenti"
  on public.suggestions for insert
  with check (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role in ('contributor', 'admin')
    )
  );

create policy "Solo admin può aggiornare i suggerimenti"
  on public.suggestions for update
  using (
    exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  );

-- ================================================================
-- TRIGGER: crea profilo automaticamente alla registrazione
-- ================================================================
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, email, full_name)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name', '')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
