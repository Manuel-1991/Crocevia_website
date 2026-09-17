-- Crocevia — capienza pensione/asilo: da "un cane alla volta" a "5 cani al
-- giorno" (capienza condivisa tra pensione e asilo, stesso spazio).
-- Da eseguire una volta in Dashboard Supabase → SQL Editor, DOPO schema.sql
-- e seed-servizi.sql. Non serve rieseguire schema.sql: questo file porta
-- da solo il database già creato allo stato aggiornato.

-- 1) toglie il vecchio vincolo "zero sovrapposizioni" (capacità 1): era
--    l'unico dei due vincoli di esclusione a non citare animale_id.
do $$
declare
  nome_vincolo text;
begin
  select conname into nome_vincolo
  from pg_constraint
  where conrelid = 'prenotazioni'::regclass
    and contype = 'x'
    and pg_get_constraintdef(oid) not like '%animale_id%';

  if nome_vincolo is not null then
    execute format('alter table prenotazioni drop constraint %I', nome_vincolo);
  end if;
end $$;

-- 2) ridefinisce la vista PRIMA di toccare la colonna "categoria": legge da
--    servizi, non dipende più dalla colonna che stiamo per togliere.
create or replace view disponibilita_pensione_asilo as
  select s.categoria, p.data_dal, p.data_al
  from prenotazioni p
  join servizi s on s.id = p.servizio_id
  where p.stato in ('in_attesa_pagamento','confermata')
    and s.categoria in ('pensione','asilo');

-- 3) la colonna categoria e il trigger che la copiava non servono più: la
--    capienza si controlla interrogando "servizi" direttamente, sempre
--    aggiornata per costruzione, senza bisogno di una copia sulla riga.
drop trigger if exists trg_imposta_categoria on prenotazioni;
drop function if exists imposta_categoria_prenotazione();
alter table prenotazioni drop column if exists categoria;

-- 4) capienza massima condivisa pensione+asilo: un solo punto da cambiare
--    in futuro se cambia lo spazio disponibile.
create or replace function capienza_pensione_asilo()
returns int language sql immutable as $$ select 5 $$;

-- 5) controlla, ad ogni inserimento/modifica, che nessun giorno del
--    soggiorno richiesto superi la capienza massima.
create or replace function controlla_capienza_pensione_asilo()
returns trigger language plpgsql as $$
declare
  categoria_riga text;
  giorno date;
  occupati int;
begin
  if new.stato not in ('in_attesa_pagamento','confermata') then
    return new;
  end if;

  select categoria into categoria_riga from servizi where id = new.servizio_id;
  if categoria_riga is null or categoria_riga not in ('pensione','asilo') then
    return new;
  end if;

  for giorno in select generate_series(new.data_dal, new.data_al, interval '1 day')::date loop
    select count(*) into occupati
    from prenotazioni p
    join servizi s on s.id = p.servizio_id
    where p.id <> new.id
      and s.categoria in ('pensione','asilo')
      and p.stato in ('in_attesa_pagamento','confermata')
      and daterange(p.data_dal, p.data_al, '[]') @> giorno;

    if occupati >= capienza_pensione_asilo() then
      raise exception 'Il % è già al completo (% cani)', giorno, capienza_pensione_asilo();
    end if;
  end loop;

  return new;
end;
$$;

drop trigger if exists trg_verifica_capienza on prenotazioni;
create trigger trg_verifica_capienza
  before insert or update of data_dal, data_al, stato, servizio_id on prenotazioni
  for each row execute function controlla_capienza_pensione_asilo();
