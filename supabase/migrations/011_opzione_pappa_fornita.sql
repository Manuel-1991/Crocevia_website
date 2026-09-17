-- Opzione "pappa fornita": selezionabile in prenotazione, vale per
-- l'intero soggiorno (non giorno per giorno), +5€/notte. Esclusa dal
-- calcolo dell'acconto 10% (che resta solo sul soggiorno) e saldata per
-- intero alla fine insieme al resto del saldo.
-- Verificato con un caso reale (7 notti pensione + pappa): totale
-- 255,50 €, acconto 22,05 € (10% dei soli 220,50 € di soggiorno), saldo
-- 233,45 € (198,45 € residui + 35 € di pappa).
-- Già applicata al progetto live.

alter table prenotazioni
  add column if not exists pappa_fornita boolean not null default false,
  add column if not exists pappa_importo numeric(10,2) not null default 0;

create or replace function prezzo_pappa_giornaliera()
returns numeric language sql immutable set search_path = public, pg_temp as $$ select 5.00 $$;

create or replace function calcola_importi_prenotazione()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  categoria_riga text;
  prezzo_notte numeric;
  notti int;
  moltiplicatore numeric;
  prezzo_base numeric;
begin
  select categoria, prezzo into categoria_riga, prezzo_notte
  from servizi where id = new.servizio_id;

  if categoria_riga in ('pensione','asilo') then
    notti := (new.data_al - new.data_dal) + 1;
    moltiplicatore := case
      when notti >= 30 then 0.8
      when notti >= 7 then 0.9
      else 1
    end;
    prezzo_base := round(notti * prezzo_notte * moltiplicatore, 2);

    new.pappa_importo := case when new.pappa_fornita then round(notti * prezzo_pappa_giornaliera(), 2) else 0 end;
    new.acconto_importo := round(prezzo_base * 0.10, 2);
    new.prezzo_totale := prezzo_base + new.pappa_importo;
    new.saldo_importo := (prezzo_base - new.acconto_importo) + new.pappa_importo;
  end if;

  return new;
end;
$$;
