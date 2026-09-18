-- Passeggiate di gruppo diventano un servizio a sé, gestito come
-- pensione/asilo (account, prenotazione dal sito, gestione autonoma) invece
-- che via modulo WhatsApp come finora. Modello diverso da pensione/asilo:
-- non sono un intervallo di date ma uscite fisse — una riga per ogni
-- martedì programmato, con un argomento — a cui i clienti si iscrivono.
-- Niente pagamento online: si salda in loco, nessun anticipo richiesto.
--
-- Regole implementate qui:
--  - massimo 10 iscritti per uscita (si conta per persona, non per cane:
--    un iscritto può portare più cani nella stessa iscrizione);
--  - un cliente può avere una sola iscrizione attiva alla volta, su
--    qualunque uscita (indice unico parziale su cliente_id);
--  - se un'uscita viene annullata (es. maltempo) i suoi iscritti vengono
--    liberati in automatico, così possono iscriversi a quella successiva;
--  - il vecchio listino a pacchetto ('passeggiate' in servizi, 15€/uscita
--    venduto solo a voce via WhatsApp) va disattivato: da oggi il prezzo
--    e le regole sono quelli qui sotto, non più quelli del listino.
-- Già applicata al progetto live.

-- ============================================================
-- PASSEGGIATE (le uscite programmate: la gestisce lo staff)
-- ============================================================

create table if not exists passeggiate (
  id          uuid primary key default gen_random_uuid(),
  data        date not null,
  ora         time not null default '18:00',
  argomento   text not null,
  luogo       text not null default 'Bosco di Campagnola',
  stato       text not null default 'programmata'
              check (stato in ('programmata','annullata_meteo','svolta')),
  note        text,
  creato_il   timestamptz not null default now()
);

alter table passeggiate enable row level security;

-- calendario pubblico: niente dati personali in questa tabella, la vede
-- chiunque (anche prima di accedere, così la pagina di presentazione può
-- mostrare la prossima uscita in programma).
drop policy if exists passeggiate_select on passeggiate;
create policy passeggiate_select on passeggiate for select using (true);

drop policy if exists passeggiate_scrittura on passeggiate;
create policy passeggiate_scrittura on passeggiate for all
  using (ruolo_utente_corrente() in ('addetto','admin'))
  with check (ruolo_utente_corrente() in ('addetto','admin'));

-- ============================================================
-- ISCRIZIONI (una per cliente per uscita; al più una attiva per cliente)
-- ============================================================

create table if not exists iscrizioni_passeggiata (
  id              uuid primary key default gen_random_uuid(),
  passeggiata_id  uuid not null references passeggiate(id) on delete cascade,
  cliente_id      uuid not null references profili(id),
  stato           text not null default 'confermata' check (stato in ('confermata','annullata')),
  creato_il       timestamptz not null default now(),
  unique (passeggiata_id, cliente_id)
);

-- "ogni iscritto può effettuare una sola prenotazione": un solo record
-- 'confermata' per cliente in tutta la tabella, non solo per uscita.
create unique index if not exists un_iscrizione_attiva_per_cliente
  on iscrizioni_passeggiata (cliente_id) where (stato = 'confermata');

alter table iscrizioni_passeggiata enable row level security;

drop policy if exists iscrizioni_passeggiata_select on iscrizioni_passeggiata;
create policy iscrizioni_passeggiata_select on iscrizioni_passeggiata for select
  using (cliente_id = auth.uid() or ruolo_utente_corrente() in ('addetto','admin'));

drop policy if exists iscrizioni_passeggiata_insert on iscrizioni_passeggiata;
create policy iscrizioni_passeggiata_insert on iscrizioni_passeggiata for insert
  with check (cliente_id = auth.uid() and stato = 'confermata');

