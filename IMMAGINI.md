# Immagini — nuova organizzazione

## Il problema (risolto per logo, favicon e CSS)

Fino a poco fa, logo, favicon **e** tutto il CSS non erano file a parte: erano
incollati dentro ogni pagina HTML come testo codificato (`data:image/webp;
base64,...`) o ripetuti in un `<style>` per pagina. Funzionava, ma aveva tre
difetti:

- **si ripeteva 10 volte**: ogni pagina portava con sé la sua copia di logo,
  favicon e regole CSS invece di scaricarle una volta sola e riusarle;
- **appesantiva ogni pagina** di decine (nel caso del logo, centinaia) di KB
  inutili, rallentando il caricamento, specialmente da telefono;
- **era scomodo da aggiornare**: cambiare il logo o uno stile significava
  ritagliare e incollare codice dentro dieci file diversi.

Logo, favicon e CSS sono ora file veri (`assets/img/brand/`, `style.css`),
referenziati normalmente da ogni pagina — vedi sotto.

Le foto vere e proprie (cani, campo, bosco, Manuel al lavoro) non sono
ancora state caricate da nessuna parte: da qui la cartella pronta a
riceverle.

## La nuova struttura

```
assets/
└── img/
    ├── brand/            logo, favicon e icona iPhone (file veri, già collegati alle pagine)
    │   ├── logo-nav.webp
    │   ├── logo-hero.webp
    │   ├── favicon.png
    │   └── apple-touch-icon.png
    ├── index/             foto per la home
    ├── educazione/        foto per educazione.html
    ├── pensione-asilo/    foto per pensione-asilo.html
    ├── chi-siamo/         foto per chi-siamo.html
    └── dove-operiamo/     foto per dove-operiamo.html

style.css                  CSS condiviso da tutte le pagine (prima era
                            incollato dentro ogni singola pagina)

documenti/                 i moduli .docx (privacy, liberatoria, ecc.),
                            spostati dalla radice qui dentro
```

Ogni cartella dentro `assets/img/` corrisponde a una pagina: le foto che
riguardano l'educazione cinofila vanno in `assets/img/educazione/`, quelle
del campo e del bosco in `assets/img/dove-operiamo/`, e così via. Se in
futuro serve una cartella per una pagina che oggi non ne ha (es.
`contatti/`), si crea allo stesso modo.

I file `.docx` sono stati spostati in `documenti/` perché non erano
collegati da nessuna pagina del sito: spostarli non rompe nulla.

## Come caricare le foto

Dall'interfaccia web di GitHub: apri la cartella giusta dentro `assets/img/`
(es. `assets/img/chi-siamo`), **Add file → Upload files**, trascina le foto,
**Commit changes**. Stessa procedura già descritta nel `README.md` per le
pagine.

Da riga di comando:

```bash
git add assets/img/chi-siamo
git commit -m "carica foto chi-siamo"
git push
```

### Convenzioni per i nomi e il formato

- **Nome file**: minuscolo, parole separate da trattino, senza spazi né
  accenti — es. `01-manuel-e-dingo.jpg`, `02-passeggiata-bosco.jpg`. Il
  numero davanti è opzionale ma utile se poi le foto vanno mostrate in un
  ordine preciso (galleria).
- **Formato**: `.jpg` va benissimo per foto normali. Se sai esportare in
  `.webp` è ancora meglio (file più leggero a parità di qualità), ma non è
  obbligatorio: si può sempre convertire dopo.
- **Peso**: punta a foto tra 100 e 300 KB l'una. Una foto da smartphone
  moderno può pesare 3-5 MB: prima di caricarla, ridimensionala (lato lungo
  attorno ai 1600px per le foto principali, 1200px per le altre) con
  qualsiasi editor o convertitore online — pesare meno le fa caricare più
  in fretta ai visitatori.
- **Logo e favicon** (`assets/img/brand/`) sono a posto così come sono: non
  serve ricaricarli, sono già collegati a tutte le pagine.

## Cosa succede dopo

Le pagine ora puntano già a `assets/img/brand/` per logo e favicon, e a
`style.css` per lo stile. Le cartelle per le foto vere (`assets/img/index/`,
`assets/img/chi-siamo/`, ecc.) sono pronte ma vuote. Appena carichi le foto,
aggiorno le pagine perché le mostrino (`<img src="assets/img/chi-siamo/01-...jpg">`).
