-- CRITICO: gli importi (prezzo_totale, acconto_importo, saldo_importo)
-- venivano accettati così come li mandava il client, senza nessuna
-- verifica server-side — solo il JavaScript del browser li calcolava.
-- Chiunque avesse modificato la richiesta (o scritto due righe di script,
-- o aggiornato una propria prenotazione ancora "in attesa" prima di
-- pagarla) poteva dichiarare un acconto di pochi centesimi per un
-- soggiorno di 30 notti e pagarlo davvero.
--
-- Questo trigger ricalcola sempre lui gli importi da servizi.prezzo e
-- dalle date, su ogni insert e ogni update (non solo quando cambiano le
-- date): qualunque valore arrivi dal client per questi tre campi viene
-- ignorato e sovrascritto. Verificato con un tentativo di attacco reale
-- (30 notti dichiarate a 0,01 € invece di 840 €), corretto in automatico.
-- Già applicata al progetto live.

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
    new.prezzo_totale := round(notti * prezzo_notte * moltiplicatore, 2);
    new.acconto_importo := round(new.prezzo_totale * 0.10, 2);
    new.saldo_importo := new.prezzo_totale - new.acconto_importo;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_calcola_importi on prenotazioni;
create trigger trg_calcola_importi
  before insert or update on prenotazioni
  for each row execute function calcola_importi_prenotazione();
