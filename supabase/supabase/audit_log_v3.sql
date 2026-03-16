-- ================================================================
-- 4D SISTEMI — Audit Log v3: rollback su approvazione
-- Esegui nel Supabase SQL Editor
-- ================================================================

-- ── 1. AGGIUNGI STATO 'reverted' AI SUGGERIMENTI ─────────────────
-- Serve per marcare un suggerimento approvato e poi annullato

alter table public.suggestions
  drop constraint if exists suggestions_status_check;

alter table public.suggestions
  add constraint suggestions_status_check
  check (status in ('pending', 'approved', 'rejected', 'reverted'));


-- ── 2. AGGIORNA TRIGGER suggestions ──────────────────────────────
-- Quando un suggerimento viene approvato, salva lo snapshot
-- della cella PRIMA della modifica nel log dell'approvazione.

create or replace function public.trg_audit_suggestions()
returns trigger
language plpgsql
security definer
as $$
declare
  v_diff          jsonb := '[]'::jsonb;
  v_cell_before   jsonb := null;
begin

  -- ── INSERT: nuovo suggerimento ──────────────────────────────────
  if TG_OP = 'INSERT' then
    insert into public.audit_log (actor_id, actor_email, action, target_type, target_id, detail)
    select
      NEW.suggested_by,
      p.email,
      'suggestion_submitted',
      'suggestion',
      NEW.id::text,
      jsonb_build_object(
        'cell_id',         NEW.cell_id,
        'suggestion_type', NEW.suggestion_type,
        'diff', jsonb_build_array(jsonb_build_object(
          'field', 'content',
          'old',   null,
          'new',   NEW.content
        )),
        'snapshot_before', null,
        'snapshot_after',  NEW.content
      )
    from public.profiles p where p.id = NEW.suggested_by;

  -- ── UPDATE: approvazione o rifiuto ─────────────────────────────
  elsif TG_OP = 'UPDATE' and OLD.status = 'pending' and NEW.status in ('approved','rejected') then

    v_diff := jsonb_build_array(jsonb_build_object(
      'field', 'status',
      'old',   OLD.status,
      'new',   NEW.status
    ));

    -- Se approvato, cattura lo snapshot attuale della cella
    -- (in questo momento il trigger di matrix_cells non ha ancora agito,
    --  quindi questa è ancora la versione PRIMA della modifica)
    if NEW.status = 'approved' then
      select jsonb_build_object(
        'label',    mc.label,
        'coverage', mc.coverage,
        'items',    mc.items
      )
      into v_cell_before
      from public.matrix_cells mc
      where mc.id = NEW.cell_id;
    end if;

    insert into public.audit_log (actor_id, actor_email, action, target_type, target_id, detail)
    select
      NEW.reviewed_by,
      p.email,
      case when NEW.status = 'approved' then 'suggestion_approved' else 'suggestion_rejected' end,
      'suggestion',
      NEW.id::text,
      jsonb_build_object(
        'cell_id',              NEW.cell_id,
        'suggestion_type',      NEW.suggestion_type,
        'suggestion_content',   NEW.content,
        'diff',                 v_diff,
        'cell_snapshot_before', v_cell_before,   -- snapshot cella prima dell'approvazione
        'review_note',          NEW.review_note,
        'submitted_by',         NEW.suggested_by
      )
    from public.profiles p where p.id = NEW.reviewed_by;

  -- ── UPDATE: annullamento approvazione (reverted) ────────────────
  elsif TG_OP = 'UPDATE' and OLD.status = 'approved' and NEW.status = 'reverted' then

    insert into public.audit_log (actor_id, actor_email, action, target_type, target_id, detail)
    select
      NEW.reviewed_by,
      p.email,
      'suggestion_reverted',
      'suggestion',
      NEW.id::text,
      jsonb_build_object(
        'cell_id',         NEW.cell_id,
        'suggestion_type', NEW.suggestion_type,
        'review_note',     NEW.review_note
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


-- ── 3. FUNZIONE ROLLBACK AGGIORNATA ──────────────────────────────

create or replace function public.rollback_audit_entry(
  p_log_id     bigint,
  p_field      text,
  p_actor_id   uuid
)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_entry        public.audit_log%rowtype;
  v_actor_role   text;
  v_actor_email  text;
  v_old_val      jsonb;
  v_new_val      jsonb;
  v_diff_item    jsonb;
  v_cell_before  jsonb;
begin
  -- Verifica admin
  select role, email into v_actor_role, v_actor_email
  from public.profiles where id = p_actor_id;

  if v_actor_role != 'admin' then
    return jsonb_build_object('ok', false, 'error', 'Solo gli admin possono eseguire un rollback.');
  end if;

  -- Recupera la riga del log
  select * into v_entry from public.audit_log where id = p_log_id;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'Voce di log non trovata.');
  end if;

  -- ── CASO A: rollback su cell_updated o role_changed ─────────────
  if v_entry.action in ('cell_updated', 'role_changed') then

    select elem into v_diff_item
    from jsonb_array_elements(v_entry.detail->'diff') as elem
    where elem->>'field' = p_field
    limit 1;

    if v_diff_item is null then
      return jsonb_build_object('ok', false, 'error', 'Campo ' || p_field || ' non trovato nel log.');
    end if;

    v_old_val := v_diff_item->'old';
    v_new_val := v_diff_item->'new';

    if v_entry.target_type = 'matrix_cell' then
      case p_field
        when 'label' then
          update public.matrix_cells
          set label = v_old_val #>> '{}', updated_at = now(), updated_by = p_actor_id
          where id = v_entry.target_id;
        when 'coverage' then
          update public.matrix_cells
          set coverage = v_old_val #>> '{}', updated_at = now(), updated_by = p_actor_id
          where id = v_entry.target_id;
        when 'items' then
          update public.matrix_cells
          set items = v_old_val, updated_at = now(), updated_by = p_actor_id
          where id = v_entry.target_id;
        else
          return jsonb_build_object('ok', false, 'error', 'Campo non supportato: ' || p_field);
      end case;

    elsif v_entry.target_type = 'profile' then
      if p_field = 'role' then
        update public.profiles
        set role = v_old_val #>> '{}'
        where id = v_entry.target_id::uuid;
      else
        return jsonb_build_object('ok', false, 'error', 'Campo non supportato: ' || p_field);
      end if;
    end if;

  -- ── CASO B: rollback su suggestion_approved ──────────────────────
  elsif v_entry.action = 'suggestion_approved' then

    v_cell_before := v_entry.detail->'cell_snapshot_before';

    if v_cell_before is null then
      return jsonb_build_object('ok', false,
        'error', 'Snapshot della cella non disponibile. Questo suggerimento è stato approvato prima dell''aggiornamento al log v3.');
    end if;

    -- Ripristina la cella intera allo stato precedente all'approvazione
    update public.matrix_cells
    set
      label      = v_cell_before->>'label',
      coverage   = v_cell_before->>'coverage',
      items      = v_cell_before->'items',
      updated_at = now(),
      updated_by = p_actor_id
    where id = v_entry.detail->>'cell_id';

    -- Segna il suggerimento come 'reverted'
    update public.suggestions
    set
      status      = 'reverted',
      reviewed_by = p_actor_id,
      review_note = coalesce(review_note, '') || ' [rollback eseguito da ' || v_actor_email || ']',
      reviewed_at = now()
    where id = v_entry.target_id::uuid;

    v_old_val := v_cell_before;
    v_new_val := null;

  else
    return jsonb_build_object('ok', false,
      'error', 'Rollback non supportato per azione: ' || v_entry.action);
  end if;

  -- Scrivi il rollback nel log
  insert into public.audit_log (actor_id, actor_email, action, target_type, target_id, detail)
  values (
    p_actor_id,
    v_actor_email,
    'rollback',
    v_entry.target_type,
    v_entry.target_id,
    jsonb_build_object(
      'original_log_id', p_log_id,
      'original_action', v_entry.action,
      'original_actor',  v_entry.actor_email,
      'field',           p_field,
      'restored_to',     v_old_val,
      'reverted_from',   v_new_val
    )
  );

  return jsonb_build_object('ok', true, 'field', p_field, 'old_val', v_old_val);
end;
$$;
