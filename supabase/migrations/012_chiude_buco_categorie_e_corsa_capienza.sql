-- BUCO 1 (critico, verificato con un tentativo reale): un client poteva
-- creare una prenotazione per un servizio di educazione/passeggiate —
-- categoria che il trigger degli importi ignorava completamente,
-- lasciando passare qualunque prezzo/acconto inventato dal client (0,01€
-- accettati senza correzione). Due difese indipendenti:
--
-- 1a) RLS: il cliente può creare una prenotazione solo per un servizio
--     di categoria pensione/asilo (le uniche vendute online oggi).
--     Verificato con una vera richiesta HTTP autenticata: 403, bloccata.
-- 1b) Difesa in profondità nel trigger: se una riga con altra categoria
--     arrivasse comunque, gli importi vengono azzerati invece di restare
--     quelli del client. Verificato: 999,99€ dichiarati, salvati come 0.
--     Da rivedere se in futuro si vende online anche educazione/passeggiate.
--
-- BUCO 2 (teorico, bassa probabilità a questa scala, non misurato sotto
-- carico): il controllo di capienza contava le prenotazioni esistenti e
-- poi decideva se accettarne una nuova — due richieste simultanee
-- sull'ultimo posto avrebbero potuto non vedersi a vicenda ed entrare
-- entrambe (finestra di corsa tipica di un conteggio sotto READ
-- COMMITTED). Un lock sulla tabella durante il controllo serializza le
-- scritture (le letture normali del sito non ne risentono) e chiude la
-- finestra.
--
-- Già applicata al progetto live.

drop policy if exists prenotazioni_insert on prenotazioni;
create policy prenotazioni_insert on prenotazioni for insert
  with check (
    cliente_id = auth.uid()
    and stato = 'in_attesa_pagamento'
    and exists (select 1 from animali a where a.id = animale_id and a.proprietario_id = auth.uid())
    and exists (select 1 from servizi s where s.id = servizio_id and s.categoria in ('pensione','asilo'))
  );

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
  else
    new.pappa_importo := 0;
    new.prezzo_totale := 0;
    new.acconto_importo := 0;
    new.saldo_importo := 0;
  end if;

  return new;
end;
$$;

create or replace function controlla_capienza_pensione_asilo()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
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

  lock table prenotazioni in share row exclusive mode;

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
