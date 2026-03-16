-- ================================================================
-- 4D SISTEMI — Audit Log v2: diff per campo + rollback
-- Esegui nel Supabase SQL Editor
-- ================================================================

-- ── 1. AGGIORNA TRIGGER matrix_cells ─────────────────────────────
-- Salva ogni campo modificato con valore precedente e nuovo

create or replace function public.trg_audit_matrix_cells()
returns trigger
language plpgsql
security definer
as $$
declare
  v_email  text;
  v_diff   jsonb := '[]'::jsonb;
begin
  if TG_OP = 'UPDATE' then
    select email into v_email from public.profiles where id = NEW.updated_by;

    -- Confronta campo per campo e registra solo quelli cambiati
    if OLD.label != NEW.label then
      v_diff := v_diff || jsonb_build_array(jsonb_build_object(
        'field', 'label',
        'old',   OLD.label,
        'new',   NEW.label
      ));
    end if;

    if OLD.coverage != NEW.coverage then
      v_diff := v_diff || jsonb_build_array(jsonb_build_object(
        'field', 'coverage',
        'old',   OLD.coverage,
        'new',   NEW.coverage
      ));
    end if;

    if OLD.items::text != NEW.items::text then
      v_diff := v_diff || jsonb_build_array(jsonb_build_object(
        'field', 'items',
        'old',   OLD.items,
        'new',   NEW.items
      ));
    end if;

    -- Registra solo se c'è almeno un campo cambiato
    if jsonb_array_length(v_diff) > 0 then
      insert into public.audit_log (actor_id, actor_email, action, target_type, target_id, detail)
      values (
        NEW.updated_by,
        v_email,
        'cell_updated',
        'matrix_cell',
        NEW.id,
        jsonb_build_object(
          'cell_id',    NEW.id,
          'diff',       v_diff,
          -- Snapshot completo per poter fare rollback
          'snapshot_before', jsonb_build_object(
            'label',    OLD.label,
            'coverage', OLD.coverage,
            'items',    OLD.items
          ),
          'snapshot_after', jsonb_build_object(
            'label',    NEW.label,
            'coverage', NEW.coverage,
            'items',    NEW.items
          )
        )
      );
    end if;
  end if;
  return NEW;
end;
$$;

drop trigger if exists audit_matrix_cells on public.matrix_cells;
create trigger audit_matrix_cells
  after update on public.matrix_cells
  for each row execute procedure public.trg_audit_matrix_cells();


-- ── 2. AGGIORNA TRIGGER suggestions ──────────────────────────────

