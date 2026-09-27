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

## Stato attuale (settembre 2026)

Le foto sono online. Le 297 foto originali sono state caricate sul branch
`foto-grezze` (solo deposito, non va unito al sito); da lì ne sono state
scelte 15, ritagliate, corrette leggermente in luce e colore, ridimensionate
e salvate in `.webp` dentro le cartelle di `assets/img/`.

- **Metadati rimossi**: le foto da telefono contengono data e coordinate GPS
  (anche di casa). Le versioni per il sito non hanno più nessun metadato.
- **Due misure per foto**: `nome.webp` (grande) e `nome-480.webp` (piccola,
  per il telefono), scelte dal browser con `srcset`. Il banner di
  `passeggiate/` ha `-800` al posto di `-480`.
- **Dove sono usate**: home (3 riquadri), chi siamo (Manuel, Dingo), dove
  operiamo (una per luogo), educazione e passeggiate (galleria + banner),
  pensione & asilo (galleria da 3).
- **Stili**: `.card-foto`, `.foto-banner`, `.foto-griglia` in `style.css`.

Per aggiungere o cambiare una foto basta sostituire il file con lo stesso
nome (stesse proporzioni: 4:3, quadrate per chi siamo, banner 16:9), oppure chiedere a Claude di
rifare la selezione dal branch `foto-grezze`.
