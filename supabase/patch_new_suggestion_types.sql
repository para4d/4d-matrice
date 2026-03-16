-- ================================================================
-- 4D SISTEMI — Patch: nuovi tipi di suggerimento
-- edit_item e delete_item
-- Esegui nel Supabase SQL Editor
-- ================================================================

-- ── 1. AGGIORNA IL VINCOLO SUI TIPI ──────────────────────────────

alter table public.suggestions
  drop constraint if exists suggestions_suggestion_type_check;

alter table public.suggestions
  add constraint suggestions_suggestion_type_check
  check (suggestion_type in (
    'add_item',
    'edit_item',
    'delete_item',
    'change_coverage',
    'change_label',
    'general_note'
  ));


-- ── 2. AGGIORNA ROLLBACK PER I NUOVI TIPI ────────────────────────
-- Il rollback di edit_item e delete_item ripristina l'array items intero

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
  select role, email into v_actor_role, v_actor_email
  from public.profiles where id = p_actor_id;

  if v_actor_role != 'admin' then
    return jsonb_build_object('ok', false, 'error', 'Solo gli admin possono eseguire un rollback.');
  end if;

  select * into v_entry from public.audit_log where id = p_log_id;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'Voce di log non trovata.');
  end if;

  -- ── CASO A: cell_updated / role_changed ─────────────────────────
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

  -- ── CASO B: suggestion_approved (qualsiasi tipo) ─────────────────
  elsif v_entry.action = 'suggestion_approved' then

    v_cell_before := v_entry.detail->'cell_snapshot_before';

    if v_cell_before is null then
      return jsonb_build_object('ok', false,
        'error', 'Snapshot non disponibile per questa approvazione.');
    end if;

    update public.matrix_cells
    set
      label      = v_cell_before->>'label',
      coverage   = v_cell_before->>'coverage',
      items      = v_cell_before->'items',
      updated_at = now(),
      updated_by = p_actor_id
    where id = v_entry.detail->>'cell_id';

    update public.suggestions
    set
      status      = 'reverted',
      reviewed_by = p_actor_id,
      review_note = coalesce(review_note, '') || ' [rollback da ' || v_actor_email || ']',
      reviewed_at = now()
    where id = v_entry.target_id::uuid;

    v_old_val := v_cell_before;
    v_new_val := null;

  else
    return jsonb_build_object('ok', false,
      'error', 'Rollback non supportato per: ' || v_entry.action);
  end if;

  -- Scrivi rollback nel log
  insert into public.audit_log (actor_id, actor_email, action, target_type, target_id, detail)
  values (
    p_actor_id, v_actor_email, 'rollback',
    v_entry.target_type, v_entry.target_id,
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
