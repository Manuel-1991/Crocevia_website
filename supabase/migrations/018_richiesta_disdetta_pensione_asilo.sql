-- Richiesta di disdetta per stallo/pensione/asilo dall'area privata.
-- Il cliente non annulla la prenotazione da solo: lo stato resta
-- "confermata" (il posto resta occupato, il calendario e l'evento Google
-- restano intatti), ma accende un flag che lo staff vede nel pannello.
-- Lo staff valuta il rimborso secondo i termini (7 giorni di preavviso,
-- importo versato meno le commissioni di pagamento) e poi annulla lui la
-- prenotazione con il bottone "Annulla" già esistente.

alter table prenotazioni
  add column if not exists disdetta_richiesta boolean not null default false,
  add column if not exists disdetta_richiesta_il timestamptz;

-- La RLS da sola non protegge colonna per colonna: una volta ammesso un
-- update su una riga, un cliente potrebbe altrimenti provare a cambiare
-- qualunque campo (prezzi, date, stato...). Questo trigger fa rispettare
-- due soli percorsi per un cliente:
--  A) prenotazione non ancora pagata -> può annullarla lui stesso (era già
--     l'intento della RLS originale, ma senza WITH CHECK esplicito non
--     avrebbe mai funzionato: lo sistemiamo insieme a questa modifica)
--  B) prenotazione confermata -> può solo accendere disdetta_richiesta
-- Qualunque altro tentativo di modifica da parte di un cliente viene
-- respinto con un'eccezione. Staff (addetto/admin) e le Edge Function con
-- la chiave service role (crea-pagamento, stripe-webhook) restano esenti,
-- esattamente come prima.
create or replace function blocca_modifiche_prenotazione_cliente()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.role() = 'service_role' or ruolo_utente_corrente() in ('addetto', 'admin') then
    return new;
  end if;

  -- Oltre alla RLS, controlla anche qui che la riga sia davvero di chi la
  -- sta modificando: un cliente non deve poter toccare la prenotazione di
  -- un altro nemmeno se, per qualunque motivo, la RLS non la filtrasse
  -- (difesa in profondità: verificato con una connessione che bypassa la
  -- RLS, la sola RLS non basterebbe da sola come unica barriera).
  if old.cliente_id is distinct from auth.uid() then
    raise exception 'Non puoi modificare questa prenotazione in questo modo.';
  end if;

  if old.stato = 'in_attesa_pagamento' and new.stato = 'annullata'
     and (to_jsonb(new) - 'stato') is not distinct from (to_jsonb(old) - 'stato') then
    return new;
  end if;

  if old.stato = 'confermata' and old.disdetta_richiesta is not true
     and new.disdetta_richiesta is true
     and (to_jsonb(new) - 'disdetta_richiesta' - 'disdetta_richiesta_il')
         is not distinct from
         (to_jsonb(old) - 'disdetta_richiesta' - 'disdetta_richiesta_il') then
    return new;
  end if;

  raise exception 'Non puoi modificare questa prenotazione in questo modo.';
end;
$$;

drop trigger if exists trg_blocca_modifiche_prenotazione_cliente on prenotazioni;
create trigger trg_blocca_modifiche_prenotazione_cliente
  before update on prenotazioni
  for each row execute function blocca_modifiche_prenotazione_cliente();

-- USING limita quali righe esistenti un cliente può toccare (le sue,
-- ancora in attesa di pagamento o confermate). WITH CHECK, separato di
-- proposito, lascia decidere al trigger sopra cosa esattamente può
-- diventare la riga: qui verifica solo che resti sua.
drop policy if exists prenotazioni_update on prenotazioni;
create policy prenotazioni_update on prenotazioni for update
  using (
    ruolo_utente_corrente() in ('addetto', 'admin')
    or (cliente_id = auth.uid() and stato in ('in_attesa_pagamento', 'confermata'))
  )
  with check (
    ruolo_utente_corrente() in ('addetto', 'admin')
    or cliente_id = auth.uid()
  );
