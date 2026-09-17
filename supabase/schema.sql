-- Crocevia — schema del database (Supabase / Postgres)
-- Da eseguire una sola volta in: Dashboard Supabase → SQL Editor → New query → Run
-- Sicuro da rieseguire: usa IF NOT EXISTS / CREATE OR REPLACE dove possibile.

create extension if not exists pgcrypto;   -- gen_random_uuid()
create extension if not exists btree_gist; -- vincoli di non sovrapposizione date

-- ============================================================
-- PROFILI (dati di contatto + ruolo, un profilo per utente registrato)
-- ============================================================

create table if not exists profili (
  id               uuid primary key references auth.users(id) on delete cascade,
  nome             text,
  cognome          text,
  telefono         text,
  email            text,
  indirizzo        text,
  codice_fiscale   text,
  ruolo            text not null default 'cliente' check (ruolo in ('cliente','addetto','admin')),
  creato_il        timestamptz not null default now()
);

alter table profili enable row level security;

-- Funzione di appoggio: ruolo dell'utente che sta facendo la richiesta.
-- security definer così non innesca ricorsione con le policy di "profili".
create or replace function ruolo_utente_corrente()
returns text
language sql stable security definer set search_path = public as $$
  select ruolo from profili where id = auth.uid();
$$;

-- Crea automaticamente il profilo quando qualcuno si registra
create or replace function gestisci_nuovo_utente()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into profili (id, email, ruolo) values (new.id, new.email, 'cliente');
  return new;
end;
$$;

drop trigger if exists trg_nuovo_utente on auth.users;
create trigger trg_nuovo_utente
  after insert on auth.users
  for each row execute function gestisci_nuovo_utente();

-- Impedisce a un cliente di auto-promuoversi cambiando il proprio ruolo
create or replace function blocca_cambio_ruolo()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.ruolo <> old.ruolo and ruolo_utente_corrente() <> 'admin' then
    raise exception 'Solo un admin può cambiare il ruolo di un utente';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_blocca_cambio_ruolo on profili;
create trigger trg_blocca_cambio_ruolo
  before update on profili
  for each row execute function blocca_cambio_ruolo();

drop policy if exists profili_select on profili;
create policy profili_select on profili for select
  using (id = auth.uid() or ruolo_utente_corrente() in ('addetto','admin'));

drop policy if exists profili_update on profili;
create policy profili_update on profili for update
  using (id = auth.uid() or ruolo_utente_corrente() = 'admin');

-- ============================================================
-- ANIMALI
-- ============================================================

create table if not exists animali (
  id                    uuid primary key default gen_random_uuid(),
  proprietario_id       uuid not null references profili(id) on delete cascade,
  nome                  text not null,
  razza                 text,
  data_nascita          date,
  sesso                 text,
  sterilizzato          boolean,
  note_mediche          text,
  note_comportamentali  text,
  creato_il             timestamptz not null default now()
);

alter table animali enable row level security;

drop policy if exists animali_select on animali;
create policy animali_select on animali for select
  using (proprietario_id = auth.uid() or ruolo_utente_corrente() in ('addetto','admin'));

drop policy if exists animali_insert on animali;
create policy animali_insert on animali for insert
  with check (proprietario_id = auth.uid());

drop policy if exists animali_update on animali;
create policy animali_update on animali for update
  using (proprietario_id = auth.uid() or ruolo_utente_corrente() in ('addetto','admin'));

drop policy if exists animali_delete on animali;
create policy animali_delete on animali for delete
  using (proprietario_id = auth.uid() or ruolo_utente_corrente() = 'admin');

