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
- `013_passeggiate.sql` — nuove tabelle `passeggiate` (le uscite
  programmate), `iscrizioni_passeggiata` (una sola attiva per cliente,
  capienza 10 per uscita) e `iscrizione_passeggiata_animali` (più cani
  per iscrizione); vista pubblica `passeggiate_disponibilita`; disattiva
  il vecchio servizio `passeggiate` a listino (venduto a pacchetto via
  WhatsApp, non più in uso)
- `014_irrobustisce_capienza_passeggiata_e_commento_vista.sql` —
  `search_path` fisso su `capienza_passeggiata()` e commento sul perché
  `passeggiate_disponibilita` è volutamente SECURITY DEFINER, stesso
  trattamento già fatto per pensione/asilo in `003`/`004`
- `015_chiude_buchi_passeggiate.sql` — trovati rileggendo 013/014 prima
  dell'uso reale: `iscrizione_passeggiata_animali.animale_id` non è più
  ON DELETE CASCADE (altrimenti si poteva svuotare un'iscrizione attiva
  eliminando l'ultimo cane, lasciando un posto occupato da nessuno);
  l'iscrizione ora richiede un telefono in `profili` (RLS), non solo lato
  sito; `passeggiate_disponibilita` non mostra più un'uscita di oggi il
  cui orario è già passato
- `016_staff_prenota_passeggiata_per_cliente.sql` — stesso schema di
  `006` ma per le passeggiate: permette a addetto/admin di creare
  un'iscrizione per conto di un cliente già registrato (chi telefona),
  mantenendo comunque il requisito del telefono introdotto in `015` e
  verificando che i cani aggiunti siano davvero del cliente giusto
- `017_pagamento_completo_alla_prenotazione.sql` — aggiunge il tipo
  `completo` ai pagamenti: il cliente può scegliere di saldare acconto e
  saldo insieme, in un'unica transazione, già alla prenotazione di
  stallo/pensione/asilo, invece di pagare solo il 10% e il resto alla fine
  del soggiorno

Avvisi di sicurezza rivisti e lasciati come sono, perché non applicabili
a questo progetto: l'estensione `btree_gist` nello schema `public`
(comune, spostarla non vale lo sforzo per questa scala) e le funzioni
`blocca_cambio_ruolo`/`gestisci_nuovo_utente` segnalate come chiamabili
via RPC (sono funzioni trigger: Postgres impedisce di chiamarle
direttamente, l'avviso è un falso positivo).

## 5. Pagamenti (functions/)

Due Edge Function, già distribuite al progetto live:

- **`crea-pagamento`** — chiamata dal sito (autenticata) quando un cliente
  clicca "Paga acconto" o "Paga saldo", oppure quando sceglie di saldare
  per intero già alla prenotazione ("completo", somma di acconto e saldo
  in un'unica transazione): legge la prenotazione con il token dell'utente
  stesso (le RLS impediscono di pagare prenotazioni altrui), crea una
  sessione di pagamento Stripe Checkout e la registra in `pagamenti` come
  "in attesa". Torna l'URL a cui il sito reindirizza.
- **`stripe-webhook`** — chiamata da Stripe quando il pagamento va a buon
  fine: verifica la firma con `STRIPE_WEBHOOK_SECRET`, poi con la chiave
  service role segna il pagamento "pagato" e la prenotazione "confermata"
  (acconto), aggiorna `saldo_pagato_il` (saldo), oppure valorizza insieme
  `acconto_pagato_il` e `saldo_pagato_il` e conferma la prenotazione
  (pagamento completo).

**In produzione dal 18 settembre 2026: chiavi e webhook live.** Conto Stripe
"Crocevia Cani" (`acct_1UGlf4BP3z1Napez`) verificato e attivo —
`charges_enabled`/`payouts_enabled` true, IBAN collegato, nessun
requisito in sospeso. Il webhook live è creato via connettore Stripe,
puntato su `https://gcjxhgvghncjjvcnacbv.supabase.co/functions/v1/stripe-webhook`,
evento `checkout.session.completed`. I secret `STRIPE_SECRET_KEY`
(`sk_live_...`) e `STRIPE_WEBHOOK_SECRET` sono impostati su Supabase con
i valori live. Da questo momento ogni pagamento sul sito è vero.

Il flusso era già stato verificato end-to-end in modalità test/sandbox
(registrazione, prenotazione, pagamento, webhook di conferma, evento
calendario). **Manca ancora un test con una carta vera in produzione** —
non fatto di proposito per ora, da fare quando si vuole con una
prenotazione a importo basso.

L'endpoint di test resta attivo separatamente sull'account sandbox
(`acct_1UGlfoBh7RgvyMiF`), utile se un domani serve provare qualcosa
senza toccare i dati veri.

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

## 5c. Passeggiate di gruppo: niente Stripe, niente Google Calendar

A differenza di pensione/asilo, le passeggiate non passano né da
`crea-pagamento`/`stripe-webhook` né dal trigger di
`008_integrazione_google_calendar.sql`: non c'è acconto da pagare online
(si salda in loco) e le uscite sono righe che lo staff crea a mano in
`passeggiate` dal pannello staff, non prenotazioni con data libera da
confermare. Se in futuro si vuole un evento automatico su Google Calendar
anche per le passeggiate, va scritto un trigger a parte (stessa idea di
quello per `prenotazioni`, ma agganciato a
`passeggiate`/`iscrizioni_passeggiata`): non l'ho fatto ora per non
allargare la modifica oltre a quanto richiesto.

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

12. ~~Chiavi e webhook Stripe passati da test a live~~ ✓ (18 settembre
    2026 — conto verificato attivo, IBAN collegato)

**Il sito è live.** Resta solo, quando si vuole: un vero test con una
carta reale a importo basso, per chiudere il cerchio anche sul lato mai
verificabile da qui (la pagina di pagamento ospitata da Stripe).
