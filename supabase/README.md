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
- `005_scadenza_automatica_prenotazioni.sql` — annulla (pg_cron) le
  prenotazioni "in attesa di pagamento" mai pagate, così non bloccano un
  posto all'infinito
- `006_staff_puo_creare_prenotazioni_manuali.sql` — permette a
  addetto/admin di creare una prenotazione per conto di un cliente già
  registrato (chi telefona invece di usare il sito)
- `007_scadenza_15_minuti.sql` — accorcia la scadenza da 30 a 15 minuti
- `008_integrazione_google_calendar.sql` — trigger che chiama
  `crea-evento-calendario` ogni volta che una prenotazione diventa
  confermata (vedi sezione dedicata sotto)

Avvisi di sicurezza rivisti e lasciati come sono, perché non applicabili
a questo progetto: l'estensione `btree_gist` nello schema `public`
(comune, spostarla non vale lo sforzo per questa scala) e le funzioni
`blocca_cambio_ruolo`/`gestisci_nuovo_utente` segnalate come chiamabili
via RPC (sono funzioni trigger: Postgres impedisce di chiamarle
direttamente, l'avviso è un falso positivo).

## 5. Pagamenti (functions/)

Due Edge Function, già distribuite al progetto live:

- **`crea-pagamento`** — chiamata dal sito (autenticata) quando un cliente
  clicca "Paga acconto" o "Paga saldo": legge la prenotazione con il token
  dell'utente stesso (le RLS impediscono di pagare prenotazioni altrui),
  crea una sessione di pagamento Stripe Checkout e la registra in
  `pagamenti` come "in attesa". Torna l'URL a cui il sito reindirizza.
- **`stripe-webhook`** — chiamata da Stripe quando il pagamento va a buon
  fine: verifica la firma con `STRIPE_WEBHOOK_SECRET`, poi con la chiave
  service role segna il pagamento "pagato" e la prenotazione "confermata"
  (acconto) o aggiorna `saldo_pagato_il` (saldo).

L'endpoint webhook su Stripe (modalità test, account sandbox
`acct_1UGlfoBh7RgvyMiF`) è già creato via connettore Stripe, puntato su
`https://gcjxhgvghncjjvcnacbv.supabase.co/functions/v1/stripe-webhook`,
evento `checkout.session.completed`.

I due secret (`STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`) sono già
impostati su Supabase. Flusso testato end-to-end (vedi cronologia della
conversazione): registrazione, prenotazione, pagamento, webhook di
conferma, tutto verificato in modalità test/sandbox.

Per testare i pagamenti in modalità test si usano le carte di prova di
Stripe (es. `4242 4242 4242 4242`, qualsiasi data futura e CVC), nessun
addebito reale.

## 5b. Google Calendar (functions/crea-evento-calendario)

Quando una prenotazione diventa "confermata" (pagamento online, conferma
manuale dello staff, o prenotazione manuale con acconto già ricevuto), un
trigger nel database (`008_integrazione_google_calendar.sql`) chiama
questa Edge Function, che crea un evento di un giorno intero sul
calendario Google configurato. Autenticazione lato Google Calendar tramite
service account (server-to-server, non dipende da nessuna sessione di
chat collegata); autenticazione della chiamata trigger→funzione tramite
un segreto condiviso salvato in Supabase Vault.

Nel modulo "Aggiungi una prenotazione" del pannello staff, la casella
"Non creare l'evento sul calendario" imposta `salta_calendario = true` e
salta questa parte per quella prenotazione.

### Tre secret da impostare (Dashboard Supabase → Project Settings → Edge
Functions → Secrets):

| Secret | Valore |
|---|---|
| `GOOGLE_SERVICE_ACCOUNT_JSON` | il contenuto intero del file JSON scaricato dal service account Google Cloud |
| `GOOGLE_CALENDAR_ID` | l'ID del calendario Google su cui creare gli eventi |
| `INTERNAL_WEBHOOK_SECRET` | il valore dato in chat quando è stato generato (salvato in Vault, non riscrivibile qui) |

Il service account deve avere accesso "Apportare modifiche agli eventi"
sul calendario scelto (Google Calendar → impostazioni del calendario →
Condividi con persone specifiche → incolla l'email `client_email` del
file JSON).

## 6. Prossimi passi

1. ~~Eseguire `schema.sql`~~ ✓
2. ~~Popolare la tabella `servizi`~~ ✓
3. ~~Login/registrazione + area privata cliente~~ ✓
4. ~~Calendario disponibilità pensione/asilo~~ ✓
5. ~~Edge Function `crea-pagamento` + `stripe-webhook`~~ ✓
6. ~~Pagina staff (addetto/admin)~~ ✓
7. ~~Scadenza automatica delle prenotazioni non pagate~~ ✓ (15 minuti)
8. ~~Provider email per Supabase Auth~~ ✓ (SMTP custom con la casella
   Aruba già esistente sul dominio — nessun account esterno nuovo
   necessario; registrazione di prova fatta tramite l'API, accettata
   senza errori di invio)
9. ~~Termini e condizioni riconciliati col sistema di pagamento reale~~ ✓
10. ~~Prenotazione manuale da parte dello staff~~ ✓
11. ~~Evento su Google Calendar per ogni prenotazione confermata~~ ✓
    (service account, verificato end-to-end)

Punti 1-11 completati. Prima di andare live con pagamenti veri restano
solo: cambiare le chiavi Stripe da test a live (nuovo webhook in
modalità live), verificare l'attivazione completa dell'account Stripe
per gli incassi reali, e un vero test con carta reale a importo basso.