-- ============================================================
-- SERVIZI (listino: l'admin lo modifica da qui, non serve toccare il sito)
-- ============================================================

create table if not exists servizi (
  id             uuid primary key default gen_random_uuid(),
  categoria      text not null check (categoria in ('educazione','passeggiate','pensione','asilo')),
  nome           text not null,
  prezzo         numeric(10,2) not null,
  unita_misura   text not null default 'giorno', -- giorno | ora | una_tantum
  attivo         boolean not null default true
);

alter table servizi enable row level security;

drop policy if exists servizi_select on servizi;
create policy servizi_select on servizi for select using (true); -- listino pubblico

drop policy if exists servizi_scrittura on servizi;
create policy servizi_scrittura on servizi for all
  using (ruolo_utente_corrente() = 'admin')
  with check (ruolo_utente_corrente() = 'admin');

-- ============================================================
-- PRENOTAZIONI
-- ============================================================

create table if not exists prenotazioni (
  id                  uuid primary key default gen_random_uuid(),
  cliente_id          uuid not null references profili(id),
  animale_id          uuid not null references animali(id),
  servizio_id         uuid not null references servizi(id),
  data_dal            date not null,
  data_al             date not null,
  stato               text not null default 'in_attesa_pagamento'
                       check (stato in ('in_attesa_pagamento','confermata','completata','annullata')),
  prezzo_totale       numeric(10,2),
  acconto_importo     numeric(10,2),
  acconto_pagato_il   timestamptz,
  saldo_importo       numeric(10,2),
  saldo_pagato_il     timestamptz,
  note                text,
  creato_il           timestamptz not null default now(),
  check (data_al >= data_dal),

  -- lo stesso animale non può avere due prenotazioni attive che si sovrappongono
  exclude using gist (
    animale_id with =,
    daterange(data_dal, data_al, '[]') with &&
  ) where (stato in ('in_attesa_pagamento','confermata'))
);

-- capienza massima condivisa pensione+asilo (stesso spazio): un solo punto
-- da cambiare in futuro se cambia lo spazio disponibile.
create or replace function capienza_pensione_asilo()
returns int language sql immutable as $$ select 5 $$;

-- controlla, ad ogni inserimento/modifica, che nessun giorno del soggiorno
-- richiesto superi la capienza massima (pensione e asilo condividono lo
-- stesso conteggio: sono lo stesso spazio fisico).
create or replace function controlla_capienza_pensione_asilo()
returns trigger
language plpgsql as $$
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

alter table prenotazioni enable row level security;

drop policy if exists prenotazioni_select on prenotazioni;
create policy prenotazioni_select on prenotazioni for select
  using (cliente_id = auth.uid() or ruolo_utente_corrente() in ('addetto','admin'));

-- il cliente può solo creare una richiesta "in attesa di pagamento", per un
-- animale suo; la conferma avviene solo via Edge Function dopo il pagamento
drop policy if exists prenotazioni_insert on prenotazioni;
create policy prenotazioni_insert on prenotazioni for insert
  with check (
    cliente_id = auth.uid()
    and stato = 'in_attesa_pagamento'
    and exists (select 1 from animali a where a.id = animale_id and a.proprietario_id = auth.uid())
  );

-- il cliente può annullare una propria prenotazione non ancora pagata;
-- lo staff può aggiornare tutto (conferme, saldi, check-in/out)
drop policy if exists prenotazioni_update on prenotazioni;
create policy prenotazioni_update on prenotazioni for update
  using (
    ruolo_utente_corrente() in ('addetto','admin')
    or (cliente_id = auth.uid() and stato = 'in_attesa_pagamento')
  );

-- ============================================================
-- PAGAMENTI (log delle transazioni Stripe — le scrive solo l'Edge Function
-- con la service role, che bypassa RLS: nessuna policy di insert per gli utenti)
-- ============================================================

create table if not exists pagamenti (
  id                     uuid primary key default gen_random_uuid(),
  prenotazione_id        uuid not null references prenotazioni(id),
  tipo                   text not null check (tipo in ('acconto','saldo')),
  importo                numeric(10,2) not null,
  stripe_payment_id      text,
  stato                  text not null default 'in_attesa' check (stato in ('in_attesa','pagato','fallito')),
  creato_il              timestamptz not null default now(),
  pagato_il              timestamptz
);

alter table pagamenti enable row level security;

drop policy if exists pagamenti_select on pagamenti;
create policy pagamenti_select on pagamenti for select
  using (ruolo_utente_corrente() in ('addetto','admin'));

-- ============================================================
-- DISPONIBILITÀ PUBBLICA (per il calendario pieno/vuoto di pensione e asilo:
-- solo date occupate, nessun dato personale — leggibile da chiunque sia loggato)
-- ============================================================

create or replace view disponibilita_pensione_asilo as
  select s.categoria, p.data_dal, p.data_al
  from prenotazioni p
  join servizi s on s.id = p.servizio_id
  where p.stato in ('in_attesa_pagamento','confermata')
    and s.categoria in ('pensione','asilo');

grant select on disponibilita_pensione_asilo to authenticated;
