-- Scadenza prenotazioni non pagate: da 30 a 15 minuti, controllo ogni 5
-- minuti invece di 10 (per restare proporzionati alla soglia più corta).
-- Già applicata al progetto live.

create or replace function scade_prenotazioni_non_pagate()
returns void language plpgsql set search_path = public, pg_temp as $$
begin
  with scadute as (
    update prenotazioni
    set stato = 'annullata'
    where stato = 'in_attesa_pagamento'
      and creato_il < now() - interval '15 minutes'
    returning id
  )
  update pagamenti set stato = 'fallito'
  where stato = 'in_attesa' and prenotazione_id in (select id from scadute);
end;
$$;

select cron.alter_job(
  (select jobid from cron.job where jobname = 'scadenza-prenotazioni-non-pagate'),
  schedule := '*/5 * * * *'
);
