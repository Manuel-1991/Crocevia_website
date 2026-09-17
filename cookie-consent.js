/* Crocevia — banner di consenso cookie + Google Analytics 4, Google Ads
   e Meta Pixel (Consent Mode v2). File unico incluso in tutte le pagine:
   un solo punto da aggiornare. */
(function () {
  "use strict";

  var GA_MEASUREMENT_ID = "G-423CC11GJD";
  var GOOGLE_ADS_ID = ""; // TODO: AW-XXXXXXXXX (Google Ads → Strumenti → Conversioni)
  var META_PIXEL_ID = ""; // TODO: ID numerico del Meta Pixel (Meta Events Manager → Origini dati)
  var STORAGE_KEY = "cc_consent_v1";

  function readConsent() {
    try {
      var raw = localStorage.getItem(STORAGE_KEY);
      return raw ? JSON.parse(raw) : null;
    } catch (e) {
      return null;
    }
  }

  function writeConsent(consent) {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(consent));
    } catch (e) {}
  }

  window.dataLayer = window.dataLayer || [];
  function gtag() { window.dataLayer.push(arguments); }
  window.gtag = window.gtag || gtag;

  // Consent Mode v2: nega tutto finché l'utente non sceglie.
  gtag("consent", "default", {
    analytics_storage: "denied",
    ad_storage: "denied",
    ad_user_data: "denied",
    ad_personalization: "denied",
    wait_for_update: 500
  });

  var gaLoaded = false;
  function loadGA() {
    if (gaLoaded) return;
    if (!GA_MEASUREMENT_ID) return;
    gaLoaded = true;
    var s = document.createElement("script");
    s.async = true;
    s.src = "https://www.googletagmanager.com/gtag/js?id=" + GA_MEASUREMENT_ID;
    document.head.appendChild(s);
    gtag("js", new Date());
    gtag("config", GA_MEASUREMENT_ID, { anonymize_ip: true });
  }

  function applyConsent(consent) {
    gtag("consent", "update", {
      analytics_storage: consent.statistiche ? "granted" : "denied"
    });
    if (consent.statistiche) loadGA();
  }

  var saved = readConsent();
  if (saved) applyConsent(saved);

  window.CroceviaConsent = {
    // Da chiamare per tracciare un evento (es. invio modulo prenotazione).
    // Non fa nulla se l'utente non ha acconsentito alle statistiche.
    trackEvent: function (name, params) {
      var c = readConsent();
      if (c && c.statistiche && window.gtag) gtag("event", name, params || {});
    },
    openPreferences: function () { showBanner(true); }
  };

  // ---------- UI ----------

  var STYLE_ID = "cc-style";
  function injectStyle() {
    if (document.getElementById(STYLE_ID)) return;
    var css =
      ".cc-banner{position:fixed;left:0;right:0;bottom:0;z-index:40;" +
      "background:var(--surface,#24352a);border-top:1px solid var(--border,#3e4a31);" +
      "box-shadow:0 -8px 24px rgba(0,0,0,.35);font-family:\"EB Garamond\",Georgia,serif;}" +
      ".cc-banner.cc-hidden{display:none;}" +
      "@media (max-width:999px){.cc-banner{bottom:calc(var(--barra,56px) + env(safe-area-inset-bottom));}}" +
      ".cc-inner{max-width:780px;margin:0 auto;padding:18px 22px;}" +
      ".cc-text{font-size:15px;line-height:1.5;margin:0 0 14px;color:var(--ink,#f4f1e4);}" +
      ".cc-text a{color:var(--terracotta,#c38345);border-bottom:1px solid currentColor;}" +
      ".cc-panel{display:none;margin:0 0 14px;padding:4px 14px;border:1px solid var(--border-soft,rgba(62,74,49,.55));border-radius:4px;background:var(--surface-soft,rgba(36,53,42,.55));}" +
      ".cc-panel.cc-open{display:block;}" +
      ".cc-row{display:flex;align-items:center;justify-content:space-between;gap:14px;padding:10px 0;}" +
      ".cc-row + .cc-row{border-top:1px solid var(--border-soft,rgba(62,74,49,.55));}" +
      ".cc-row .cc-label{display:block;font-family:\"Cinzel\",serif;font-size:12px;letter-spacing:.05em;text-transform:uppercase;color:var(--ink,#f4f1e4);}" +
      ".cc-row .cc-desc{display:block;font-size:13.5px;color:var(--ink-muted,#b2bfb3);margin-top:3px;}" +
      ".cc-row input{flex:none;width:18px;height:18px;accent-color:var(--gold,#c38345);}" +
      ".cc-actions{display:flex;flex-wrap:wrap;gap:10px;}" +
      ".cc-btn{font-family:\"Cinzel\",serif;font-weight:600;font-size:12.5px;letter-spacing:.05em;" +
      "text-transform:uppercase;padding:11px 20px;border-radius:3px;cursor:pointer;border:1px solid var(--border,#3e4a31);background:transparent;color:var(--ink,#f4f1e4);}" +
      ".cc-btn.cc-primary{background:var(--gold,#c38345);border-color:var(--gold,#c38345);color:#1a1005;}" +
      ".cc-btn:focus-visible{outline:2px solid var(--gold,#c38345);outline-offset:2px;}";
    var style = document.createElement("style");
    style.id = STYLE_ID;
    style.textContent = css;
    document.head.appendChild(style);
  }

  var banner = null;
  function buildBanner() {
    if (banner) return banner;
    injectStyle();
    banner = document.createElement("div");
    banner.className = "cc-banner cc-hidden";
    banner.setAttribute("role", "dialog");
    banner.setAttribute("aria-live", "polite");
    banner.setAttribute("aria-label", "Preferenze cookie");
    banner.innerHTML =
      '<div class="cc-inner">' +
        '<p class="cc-text">Uso <b>Google Analytics</b> solo per capire come viene usato il sito, e solo se acconsenti. Puoi cambiare idea in ogni momento da &quot;Gestisci cookie&quot; in fondo alla pagina. <a href="privacy.html#terzi">Leggi di pi&ugrave;</a>.</p>' +
        '<div class="cc-panel" id="cc-panel">' +
          '<label class="cc-row"><span><span class="cc-label">Necessari</span><span class="cc-desc">Sempre attivi: servono al funzionamento del sito.</span></span><input type="checkbox" checked disabled></label>' +
          '<label class="cc-row"><span><span class="cc-label">Statistiche</span><span class="cc-desc">Google Analytics, solo con il tuo consenso.</span></span><input type="checkbox" id="cc-stat"></label>' +
        "</div>" +
        '<div class="cc-actions">' +
          '<button type="button" class="cc-btn" id="cc-reject">Rifiuta</button>' +
          '<button type="button" class="cc-btn" id="cc-customize">Personalizza</button>' +
          '<button type="button" class="cc-btn" id="cc-save" style="display:none;">Salva preferenze</button>' +
          '<button type="button" class="cc-btn cc-primary" id="cc-accept">Accetta tutti</button>' +
        "</div>" +
      "</div>";
    document.body.appendChild(banner);

    banner.querySelector("#cc-customize").addEventListener("click", function () {
      banner.querySelector("#cc-panel").classList.add("cc-open");
      this.style.display = "none";
      banner.querySelector("#cc-save").style.display = "";
    });
    banner.querySelector("#cc-reject").addEventListener("click", function () { saveAndApply(false); });
    banner.querySelector("#cc-accept").addEventListener("click", function () { saveAndApply(true); });
    banner.querySelector("#cc-save").addEventListener("click", function () {
      saveAndApply(banner.querySelector("#cc-stat").checked);
    });
    return banner;
  }

  function saveAndApply(statistiche) {
    var consent = { necessari: true, statistiche: !!statistiche, ts: new Date().toISOString() };
    writeConsent(consent);
    applyConsent(consent);
    if (banner) banner.classList.add("cc-hidden");
  }

  function showBanner(reopenedFromFooter) {
    var el = buildBanner();
    var current = readConsent();
    if (reopenedFromFooter && current) {
      el.querySelector("#cc-stat").checked = !!current.statistiche;
      el.querySelector("#cc-panel").classList.add("cc-open");
      el.querySelector("#cc-customize").style.display = "none";
      el.querySelector("#cc-save").style.display = "";
    }
    el.classList.remove("cc-hidden");
  }

  document.addEventListener("DOMContentLoaded", function () {
    if (!readConsent()) showBanner(false);
    var link = document.getElementById("gestisci-cookie");
    if (link) {
      link.addEventListener("click", function (e) {
        e.preventDefault();
        showBanner(true);
      });
    }
  });
})();
