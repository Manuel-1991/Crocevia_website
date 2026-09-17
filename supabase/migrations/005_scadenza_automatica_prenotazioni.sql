-- Scadenza automatica delle prenotazioni "in attesa di pagamento" mai
-- pagate: senza questo, una prenotazione abbandonata a metà pagamento
-- blocca un posto per sempre. Un job pg_cron le annulla dopo 30 minuti
-- (poi ridotti a 15, vedi 007_scadenza_15_minuti.sql).
-- Già applicata al progetto live.

create extension if not exists pg_cron;

create or replace function scade_prenotazioni_non_pagate()
returns void language plpgsql set search_path = public, pg_temp as $$
begin
  with scadute as (
    update prenotazioni
    set stato = 'annullata'
    where stato = 'in_attesa_pagamento'
      and creato_il < now() - interval '30 minutes'
    returning id
  )
  update pagamenti set stato = 'fallito'
  where stato = 'in_attesa' and prenotazione_id in (select id from scadute);
end;
$$;

select cron.schedule(
  'scadenza-prenotazioni-non-pagate',
  '*/10 * * * *',
  $$select scade_prenotazioni_non_pagate();$$
);
