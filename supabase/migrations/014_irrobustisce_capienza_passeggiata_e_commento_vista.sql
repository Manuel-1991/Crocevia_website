-- Stesso irrobustimento già fatto per pensione/asilo in
-- 003_search_path_funzioni_capienza.sql, applicato ora a
-- capienza_passeggiata() (segnalato dall'advisor di sicurezza appena
-- introdotta la tabella): senza search_path fisso, una funzione IMMUTABLE
-- è in teoria dirottabile creando un oggetto con lo stesso nome in uno
-- schema che precede "public" nel search_path del chiamante.
-- Già applicata al progetto live.

create or replace function capienza_passeggiata()
returns int language sql immutable
set search_path = public, pg_temp
as $$ select 10 $$;

-- Stessa nota già lasciata su disponibilita_pensione_asilo in
-- 004_commento_vista_disponibilita.sql: la vista è SECURITY DEFINER (di
-- default per le viste Postgres) e quindi bypassa volutamente le RLS di
-- iscrizioni_passeggiata — è così che mostra i posti liberi aggregati
-- (un conteggio, nessun dato personale) anche a chi non ha ancora
-- un'iscrizione propria da cui le RLS gli farebbero vedere righe. Non è
-- un errore, è il motivo per cui esiste questa vista invece di leggere
-- direttamente la tabella.
comment on view passeggiate_disponibilita is
  'SECURITY DEFINER intenzionale: mostra i posti liberi aggregati delle prossime passeggiate (nessun dato personale) anche a chi non ha ancora un account, bypassando le RLS di iscrizioni_passeggiata che altrimenti nasconderebbero le iscrizioni altrui. Vedi anche disponibilita_pensione_asilo.';
