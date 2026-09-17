(function(){
  var testata = document.querySelector('.site-header');
  var bottone = document.getElementById('apri-menu');
  var menu    = document.getElementById('menu-crocevia');

  /* L'altezza dell'intestazione non è un numero fisso: cambia con
     l'orientamento e con la dimensione del testo. La misuriamo. */
  function misuraTestata(){
    if(testata){
      document.documentElement.style.setProperty('--testata', testata.offsetHeight + 'px');
    }
  }
  misuraTestata();
  window.addEventListener('resize', misuraTestata);
  window.addEventListener('orientationchange', function(){ setTimeout(misuraTestata, 120); });

  if(!bottone || !menu) return;

  function chiudi(){
    document.body.classList.remove('menu-aperto');
    bottone.setAttribute('aria-expanded','false');
    bottone.setAttribute('aria-label','Apri il menu');
  }
  bottone.addEventListener('click', function(){
    var aperto = document.body.classList.toggle('menu-aperto');
    bottone.setAttribute('aria-expanded', aperto ? 'true' : 'false');
    bottone.setAttribute('aria-label', aperto ? 'Chiudi il menu' : 'Apri il menu');
    misuraTestata();
  });
  menu.addEventListener('click', function(e){
    if(e.target.closest('a')) chiudi();
  });
  window.addEventListener('keydown', function(e){
    if(e.key === 'Escape' || e.key === 'Esc') chiudi();
  });
  window.addEventListener('resize', function(){
    if(window.innerWidth >= 1000) chiudi();
  });
})();

/* interruttore tema chiaro/scuro — la scelta manuale (in localStorage)
   prevale sempre sulla preferenza di sistema, già gestita via CSS. */
(function(){
  var CHIAVE = 'crocevia-tema';
  var BG_SCURO = '#0d2219';
  var BG_CHIARO = '#f2e6c4';
  var pulsante = document.getElementById('cambia-tema');
  var meta = document.querySelector('meta[name="theme-color"]');
  var sistemaChiaro = window.matchMedia && window.matchMedia('(prefers-color-scheme: light)');

  function temaForzato(){
    try{ return localStorage.getItem(CHIAVE); }catch(e){ return null; }
  }
  function temaEffettivo(){
    var forzato = temaForzato();
    if(forzato === 'chiaro' || forzato === 'scuro') return forzato;
    return (sistemaChiaro && sistemaChiaro.matches) ? 'chiaro' : 'scuro';
  }
  function aggiorna(){
    var attivo = temaEffettivo();
    if(meta) meta.setAttribute('content', attivo === 'chiaro' ? BG_CHIARO : BG_SCURO);
    if(pulsante){
      pulsante.setAttribute('aria-label', attivo === 'chiaro' ? 'Passa al tema scuro' : 'Passa al tema chiaro');
      pulsante.setAttribute('aria-pressed', attivo === 'chiaro' ? 'true' : 'false');
    }
  }
  aggiorna();
  if(sistemaChiaro && sistemaChiaro.addEventListener){
    sistemaChiaro.addEventListener('change', function(){
      if(!temaForzato()) aggiorna();
    });
  }
  if(!pulsante) return;
  pulsante.addEventListener('click', function(){
    var nuovo = temaEffettivo() === 'chiaro' ? 'scuro' : 'chiaro';
    document.documentElement.setAttribute('data-tema', nuovo);
    try{ localStorage.setItem(CHIAVE, nuovo); }catch(e){}
    aggiorna();
  });
})();

/* comparsa allo scroll: gli elementi con classe .reveal partono
   trasparenti (in CSS) e prendono .is-visible ogni volta che entrano
   nello schermo — e la perdono uscendone, così scendendo e risalendo
   con lo scroll l'animazione si ripete invece di sparire dopo la prima
   volta. Un <noscript> nella pagina neutralizza .reveal se lo script
   non parte, così il contenuto non resta mai invisibile. */
(function(){
  var elementi = document.querySelectorAll('.reveal');
  if(!elementi.length) return;

  var riduciMovimento = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  if(riduciMovimento || !('IntersectionObserver' in window)){
    for(var i=0; i<elementi.length; i++) elementi[i].classList.add('is-visible');
    return;
  }

  var osservatore = new IntersectionObserver(function(entries){
    entries.forEach(function(entry){
      entry.target.classList.toggle('is-visible', entry.isIntersecting);
    });
  }, { threshold: 0.15, rootMargin: '0px 0px -40px 0px' });

  elementi.forEach(function(el){ osservatore.observe(el); });
})();
