-- Tre buchi trovati rileggendo 013/014 con occhio critico, prima che il
-- sistema fosse davvero usato:
--
-- BUCO 1 (dati orfani): iscrizione_passeggiata_animali.animale_id era ON
-- DELETE CASCADE. Un cliente con un solo cane iscritto a una passeggiata
-- poteva eliminare quel cane dalla sua area privata: il cane spariva dal
-- profilo, ma l'iscrizione restava "confermata" con zero cani dentro,
-- occupando comunque un posto (e l'unico posto disponibile per quel
-- cliente, visto il vincolo di una sola iscrizione attiva). prenotazioni
-- non ha questo problema: animale_id lì non è a cascata, la cancellazione
-- del cane viene bloccata con un errore finché ci sono prenotazioni
-- collegate (l'area privata lo intercetta già, vedi eliminaAnimale). Stesso
-- trattamento qui, per coerenza.
--
-- BUCO 2 (requisito esplicito non applicato): "servono i numeri di
-- telefono per avvisare" in caso di maltempo, ma nulla obbligava ad
-- averne uno salvato prima di iscriversi — un cliente poteva registrarsi,
-- aggiungere un cane e prenotare una passeggiata senza mai passare dal
-- modulo profilo. Aggiunta la verifica lato RLS (oltre a quella lato
-- sito): senza telefono in profilo, l'iscrizione viene rifiutata.
--
-- BUCO 3 (finestra temporale): la vista passeggiate_disponibilita
-- filtrava solo per data (data >= oggi), non per orario: un'uscita di
-- oggi già iniziata restava prenotabile fino a mezzanotte. Aggiunto il
-- confronto sull'ora per le uscite di oggi.

-- BUCO 1
alter table iscrizione_passeggiata_animali
  drop constraint iscrizione_passeggiata_animali_animale_id_fkey;
alter table iscrizione_passeggiata_animali
  add constraint iscrizione_passeggiata_animali_animale_id_fkey
  foreign key (animale_id) references animali(id);

-- BUCO 2
drop policy if exists iscrizioni_passeggiata_insert on iscrizioni_passeggiata;
create policy iscrizioni_passeggiata_insert on iscrizioni_passeggiata for insert
  with check (
    cliente_id = auth.uid()
    and stato = 'confermata'
    and exists (
      select 1 from profili p
      where p.id = auth.uid() and coalesce(p.telefono, '') <> ''
    )
  );

-- BUCO 3
create or replace view passeggiate_disponibilita as
  select p.id, p.data, p.ora, p.argomento, p.luogo,
         capienza_passeggiata() - count(i.id) filter (where i.stato = 'confermata') as posti_liberi
  from passeggiate p
  left join iscrizioni_passeggiata i on i.passeggiata_id = p.id
  where p.stato = 'programmata'
    and (p.data > current_date or (p.data = current_date and p.ora > current_time))
  group by p.id
  order by p.data, p.ora;

comment on view passeggiate_disponibilita is
  'SECURITY DEFINER intenzionale: mostra i posti liberi aggregati delle prossime passeggiate (nessun dato personale) anche a chi non ha ancora un account, bypassando le RLS di iscrizioni_passeggiata che altrimenti nasconderebbero le iscrizioni altrui. Vedi anche disponibilita_pensione_asilo.';
