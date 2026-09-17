# Crocevia — sito

Sito di **Crocevia** — educazione cinofila, asilo diurno, pensione e passeggiate
di gruppo. Manuel, educatore cinofilo FICSS.
Settimo Milanese (MI) · campo e bosco sul Lago Maggiore.

Le pagine di presentazione sono HTML statico senza framework, come all'inizio.
Da qui però il sito ha anche un vero backend: un database Supabase con account
utente, animali e prenotazioni, pagamento online (Stripe) per stallo/pensione
e asilo con acconto e saldo separati, evento automatico su Google Calendar a
ogni prenotazione confermata. Educazione, valutazione e passeggiate restano
invece sul modulo che compone un messaggio e apre WhatsApp — nessun account
richiesto per quei servizi. Dettagli tecnici, schema del database ed Edge
Function in `supabase/README.md`.

## Le pagine

| file | cosa contiene |
|---|---|
| `index.html` | home: il bivio tra Educazione e Pensione & Asilo |
| `educazione.html` | valutazione, lezioni, pacchetti, passeggiate di gruppo |
| `pensione-asilo.html` | stallo/pensione, asilo diurno, giornata tipo |
| `prenota.html` | modulo di prenotazione per educazione e passeggiate → messaggio WhatsApp precompilato |
| `area-privata.html` | login/registrazione, profilo, animali e prenotazioni del cliente (Supabase) |
| `prenota-pensione-asilo.html` | calendario disponibilità e richiesta di prenotazione per pensione/asilo (richiede accesso) |
| `area-staff.html` | riservata ad addetto/admin: prenotazioni in arrivo, conferme, prenotazione manuale, ruoli utenti |
| `chi-siamo.html` | Manuel e Dingo, metodo e filosofia |
| `dove-operiamo.html` | campo e bosco, Settimo Milanese |
| `contatti.html` | telefono, email, P.IVA |
| `privacy.html` | informativa privacy |
| `termini.html` | termini e condizioni |
| `404.html` | pagina non trovata |

Contorno: `style.css` (stile condiviso da tutte le pagine), `main.js`
(script condiviso: menu mobile e altezza dell'intestazione), `robots.txt`,
`sitemap.xml`, `.nojekyll` (dice a GitHub Pages di pubblicare i file così
come sono).

`supabase-client.js` inizializza il collegamento al database (Supabase) usato
da `area-privata.html`: contiene solo la URL del progetto e la chiave
"pubblicabile", pensata apposta per stare nel codice del sito. La cartella
`supabase/` contiene lo schema del database e le istruzioni per crearlo —
vedi `supabase/README.md`.

`documenti/` contiene i moduli (privacy, liberatoria foto/video, scarico
responsabilità, prenotazione) in formato `.docx`, non collegati dalle
pagine.

`assets/img/brand/` contiene logo, favicon e icona per iPhone (file veri,
non più incollati dentro le pagine). `assets/img/<pagina>/` sono le
cartelle pronte per le foto vere del sito, una per pagina, ancora vuote —
vedi `IMMAGINI.md` per la nuova organizzazione e come caricare le foto.

## Le tre viste

Ogni pagina si comporta in tre modi:

| vista | quando | cosa cambia |
|---|---|---|
| telefono in verticale | fino a 999px | menu hamburger a tutto schermo, una colonna, barra "Prenota" fissa in basso |
| telefono in orizzontale | `orientation:landscape`, larghezza ≤999px **e** altezza ≤560px | intestazione più bassa, menu su due colonne, meno spazi vuoti |
| computer | da 1000px | menu in linea, niente hamburger, niente barra |

La vista orizzontale guarda larghezza **e** altezza: un telefono girato è largo
~850px, e una regola sulla sola larghezza lo scambierebbe per un tablet.

## Se metti mano al codice

- Lo stile è tutto in `style.css`, condiviso da tutte le pagine: modificalo
  lì, non serve più ripetere le modifiche su dieci file. Stesso discorso per
  `main.js` (menu mobile e altezza dell'intestazione) — lo script del
  modulo di prenotazione resta invece dentro `prenota.html`, è specifico
  di quella pagina.
- **Non togliere `<meta name="viewport">`.** Senza, il telefono disegna la
  pagina larga 980px e la rimpicciolisce: testo minuscolo e nessuna regola
  mobile che entra in funzione.
- `--testata` la misura lo script, non scriverla a mano: il menu si aggancia lì
  sotto. Se cambi l'altezza dell'intestazione si adegua da sola.
- **Niente `backdrop-filter` sull'intestazione sotto i 999px:** un elemento con
  `backdrop-filter` diventa il riferimento per i figli `position:fixed`, e il
  menu a tutto schermo finirebbe agganciato all'intestazione invece che allo
  schermo.
- I campi del modulo stanno a 16px: sotto quella misura iOS zooma da solo quando
  li tocchi.
- In `prenota.html` la regola `[data-blocco]{display:none}` / `.attivo` governa
  le due schede data (lezione singola, pacchetto). Se sparisce, compaiono
  entrambe insieme. Pensione e asilo non sono più su questa pagina: hanno il
  loro calendario in `prenota-pensione-asilo.html`.

## Caricare gli aggiornamenti su GitHub

Dall'interfaccia web: **Add file → Upload files**, trascina i file, poi
**Commit changes**. Un file con lo stesso nome sostituisce quello di prima.

Attenzione a una cosa sola: se il browser ha salvato il file come
`index (1).html` o `index-2.html`, **rinominalo** in `index.html` prima di
caricarlo, altrimenti su GitHub finiscono due pagine diverse e la home continua
a mostrare quella vecchia.

Da riga di comando:

```bash
git add -A
git commit -m "aggiorna il sito"
git push
```

## Pubblicazione

GitHub Pages, ramo `main`, cartella radice (`/`).
`sitemap.xml` e `robots.txt` puntano a
`https://manuel-1991.github.io/Crocevia_website/`: se in futuro colleghi un
dominio tuo, cambia quell'indirizzo in tutti e due i file e aggiungi un file
`CNAME` con il dominio dentro.

---

© Crocevia — Manuel · P.IVA 14868890964
