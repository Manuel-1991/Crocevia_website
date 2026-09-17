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
