# Crocevia — sito

Sito di **Crocevia** — educazione cinofila, asilo diurno, pensione e passeggiate
di gruppo. Manuel Pegoraro, educatore cinofilo FICSS.
Settimo Milanese (MI) · campo e bosco sul Lago Maggiore.

Dieci pagine HTML statiche, senza framework e senza backend: si aprono anche
facendo doppio clic sul file. La prenotazione non passa da un server, il modulo
compone un messaggio e apre WhatsApp.

## Le pagine

| file | cosa contiene |
|---|---|
| `index.html` | home: il bivio tra Educazione e Pensione & Asilo |
| `educazione.html` | valutazione, lezioni, pacchetti, passeggiate di gruppo |
| `pensione-asilo.html` | stallo/pensione, asilo diurno, giornata tipo |
| `prenota.html` | modulo di prenotazione → messaggio WhatsApp precompilato |
| `chi-siamo.html` | Manuel e Dingo, metodo e filosofia |
| `dove-operiamo.html` | campo e bosco, Settimo Milanese |
| `contatti.html` | telefono, email, P.IVA |
| `privacy.html` | informativa privacy |
| `termini.html` | termini e condizioni |
| `404.html` | pagina non trovata |

Contorno: `apple-touch-icon.png` (icona su iPhone quando si salva in home),
`robots.txt`, `sitemap.xml`, `.nojekyll` (dice a GitHub Pages di pubblicare i
file così come sono).

Il logo è dentro le pagine, non è un file a parte: nessun collegamento da
rompere.

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
  le tre schede data (lezione singola, pacchetto, soggiorno). Se sparisce,
  compaiono tutte e tre insieme.

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

## Ancora da compilare

Testi lasciati come sono, sono decisioni da prendere:

- `privacy.html` — la data in "In vigore dal [data]"
- `termini.html` — la stessa data, i metodi di pagamento, rimborso
  `[integrale / parziale]`, la regola sui ritardi, `[48 ore]`, `[7 giorni]`,
  `[20 minuti]`, validità pacchetti `[X mesi]`, recesso `[X giorni]`

---

© Crocevia — Manuel Pegoraro · P.IVA 14868890964