create or replace function public.trg_audit_suggestions()
returns trigger
language plpgsql
security definer
as $$
declare
  v_diff jsonb := '[]'::jsonb;
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

  elsif TG_OP = 'UPDATE' and OLD.status = 'pending' and NEW.status != 'pending' then

    v_diff := jsonb_build_array(jsonb_build_object(
      'field', 'status',
      'old',   OLD.status,
      'new',   NEW.status
    ));
    if OLD.review_note is distinct from NEW.review_note then
      v_diff := v_diff || jsonb_build_array(jsonb_build_object(
        'field', 'review_note',
        'old',   OLD.review_note,
        'new',   NEW.review_note
      ));
    end if;

    insert into public.audit_log (actor_id, actor_email, action, target_type, target_id, detail)
    select
      NEW.reviewed_by,
      p.email,
      case when NEW.status = 'approved' then 'suggestion_approved' else 'suggestion_rejected' end,
      'suggestion',
      NEW.id::text,
      jsonb_build_object(
        'cell_id',         NEW.cell_id,
        'suggestion_type', NEW.suggestion_type,
        'diff',            v_diff,
        'snapshot_before', jsonb_build_object('status', OLD.status, 'review_note', OLD.review_note),
        'snapshot_after',  jsonb_build_object('status', NEW.status, 'review_note', NEW.review_note),
        'submitted_by',    NEW.suggested_by
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


-- ── 3. AGGIORNA TRIGGER profiles ─────────────────────────────────

create or replace function public.trg_audit_profiles()
returns trigger
language plpgsql
security definer
as $$
declare
  v_diff jsonb := '[]'::jsonb;
begin
  if TG_OP = 'UPDATE' then
    if OLD.role != NEW.role then
      v_diff := v_diff || jsonb_build_array(jsonb_build_object(
        'field', 'role',
        'old',   OLD.role,
        'new',   NEW.role
      ));
    end if;
    if OLD.full_name is distinct from NEW.full_name then
      v_diff := v_diff || jsonb_build_array(jsonb_build_object(
        'field', 'full_name',
        'old',   OLD.full_name,
        'new',   NEW.full_name
      ));
    end if;

    if jsonb_array_length(v_diff) > 0 then
      insert into public.audit_log (actor_id, actor_email, action, target_type, target_id, detail)
      values (
        auth.uid(),
        NEW.email,
        'role_changed',
        'profile',
        NEW.id::text,
        jsonb_build_object(
          'user_email',      NEW.email,
          'diff',            v_diff,
          'snapshot_before', jsonb_build_object('role', OLD.role, 'full_name', OLD.full_name),
          'snapshot_after',  jsonb_build_object('role', NEW.role, 'full_name', NEW.full_name)
        )
      );
    end if;
  end if;
  return NEW;
end;
$$;

drop trigger if exists audit_profiles on public.profiles;
create trigger audit_profiles
  after update on public.profiles
  for each row execute procedure public.trg_audit_profiles();


-- ── 4. FUNZIONE ROLLBACK ──────────────────────────────────────────
-- Ripristina un singolo campo al valore precedente e logga l'operazione.
-- Può essere chiamata solo da un admin (verificato a livello applicativo).

create or replace function public.rollback_audit_entry(
  p_log_id     bigint,   -- ID della riga in audit_log da annullare
  p_field      text,     -- Campo da ripristinare (es. 'coverage', 'label', 'items', 'role')
  p_actor_id   uuid      -- Chi sta eseguendo il rollback (deve essere admin)
)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_entry       public.audit_log%rowtype;
  v_actor_role  text;
  v_old_val     jsonb;
  v_new_val     jsonb;
  v_diff_item   jsonb;
  v_actor_email text;
  v_result      jsonb;
begin
  -- Verifica che l'attore sia admin
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

  -- Estrai il valore vecchio e nuovo per il campo richiesto dal diff
  select elem into v_diff_item
  from jsonb_array_elements(v_entry.detail->'diff') as elem
  where elem->>'field' = p_field
  limit 1;

  if v_diff_item is null then
    return jsonb_build_object('ok', false, 'error', 'Campo ' || p_field || ' non trovato in questo log.');
  end if;

  v_old_val := v_diff_item->'old';
  v_new_val := v_diff_item->'new';

  -- Esegui il ripristino in base al target_type
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
        return jsonb_build_object('ok', false, 'error', 'Campo non supportato per rollback su matrix_cell.');
    end case;

  elsif v_entry.target_type = 'profile' then
    case p_field
      when 'role' then
        update public.profiles
        set role = v_old_val #>> '{}'
        where id = v_entry.target_id::uuid;
      else
        return jsonb_build_object('ok', false, 'error', 'Campo non supportato per rollback su profile.');
    end case;

  else
    return jsonb_build_object('ok', false, 'error', 'Rollback non supportato per target_type: ' || v_entry.target_type);
  end if;

  -- Scrivi nel log il rollback stesso
  insert into public.audit_log (actor_id, actor_email, action, target_type, target_id, detail)
  values (
    p_actor_id,
    v_actor_email,
    'rollback',
    v_entry.target_type,
    v_entry.target_id,
    jsonb_build_object(
      'original_log_id', p_log_id,
      'field',           p_field,
      'restored_to',     v_old_val,
      'reverted_from',   v_new_val,
      'original_action', v_entry.action,
      'original_actor',  v_entry.actor_email
    )
  );

  return jsonb_build_object(
    'ok',      true,
    'field',   p_field,
    'old_val', v_old_val,
    'new_val', v_new_val
  );
end;
$$;
