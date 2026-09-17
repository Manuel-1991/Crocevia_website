-- Crea un evento su Google Calendar ogni volta che una prenotazione
-- diventa "confermata" (pagamento online, conferma manuale dello staff, o
-- prenotazione manuale con "acconto già ricevuto"). Il trigger chiama la
-- Edge Function crea-evento-calendario tramite pg_net, autenticata con un
-- segreto condiviso salvato in Vault (mai leggibile via query normale).
-- Già applicata al progetto live.

alter table prenotazioni
  add column if not exists salta_calendario boolean not null default false,
  add column if not exists evento_calendario_id text;

create extension if not exists pg_net;

-- NOTA: vault.create_secret va eseguito una sola volta. Se questo file
-- viene rieseguito su un database dove il segreto esiste già, commentare
-- la riga sotto per evitare un secondo segreto con lo stesso nome.
select vault.create_secret(
  encode(gen_random_bytes(32), 'hex'),
  'internal_webhook_secret',
  'Autentica le chiamate da trigger Postgres a Edge Function'
);

create or replace function notifica_prenotazione_confermata()
returns trigger
language plpgsql
set search_path = public, pg_temp, extensions
as $$
declare
  segreto text;
begin
  if new.stato = 'confermata'
     and not new.salta_calendario
     and new.evento_calendario_id is null
     and (tg_op = 'INSERT' or old.stato is distinct from 'confermata') then

    select decrypted_secret into segreto
    from vault.decrypted_secrets
    where name = 'internal_webhook_secret';

    perform net.http_post(
      url := 'https://gcjxhgvghncjjvcnacbv.supabase.co/functions/v1/crea-evento-calendario',
      headers := jsonb_build_object('Content-Type', 'application/json', 'x-internal-secret', segreto),
      body := jsonb_build_object('prenotazione_id', new.id)
    );
  end if;
  return new;
end;
$$;

drop trigger if exists trg_notifica_prenotazione_confermata on prenotazioni;
create trigger trg_notifica_prenotazione_confermata
  after insert or update of stato on prenotazioni
  for each row execute function notifica_prenotazione_confermata();
