/* Area privata e staff — script condiviso.
   Da caricare dopo supabase-js e supabase-client.js. Fa tre cose:
   1) se sei loggato, sostituisce l'icona dell'area privata in testata con
      il pulsante che apre il menù "il mio conto" (con i contatori delle
      cose da fare);
   2) protegge le pagine dell'area: CroceviaArea.pagina() rimanda
      all'accesso chi non è loggato, e allo staff solo addetti e admin;
   3) raccoglie le piccole funzioni che servono a tutte le pagine
      (date, euro, avvisi...). */
(function(){
  var sb = window.CroceviaSupabase;
  if (!sb || window.CroceviaArea) return;

  var CHIAVE_ULTIMA_VISITA = 'crocevia-staff-ultima-visita';
  var CHIAVE_INIZIALE = 'crocevia-conto';
  // sessione finita o uscita: torna l'omino
  function dimenticaIniziale(){
    try { localStorage.removeItem(CHIAVE_INIZIALE); } catch (e) {}
    document.documentElement.classList.remove('conto-noto');
  }
  var CAPIENZA_PASSEGGIATA = 10;
  var nomiGiorni = ['domenica','lunedì','martedì','mercoledì','giovedì','venerdì','sabato'];
  var giorniBrevi = ['dom','lun','mar','mer','gio','ven','sab'];
  var nomiMesi = ['gennaio','febbraio','marzo','aprile','maggio','giugno','luglio','agosto','settembre','ottobre','novembre','dicembre'];

  // ---------- funzioni di appoggio ----------

  // sicuro anche dentro gli attributi: escape pure delle virgolette
  var ENTITA = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' };
  function escapeHtml(s){
    return String(s == null ? '' : s).replace(/[&<>"']/g, function(c){ return ENTITA[c]; });
  }
  function euro(n){ return n == null ? '' : Number(n).toLocaleString('it-IT', { style: 'currency', currency: 'EUR' }); }
  function avviso(el, testo, tipo){
    el.textContent = testo;
    el.className = 'avviso ' + (tipo === 'errore' ? 'avviso-errore' : 'avviso-ok');
    el.hidden = false;
  }
  function dataLocale(s){ return new Date(s + 'T00:00:00'); }
  function isoLocale(d){
    var m = d.getMonth() + 1, g = d.getDate();
    return d.getFullYear() + '-' + (m < 10 ? '0' : '') + m + '-' + (g < 10 ? '0' : '') + g;
  }
  function oggiIso(){ return isoLocale(new Date()); }
  function traGiorni(n){ var d = new Date(); d.setDate(d.getDate() + n); return isoLocale(d); }
  function giorniTra(daIso, aIso){ return Math.round((dataLocale(aIso) - dataLocale(daIso)) / 86400000); }
  // "martedì 30 settembre"
  function formattaData(iso){
    var d = dataLocale(iso);
    return nomiGiorni[d.getDay()] + ' ' + d.getDate() + ' ' + nomiMesi[d.getMonth()];
  }
  // "dom 12 → sab 18 ottobre" / "lun 3 novembre"
  function intervallo(dal, al){
    var a = dataLocale(dal), b = dataLocale(al);
    var fine = giorniBrevi[b.getDay()] + ' ' + b.getDate() + ' ' + nomiMesi[b.getMonth()];
    if (dal === al) return fine;
    var inizio = giorniBrevi[a.getDay()] + ' ' + a.getDate() +
      (a.getMonth() !== b.getMonth() || a.getFullYear() !== b.getFullYear() ? ' ' + nomiMesi[a.getMonth()] : '');
    return inizio + ' → ' + fine;
  }
  // stessa regola del prezzo: dal-al inclusi (vedi calcolo in prenota-pensione-asilo.html)
  function durata(dal, al, categoria){
    var n = giorniTra(dal, al) + 1;
    if (categoria === 'asilo') return n + (n === 1 ? ' giorno' : ' giorni');
    return n + (n === 1 ? ' notte' : ' notti');
  }
  function telefonoLink(tel){
    if (!tel) return '';
    return '<a href="tel:' + escapeHtml(String(tel).replace(/[^\d+]/g, '')) + '">' + escapeHtml(tel) + '</a>';
  }
  function nomeCompleto(p){
    return ((p && p.nome ? p.nome : '') + ' ' + (p && p.cognome ? p.cognome : '')).trim();
  }
  // campi obbligatori del profilo (il codice fiscale è facoltativo)
  var CAMPI_PROFILO = { nome: 'nome', cognome: 'cognome', telefono: 'telefono', indirizzo: 'indirizzo' };
  function campiMancanti(p){
    return Object.keys(CAMPI_PROFILO).filter(function(k){ return !p || !p[k]; }).map(function(k){ return CAMPI_PROFILO[k]; });
  }
  function eStaff(p){ return !!p && (p.ruolo === 'addetto' || p.ruolo === 'admin'); }
  function ultimaVisitaStaff(){ try { return localStorage.getItem(CHIAVE_ULTIMA_VISITA); } catch (e) { return null; } }
  function segnaVisitaStaff(){ try { localStorage.setItem(CHIAVE_ULTIMA_VISITA, new Date().toISOString()); } catch (e) {} }

  // restituisce false se il pagamento non è partito (per riattivare il pulsante)
  function avviaPagamento(prenotazioneId, tipo){
    return sb.functions.invoke('crea-pagamento', { body: { prenotazione_id: prenotazioneId, tipo: tipo } }).then(function(r){
      if (r.error || !r.data || !r.data.url) {
        window.alert('Non è stato possibile avviare il pagamento. Riprova tra poco.');
        return false;
      }
      window.location.href = r.data.url;
      return true;
    }, function(){
      window.alert('Non è stato possibile avviare il pagamento. Riprova tra poco.');
      return false;
    });
  }

  // ---------- sessione e profilo (una sola richiesta per pagina) ----------

  var sessione = sb.auth.getSession().then(function(r){
    var s = r.data && r.data.session;
    if (!s) return null;
    return sb.from('profili').select('*').eq('id', s.user.id).single().then(function(p){
      return { utente: s.user, profilo: p.data || { id: s.user.id } };
    });
  }).catch(function(){ return null; });

  // ---------- menù "il mio conto" ----------

  var ICONE = {
    panoramica: '<path d="M3 11l9-7 9 7v9a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z"/>',
    profilo: '<circle cx="12" cy="8" r="3.5"/><path d="M5 20c1.2-4 4-6 7-6s5.8 2 7 6"/>',
    cani: '<circle cx="6.5" cy="10" r="1.8"/><circle cx="10" cy="6" r="1.8"/><circle cx="14.5" cy="6" r="1.8"/><circle cx="18" cy="10" r="1.8"/><path d="M8 17.5c0-3 2-5.5 4.3-5.5s4.3 2.5 4.3 5.5c0 1.8-1.8 2.3-4.3 2.3S8 19.3 8 17.5z"/>',
    calendario: '<rect x="3" y="5" width="18" height="16" rx="1"/><path d="M3 10h18M8 3v4M16 3v4"/>',
    luogo: '<path d="M12 21s-7-6.5-7-12a7 7 0 0 1 14 0c0 5.5-7 12-7 12z"/><circle cx="12" cy="9" r="2.5"/>',
    oggi: '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>',
    elenco: '<path d="M8 6h13M8 12h13M8 18h13M3.5 6h.01M3.5 12h.01M3.5 18h.01"/>',
    piu: '<path d="M12 5v14M5 12h14"/>',
    persone: '<circle cx="9" cy="8" r="3"/><path d="M3 20c.8-3.5 3.2-5 6-5s5.2 1.5 6 5"/><circle cx="17" cy="9" r="2.5"/><path d="M16 14.5c2.5 0 4.3 1.5 5 4.5"/>',
    esci: '<path d="M15 4h4a1 1 0 0 1 1 1v14a1 1 0 0 1-1 1h-4M10 16l-4-4 4-4M6 12h10"/>'
  };

  // GitHub Pages serve la stessa pagina anche senza ".html": si normalizza
  var paginaCorrente = location.pathname.split('/').pop() || 'index.html';
  if (!/\.html$/.test(paginaCorrente)) paginaCorrente += '.html';
  var PAGINE_AREA = ['area-privata.html','area-profilo.html','area-cani.html','area-prenotazioni.html','area-passeggiate.html',
    'area-staff.html','staff-prenotazioni.html','staff-nuova-prenotazione.html','staff-passeggiate.html','staff-utenti.html'];

  function voce(href, icona, testo, idConta){
    return '<a href="' + href + '" role="menuitem"' + (href === paginaCorrente ? ' class="attiva" aria-current="page"' : '') + '>' +
      '<svg viewBox="0 0 24 24" aria-hidden="true">' + ICONE[icona] + '</svg>' + testo +
      (idConta ? '<span class="conta" data-conta="' + idConta + '" hidden></span>' : '') + '</a>';
  }

  function costruisciMenu(ctx){
    var segnaposti = document.querySelectorAll('.site-header .nav-account');
    if (!segnaposti.length) return;
    var p = ctx.profilo;
    var nome = nomeCompleto(p) || ctx.utente.email;
    var iniziale = (p.nome || ctx.utente.email || '?').charAt(0).toUpperCase();
    var staff = eStaff(p);

    var wrap = document.createElement('div');
    wrap.className = 'conto-wrap';
    wrap.innerHTML =
      '<button type="button" class="conto-btn' + (PAGINE_AREA.indexOf(paginaCorrente) !== -1 ? ' active' : '') + '" aria-haspopup="true" aria-expanded="false" aria-controls="menu-conto" aria-label="Il mio conto">' +
        '<span class="conto-iniziale" aria-hidden="true">' + escapeHtml(iniziale) + '</span>' +
        '<span class="conto-punto" hidden></span>' +
      '</button>' +
      '<div class="menu-conto" id="menu-conto" role="menu" hidden>' +
        '<div class="chi"><span class="conto-iniziale" aria-hidden="true">' + escapeHtml(iniziale) + '</span>' +
          '<div><b>' + escapeHtml(nome) + '</b><small>' + escapeHtml(ctx.utente.email) + '</small></div></div>' +
        '<div class="gruppo">Il mio conto</div>' +
        voce('area-privata.html', 'panoramica', 'Panoramica', 'totale-cliente') +
        voce('area-profilo.html', 'profilo', 'Profilo e password', 'profilo') +
        voce('area-cani.html', 'cani', 'I miei cani', 'cani') +
        voce('area-prenotazioni.html', 'calendario', 'Pensione e asilo', 'acconti') +
        voce('area-passeggiate.html', 'luogo', 'Passeggiate') +
        (staff ?
          '<div class="gruppo">Staff</div>' +
          voce('area-staff.html', 'oggi', 'Oggi') +
          voce('staff-prenotazioni.html', 'elenco', 'Prenotazioni', 'staff') +
          voce('staff-nuova-prenotazione.html', 'piu', 'Nuova prenotazione') +
          voce('staff-passeggiate.html', 'luogo', 'Uscite in programma') +
          (p.ruolo === 'admin' ? voce('staff-utenti.html', 'persone', 'Clienti e ruoli') : '')
        : '') +
        '<hr><button type="button" class="voce" role="menuitem" data-esci><svg viewBox="0 0 24 24" aria-hidden="true">' + ICONE.esci + '</svg>Esci</button>' +
      '</div>';

    // il primo segnaposto diventa il pulsante; eventuali altri spariscono
    segnaposti[0].parentNode.replaceChild(wrap, segnaposti[0]);
    // ricordata per le prossime pagine: lo script in testa la mostra subito,
    // senza il lampo dell'omino in attesa della sessione
    try { localStorage.setItem(CHIAVE_INIZIALE, iniziale); } catch (e) {}
    for (var i = 1; i < segnaposti.length; i++) segnaposti[i].parentNode.removeChild(segnaposti[i]);

    var btn = wrap.querySelector('.conto-btn');
    var menu = wrap.querySelector('.menu-conto');
    function apri(si){
      if (si) {
        var testata = document.querySelector('.site-header');
        if (testata) document.documentElement.style.setProperty('--menu-conto-top', (testata.getBoundingClientRect().bottom + 8) + 'px');
        // chiude l'hamburger, se aperto, lasciando coerente il suo pulsante
        if (document.body.classList.contains('menu-aperto') && hamburger) {
          document.body.classList.remove('menu-aperto');
          hamburger.setAttribute('aria-expanded', 'false');
          hamburger.setAttribute('aria-label', 'Apri il menu');
        }
      }
      menu.hidden = !si;
      btn.setAttribute('aria-expanded', si ? 'true' : 'false');
    }
    var hamburger = document.getElementById('apri-menu');
    btn.addEventListener('click', function(e){ e.stopPropagation(); apri(menu.hidden); });
    document.addEventListener('click', function(e){ if (!wrap.contains(e.target)) apri(false); });
    document.addEventListener('keydown', function(e){ if (e.key === 'Escape' || e.key === 'Esc') apri(false); });
    if (hamburger) hamburger.addEventListener('click', function(){ apri(false); });
    wrap.querySelector('[data-esci]').addEventListener('click', function(){
      dimenticaIniziale();
      sb.auth.signOut().then(function(){ window.location.href = 'area-privata.html'; });
    });

    aggiornaConteggi(ctx);
  }

  function imposta(chiave, n, neutra){
    var el = document.querySelector('.menu-conto [data-conta="' + chiave + '"]');
    if (!el) return;
    el.hidden = !n;
    el.textContent = n || '';
    el.classList.toggle('neutra', !!neutra);
  }

  function aggiornaConteggi(ctx){
    ctx = ctx || ultimoCtx;
    if (!ctx) return Promise.resolve();
    var uid = ctx.utente.id;
    var testa = { count: 'exact', head: true };
    var richieste = [
      sb.from('profili').select('*').eq('id', uid).single(),
      sb.from('animali').select('id', testa).eq('proprietario_id', uid),
      sb.from('prenotazioni').select('id', testa).eq('cliente_id', uid).eq('stato', 'in_attesa_pagamento')
    ];
    if (eStaff(ctx.profilo)) {
      var ultima = ultimaVisitaStaff();
      richieste.push(sb.from('prenotazioni').select('id', testa).eq('stato', 'confermata').eq('disdetta_richiesta', true));
      richieste.push(ultima ? sb.from('prenotazioni').select('id', testa).gt('creato_il', ultima) : Promise.resolve({ count: 0 }));
    }
    return Promise.all(richieste).then(function(r){
      if (r[0].data) ctx.profilo = r[0].data;
      var profiloDaFare = campiMancanti(ctx.profilo).length ? 1 : 0;
      var cani = r[1].count || 0;
      var acconti = r[2].count || 0;
      var staff = r.length > 3 ? (r[3].count || 0) + (r[4].count || 0) : 0;
      var totaleCliente = profiloDaFare + acconti + (cani ? 0 : 1);
      imposta('profilo', profiloDaFare ? '!' : 0);
      imposta('cani', cani, true);
      imposta('acconti', acconti);
      imposta('totale-cliente', totaleCliente);
      imposta('staff', staff);
      var punto = document.querySelector('.conto-punto');
      if (punto) {
        var tot = totaleCliente + staff;
        punto.hidden = !tot;
        punto.textContent = tot > 9 ? '9+' : String(tot);
      }
    });
  }

  var ultimoCtx = null;
  sessione.then(function(ctx){
    if (!ctx) { dimenticaIniziale(); return; }
    ultimoCtx = ctx;
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', function(){ costruisciMenu(ctx); });
    } else {
      costruisciMenu(ctx);
    }
  });

  // ---------- protezione delle pagine ----------
  // opzioni: { staff: true } solo addetti e admin, { admin: true } solo admin.
  // La pagina deve avere #area-corpo (nascosto) e, se è per lo staff,
  // #area-vietato (nascosto). callback(ctx) parte quando è tutto pronto.
  function pagina(opzioni, callback){
    opzioni = opzioni || {};
    sessione.then(function(ctx){
      if (!ctx) {
        window.location.replace('area-privata.html?torna=' + encodeURIComponent(paginaCorrente));
        return;
      }
      var ruolo = ctx.profilo.ruolo;
      var permesso = opzioni.admin ? ruolo === 'admin' : (opzioni.staff ? eStaff(ctx.profilo) : true);
      var attesa = document.getElementById('area-attesa');
      if (attesa) attesa.hidden = true;
      if (!permesso) {
        var vietato = document.getElementById('area-vietato');
        if (vietato) vietato.hidden = false;
        return;
      }
      document.getElementById('area-corpo').hidden = false;
      sb.auth.onAuthStateChange(function(evento){
        if (evento === 'SIGNED_OUT') window.location.replace('area-privata.html');
      });
      callback(ctx);
    });
  }

  window.CroceviaArea = {
    sb: sb,
    sessione: sessione,
    pagina: pagina,
    aggiornaConteggi: aggiornaConteggi,
    escapeHtml: escapeHtml,
    euro: euro,
    avviso: avviso,
    dataLocale: dataLocale,
    isoLocale: isoLocale,
    oggiIso: oggiIso,
    traGiorni: traGiorni,
    giorniTra: giorniTra,
    formattaData: formattaData,
    intervallo: intervallo,
    durata: durata,
    telefonoLink: telefonoLink,
    nomeCompleto: nomeCompleto,
    campiMancanti: campiMancanti,
    eStaff: eStaff,
    ultimaVisitaStaff: ultimaVisitaStaff,
    segnaVisitaStaff: segnaVisitaStaff,
    avviaPagamento: avviaPagamento,
    CAPIENZA_PASSEGGIATA: CAPIENZA_PASSEGGIATA,
    etichetteStato: {
      in_attesa_pagamento: 'In attesa di pagamento',
      confermata: 'Confermata',
      completata: 'Completata',
      annullata: 'Annullata'
    }
  };
})();
