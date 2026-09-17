# Supabase — Crocevia

Claude ha un collegamento diretto (via MCP) al progetto Supabase
`gcjxhgvghncjjvcnacbv` e da qui in avanti applica schema, seed e migrazioni
direttamente — non serve più incollarli a mano in SQL Editor. I file in
questa cartella restano comunque la fonte di verità e la cronologia
leggibile di cosa è stato fatto e perché.

## 1. Creare lo schema

Già applicato al progetto live. Per un'installazione nuova da zero:
Dashboard Supabase → **SQL Editor** → New query → incolla tutto `schema.sql` → Run.
Crea tabelle, regole di sicurezza (RLS) e i vincoli che impediscono doppie
prenotazioni. Si può rieseguire senza danni se serve aggiornarlo.

## 2. Dove vanno le chiavi (mai nel codice del sito)

| Chiave | Dove si usa | Dove si mette |
|---|---|---|
| URL progetto + chiave **pubblicabile** (`sb_publishable_...` o l'`anon key`) | Nelle pagine HTML, lato browser | Direttamente nel codice statico: è fatta per essere pubblica |
| Chiave **secret** di Supabase (`sb_secret_...`) | Solo nelle Edge Functions, per confermare pagamenti bypassando le regole utente | Dashboard → Project Settings → Edge Functions → Secrets (mai in un file del repository) |
| Chiave **pubblicabile** Stripe (`pk_test_...`) | Nel checkout, lato browser | Nel codice statico: pubblica per natura |
| Chiave **secret** Stripe (`sk_test_...`) | Solo nelle Edge Functions, per creare/verificare pagamenti | Stesso posto della secret di Supabase, mai nel repository |

Nota: la chiave secret di Supabase che hai incollato in chat non è quella
"sandbox" di Stripe — è la chiave vera del progetto. Consiglio, quando lo
setup è finito, di rigenerarla da Dashboard → Project Settings → API
(così quella vista in questa conversazione smette di essere valida).

## 3. Aggiornamenti (migrations/)

Ogni cambiamento allo schema già in produzione arriva come un file numerato
in `migrations/`, applicato direttamente al progetto live. `schema.sql`
resta aggiornato solo come riferimento di come deve apparire
un'installazione pulita da zero.

- `002_capienza_5_cani.sql` — porta la capienza pensione/asilo da 1 a 5
  cani al giorno (condivisa tra i due servizi)
- `003_search_path_funzioni_capienza.sql` — irrobustisce le funzioni della
  capienza (segnalazione dell'advisor di sicurezza di Supabase)
- `004_commento_vista_disponibilita.sql` — documenta nel database perché
  `disponibilita_pensione_asilo` bypassa volutamente le RLS di
  `prenotazioni` (serve al calendario condiviso, non è un errore)

Avvisi di sicurezza rivisti e lasciati come sono, perché non applicabili
a questo progetto: l'estensione `btree_gist` nello schema `public`
(comune, spostarla non vale lo sforzo per questa scala) e le funzioni
`blocca_cambio_ruolo`/`gestisci_nuovo_utente` segnalate come chiamabili
via RPC (sono funzioni trigger: Postgres impedisce di chiamarle
direttamente, l'avviso è un falso positivo).

## 4. Prossimi passi

1. ~~Eseguire `schema.sql`~~ ✓
2. ~~Popolare la tabella `servizi`~~ ✓
3. ~~Login/registrazione + area privata cliente~~ ✓
4. ~~Calendario disponibilità pensione/asilo~~ ✓
5. Edge Function `crea-prenotazione` + `stripe-webhook` (pagamento acconto)
