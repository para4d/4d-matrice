-- ================================================================
-- 4D SISTEMI INFORMATICI — Audit Log
-- Esegui questo file nel Supabase SQL Editor DOPO schema.sql
-- ================================================================

-- ── 1. TABELLA AUDIT LOG ─────────────────────────────────────────
create table if not exists public.audit_log (
  id           bigserial primary key,
  ts           timestamptz default now(),
  actor_id     uuid references public.profiles(id) on delete set null,
  actor_email  text,
  action       text not null,        -- 'cell_updated' | 'suggestion_submitted' | 'suggestion_approved' | 'suggestion_rejected' | 'role_changed' | 'user_login'
  target_type  text,                 -- 'matrix_cell' | 'suggestion' | 'profile'
  target_id    text,
  detail       jsonb default '{}'::jsonb
);

-- Indice per query veloci per data
create index if not exists audit_log_ts_idx on public.audit_log(ts desc);

-- RLS: solo admin può leggere il log
alter table public.audit_log enable row level security;

create policy "Solo admin legge il log"
  on public.audit_log for select
  using (
    exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  );

create policy "Il sistema può scrivere nel log"
  on public.audit_log for insert
  with check (true);


-- ── 2. FUNZIONE DI SCRITTURA LOG ─────────────────────────────────
create or replace function public.write_audit_log(
  p_actor_id    uuid,
  p_action      text,
  p_target_type text,
  p_target_id   text,
  p_detail      jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
as $$
declare
  v_email text;
begin
  select email into v_email from public.profiles where id = p_actor_id;
  insert into public.audit_log (actor_id, actor_email, action, target_type, target_id, detail)
  values (p_actor_id, v_email, p_action, p_target_type, p_target_id, p_detail);
end;
$$;


-- ── 3. TRIGGER: modifica a matrix_cells ──────────────────────────
create or replace function public.trg_audit_matrix_cells()
returns trigger
language plpgsql
security definer
as $$
begin
  if TG_OP = 'UPDATE' then
    insert into public.audit_log (actor_id, actor_email, action, target_type, target_id, detail)
    select
      NEW.updated_by,
      p.email,
      'cell_updated',
      'matrix_cell',
      NEW.id,
      jsonb_build_object(
        'cell_id',       NEW.id,
        'label',         NEW.label,
        'coverage_old',  OLD.coverage,
        'coverage_new',  NEW.coverage,
        'items_count',   jsonb_array_length(NEW.items)
      )
    from public.profiles p where p.id = NEW.updated_by;
  end if;
  return NEW;
end;
$$;

drop trigger if exists audit_matrix_cells on public.matrix_cells;
create trigger audit_matrix_cells
  after update on public.matrix_cells
  for each row execute procedure public.trg_audit_matrix_cells();


-- ── 4. TRIGGER: nuovo suggerimento ───────────────────────────────
create or replace function public.trg_audit_suggestions()
returns trigger
language plpgsql
security definer
as $$
begin
  if TG_OP = 'INSERT' then
    insert into public.audit_log (actor_id, actor_email, action, target_type, target_id, detail)
    select
      NEW.suggested_by,
      p.email,
      'suggestion_submitted',
      'suggestion',
      NEW.id::text,
      jsonb_build_object(
        'cell_id',          NEW.cell_id,
        'suggestion_type',  NEW.suggestion_type,
        'content',          NEW.content
      )
    from public.profiles p where p.id = NEW.suggested_by;

  elsif TG_OP = 'UPDATE' and OLD.status = 'pending' and NEW.status != 'pending' then
    insert into public.audit_log (actor_id, actor_email, action, target_type, target_id, detail)
    select
      NEW.reviewed_by,
      p.email,
      case when NEW.status = 'approved' then 'suggestion_approved' else 'suggestion_rejected' end,
      'suggestion',
      NEW.id::text,
      jsonb_build_object(
        'cell_id',          NEW.cell_id,
        'suggestion_type',  NEW.suggestion_type,
        'review_note',      NEW.review_note,
        'submitted_by',     NEW.suggested_by
      )
    from public.profiles p where p.id = NEW.reviewed_by;
  end if;
  return NEW;
end;
$$;

drop trigger if exists audit_suggestions on public.suggestions;
create trigger audit_suggestions
  after insert or update on public.suggestions
  for each row execute procedure public.trg_audit_suggestions();


-- ── 5. TRIGGER: cambio ruolo utente ──────────────────────────────
create or replace function public.trg_audit_profiles()
returns trigger
language plpgsql
security definer
as $$
begin
  if TG_OP = 'UPDATE' and OLD.role != NEW.role then
    insert into public.audit_log (actor_id, actor_email, action, target_type, target_id, detail)
    values (
      auth.uid(),
      NEW.email,
      'role_changed',
      'profile',
      NEW.id::text,
      jsonb_build_object(
        'user_email', NEW.email,
        'role_old',   OLD.role,
        'role_new',   NEW.role
      )
    );
  end if;
  return NEW;
end;
$$;

drop trigger if exists audit_profiles on public.profiles;
create trigger audit_profiles
  after update on public.profiles
  for each row execute procedure public.trg_audit_profiles();


-- ── 6. FUNZIONE: controlla dimensione log e notifica ─────────────
-- Richiede l'estensione pg_net (abilitata di default su Supabase)
create or replace function public.check_audit_log_size()
returns void
language plpgsql
security definer
as $$
declare
  v_size_bytes  bigint;
  v_size_mb     numeric;
  v_threshold   bigint := 50 * 1024 * 1024;  -- 50 MB in bytes
  v_edge_url    text;
  v_anon_key    text;
begin
  -- Calcola dimensione della tabella
  select pg_total_relation_size('public.audit_log') into v_size_bytes;
  v_size_mb := round(v_size_bytes::numeric / (1024*1024), 2);

  -- Se supera 50MB, chiama la Edge Function che manda l'email
  if v_size_bytes >= v_threshold then
    -- Recupera le variabili d'ambiente (impostale in Supabase → Settings → Vault)
    select decrypted_secret into v_edge_url
      from vault.decrypted_secrets where name = 'EDGE_NOTIFY_URL';
    select decrypted_secret into v_anon_key
      from vault.decrypted_secrets where name = 'SUPABASE_ANON_KEY';

    perform net.http_post(
      url     := v_edge_url,
      headers := jsonb_build_object(
        'Content-Type',  'application/json',
        'Authorization', 'Bearer ' || v_anon_key
      ),
      body    := jsonb_build_object(
        'size_mb',    v_size_mb,
        'size_bytes', v_size_bytes,
        'threshold',  '50 MB'
      )
    );
  end if;
end;
$$;


-- ── 7. SCHEDULAZIONE CON PG_CRON ─────────────────────────────────
-- Controlla la dimensione ogni giorno alle 08:00 (ora UTC)
-- Richiede: Supabase → Database → Extensions → abilitare "pg_cron"
select cron.schedule(
  'check-audit-log-size',
  '0 8 * * *',
  $$ select public.check_audit_log_size(); $$
);


-- ── 8. VISTA COMODA PER L'ADMIN ───────────────────────────────────
create or replace view public.audit_log_view as
select
  l.id,
  l.ts,
  l.actor_email,
  l.action,
  l.target_type,
  l.target_id,
  l.detail,
  pg_size_pretty(pg_total_relation_size('public.audit_log')) as log_size
from public.audit_log l
order by l.ts desc;


-- ── 9. FUNZIONE RPC: dimensione log in bytes (chiamata dal frontend) ──
create or replace function public.get_log_size()
returns bigint
language sql
security definer
as $$
  select pg_total_relation_size('public.audit_log');
$$;
