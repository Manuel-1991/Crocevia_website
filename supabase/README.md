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

### Due secret da impostare (una tantum, Dashboard Supabase → Edge
Functions → Secrets) — nessun redeploy necessario dopo averli salvati:

| Secret | Valore |
|---|---|
| `STRIPE_SECRET_KEY` | la chiave `sk_test_...` che mi hai già dato |
| `STRIPE_WEBHOOK_SECRET` | vedi sotto — arriva da Stripe, non da me |

### Un passaggio manuale su Stripe (non posso farlo io: il proxy di rete di
questo ambiente blocca le chiamate dirette a api.stripe.com)

Stripe Dashboard (modalità **test**, dato che le chiavi sono `pk_test_`/
`sk_test_`) → **Developer → Webhooks → Add endpoint**:
- Endpoint URL: `https://gcjxhgvghncjjvcnacbv.supabase.co/functions/v1/stripe-webhook`
- Evento da inviare: `checkout.session.completed`
- Dopo la creazione, copia il "Signing secret" (`whsec_...`) e mettilo come
  `STRIPE_WEBHOOK_SECRET` nel punto sopra.

Per testare i pagamenti in modalità test si usano le carte di prova di
Stripe (es. `4242 4242 4242 4242`, qualsiasi data futura e CVC), nessun
addebito reale.

## 6. Prossimi passi

1. ~~Eseguire `schema.sql`~~ ✓
2. ~~Popolare la tabella `servizi`~~ ✓
3. ~~Login/registrazione + area privata cliente~~ ✓
4. ~~Calendario disponibilità pensione/asilo~~ ✓
5. ~~Edge Function `crea-pagamento` + `stripe-webhook`~~ ✓ (mancano solo i
   due secret e il webhook Stripe, vedi sopra)
6. Pagina per lo staff (addetto/admin): vedere le richieste in arrivo,
   confermarle, gestire i saldi
7. Scadenza automatica delle prenotazioni "in attesa di pagamento" mai
   pagate, per non tenere bloccato un posto all'infinito