-- il cliente gestisce la propria iscrizione (es. la annulla); lo staff
-- gestisce tutto (es. la libera se annulla l'uscita per maltempo).
drop policy if exists iscrizioni_passeggiata_update on iscrizioni_passeggiata;
create policy iscrizioni_passeggiata_update on iscrizioni_passeggiata for update
  using (cliente_id = auth.uid() or ruolo_utente_corrente() in ('addetto','admin'));

-- capienza massima: si conta per iscritto (persona), non per cane.
create or replace function capienza_passeggiata()
returns int language sql immutable as $$ select 10 $$;

create or replace function controlla_capienza_passeggiata()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  occupati int;
  stato_uscita text;
begin
  if new.stato <> 'confermata' then
    return new;
  end if;

  select stato into stato_uscita from passeggiate where id = new.passeggiata_id;
  if stato_uscita is distinct from 'programmata' then
    raise exception 'Questa passeggiata non è più prenotabile';
  end if;

  lock table iscrizioni_passeggiata in share row exclusive mode;

  select count(*) into occupati
  from iscrizioni_passeggiata
  where passeggiata_id = new.passeggiata_id
    and stato = 'confermata'
    and id <> new.id;

  if occupati >= capienza_passeggiata() then
    raise exception 'Passeggiata al completo (% iscritti)', capienza_passeggiata();
  end if;

  return new;
end;
$$;

drop trigger if exists trg_capienza_passeggiata on iscrizioni_passeggiata;
create trigger trg_capienza_passeggiata
  before insert or update of stato, passeggiata_id on iscrizioni_passeggiata
  for each row execute function controlla_capienza_passeggiata();

-- quando un'uscita viene annullata (maltempo), libera tutti i suoi
-- iscritti così possono iscriversi a quella successiva.
create or replace function libera_iscritti_passeggiata_annullata()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if new.stato = 'annullata_meteo' and old.stato is distinct from 'annullata_meteo' then
    update iscrizioni_passeggiata set stato = 'annullata'
    where passeggiata_id = new.id and stato = 'confermata';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_libera_iscritti_passeggiata on passeggiate;
create trigger trg_libera_iscritti_passeggiata
  after update of stato on passeggiate
  for each row execute function libera_iscritti_passeggiata_annullata();

-- ============================================================
-- CANI PARTECIPANTI (un'iscrizione può includere più cani dello stesso
-- proprietario, tutti nella stessa prenotazione)
-- ============================================================

create table if not exists iscrizione_passeggiata_animali (
  iscrizione_id  uuid not null references iscrizioni_passeggiata(id) on delete cascade,
  animale_id     uuid not null references animali(id) on delete cascade,
  primary key (iscrizione_id, animale_id)
);

alter table iscrizione_passeggiata_animali enable row level security;

drop policy if exists iscrizione_animali_select on iscrizione_passeggiata_animali;
create policy iscrizione_animali_select on iscrizione_passeggiata_animali for select
  using (
    exists (
      select 1 from iscrizioni_passeggiata i
      where i.id = iscrizione_id
        and (i.cliente_id = auth.uid() or ruolo_utente_corrente() in ('addetto','admin'))
    )
  );

drop policy if exists iscrizione_animali_insert on iscrizione_passeggiata_animali;
create policy iscrizione_animali_insert on iscrizione_passeggiata_animali for insert
  with check (
    exists (select 1 from iscrizioni_passeggiata i where i.id = iscrizione_id and i.cliente_id = auth.uid())
    and exists (select 1 from animali a where a.id = animale_id and a.proprietario_id = auth.uid())
  );

drop policy if exists iscrizione_animali_delete on iscrizione_passeggiata_animali;
create policy iscrizione_animali_delete on iscrizione_passeggiata_animali for delete
  using (
    exists (
      select 1 from iscrizioni_passeggiata i
      where i.id = iscrizione_id
        and (i.cliente_id = auth.uid() or ruolo_utente_corrente() in ('addetto','admin'))
    )
  );

-- ============================================================
-- DISPONIBILITÀ PUBBLICA (prossime uscite con i posti liberi, per la
-- pagina di prenotazione — nessun dato personale)
-- ============================================================

create or replace view passeggiate_disponibilita as
  select p.id, p.data, p.ora, p.argomento, p.luogo,
         capienza_passeggiata() - count(i.id) filter (where i.stato = 'confermata') as posti_liberi
  from passeggiate p
  left join iscrizioni_passeggiata i on i.passeggiata_id = p.id
  where p.stato = 'programmata' and p.data >= current_date
  group by p.id
  order by p.data, p.ora;

-- pubblica anche a chi non ha ancora un account: la pagina di presentazione
-- mostra la prossima uscita in programma prima del login.
grant select on passeggiate_disponibilita to anon, authenticated;

-- ============================================================
-- Il vecchio listino a pacchetto delle passeggiate (venduto a voce via
-- WhatsApp) non si usa più: da oggi si prenota dal sito con le regole
-- sopra. Disattivato, non eliminato, per non perdere lo storico.
-- ============================================================

update servizi set attivo = false where categoria = 'passeggiate';
