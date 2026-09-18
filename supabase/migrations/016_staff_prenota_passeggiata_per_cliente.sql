-- Permette a addetto/admin di creare un'iscrizione a una passeggiata per
-- conto di un cliente già registrato (chi telefona invece di usare il
-- sito), stesso schema di 006_staff_puo_creare_prenotazioni_manuali.sql
-- per pensione/asilo: le policy INSERT restano in OR con quelle esistenti
-- del cliente, non le sostituiscono.
--
-- Il requisito del telefono (015_chiude_buchi_passeggiate.sql) resta
-- valido anche per questa via: lo staff non può creare un'iscrizione per
-- un cliente che non ha ancora un numero salvato in profilo. Il pannello
-- staff controlla la stessa cosa prima di mostrare il modulo, ma la
-- verifica vera è qui.
--
-- Stessa cosa per i cani: lo staff può aggiungere alla prenotazione solo
-- cani che risultano del cliente proprietario dell'iscrizione (mai cani
-- di qualcun altro, anche per errore).

drop policy if exists iscrizioni_passeggiata_insert_staff on iscrizioni_passeggiata;
create policy iscrizioni_passeggiata_insert_staff on iscrizioni_passeggiata for insert
  with check (
    ruolo_utente_corrente() in ('addetto','admin')
    and stato = 'confermata'
    and exists (
      select 1 from profili p
      where p.id = cliente_id and coalesce(p.telefono, '') <> ''
    )
  );

drop policy if exists iscrizione_animali_insert_staff on iscrizione_passeggiata_animali;
create policy iscrizione_animali_insert_staff on iscrizione_passeggiata_animali for insert
  with check (
    ruolo_utente_corrente() in ('addetto','admin')
    and exists (
      select 1 from iscrizioni_passeggiata i
      join animali a on a.proprietario_id = i.cliente_id
      where i.id = iscrizione_id and a.id = animale_id
    )
  );
