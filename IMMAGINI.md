# Immagini — nuova organizzazione

## Il problema

Finora l'unica immagine del sito — il logo — non era un file a parte: era
incollata dentro ogni pagina HTML come testo codificato (`data:image/webp;
base64,...`). Funziona, ma ha tre difetti:

- **si ripete 10 volte**: ogni pagina porta con sé la sua copia del logo
  (~20 KB) invece di scaricarlo una volta sola e riusarlo;
- **appesantisce ogni pagina** di decine di KB inutili, rallentando il
  caricamento, specialmente da telefono;
- **è scomodo da aggiornare**: cambiare il logo significa ritagliare e
  incollare codice dentro dieci file diversi, invece di sostituire un file.

Le foto vere e proprie (cani, campo, bosco, Manuel al lavoro) non erano
ancora state caricate da nessuna parte: da qui la nuova cartella pronta a
riceverle.

## La nuova struttura

```
assets/
└── img/
    ├── brand/            logo (già estratto dal base64, pronto all'uso)
    │   ├── logo-nav.webp
    │   └── logo-hero.webp
    ├── index/             foto per la home
    ├── educazione/        foto per educazione.html
    ├── pensione-asilo/    foto per pensione-asilo.html
    ├── chi-siamo/         foto per chi-siamo.html
    └── dove-operiamo/     foto per dove-operiamo.html

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
- **Il logo** (`assets/img/brand/`) è a posto così com'è: non serve
  ricaricarlo, è già stato estratto dalle pagine esistenti.

## Cosa succede dopo

Per ora **le pagine HTML non sono state toccate**: continuano a mostrare il
logo come prima (inline), e non mostrano ancora nessuna foto. Una volta che
le cartelle sono piene, il passo successivo è aggiornare le pagine perché
puntino a questi file (`<img src="assets/img/chi-siamo/01-...jpg">`) al
posto del codice incollato — cosa che libererà anche il logo dalle 10 copie
duplicate. Fammi sapere quando le foto sono pronte e aggiorno le pagine.
