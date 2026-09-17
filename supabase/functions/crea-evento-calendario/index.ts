// Crea un evento su Google Calendar quando una prenotazione diventa
// "confermata". Chiamata dal database stesso (trigger + pg_net), mai
// direttamente dal sito: l'autenticazione è un segreto condiviso
// nell'header x-internal-secret, non un token utente.

import { createClient } from "npm:@supabase/supabase-js@2";

const ACCOUNT_SERVIZIO = JSON.parse(Deno.env.get("GOOGLE_SERVICE_ACCOUNT_JSON")!);
const ID_CALENDARIO = Deno.env.get("GOOGLE_CALENDAR_ID")!;
const SEGRETO_INTERNO = Deno.env.get("INTERNAL_WEBHOOK_SECRET")!;

function base64url(bytes: ArrayBuffer | string): string {
  var testo = typeof bytes === "string" ? bytes : String.fromCharCode(...new Uint8Array(bytes));
  return btoa(testo).replace(/=+$/, "").replace(/\+/g, "-").replace(/\//g, "_");
}

async function ottieniTokenGoogle(): Promise<string> {
  const ora = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const rivendicazione = {
    iss: ACCOUNT_SERVIZIO.client_email,
    scope: "https://www.googleapis.com/auth/calendar",
    aud: "https://oauth2.googleapis.com/token",
    exp: ora + 3600,
    iat: ora,
  };
  const senzaFirma = base64url(JSON.stringify(header)) + "." + base64url(JSON.stringify(rivendicazione));

  const chiavePem = (ACCOUNT_SERVIZIO.private_key as string)
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");
  const chiaveBytes = Uint8Array.from(atob(chiavePem), (c) => c.charCodeAt(0));
  const chiave = await crypto.subtle.importKey(
    "pkcs8",
    chiaveBytes.buffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const firma = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    chiave,
    new TextEncoder().encode(senzaFirma),
  );
  const jwt = senzaFirma + "." + base64url(firma);

  const risposta = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  const dati = await risposta.json();
  if (!risposta.ok) throw new Error("Token Google non ottenuto: " + JSON.stringify(dati));
  return dati.access_token;
}

function aggiungiGiorno(dataIso: string): string {
  const d = new Date(dataIso + "T00:00:00Z");
  d.setUTCDate(d.getUTCDate() + 1);
  return d.toISOString().slice(0, 10);
}

Deno.serve(async (req) => {
  if (req.headers.get("x-internal-secret") !== SEGRETO_INTERNO) {
    return new Response("non autorizzato", { status: 401 });
  }

  try {
    const { prenotazione_id } = await req.json();

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: p, error } = await supabase
      .from("prenotazioni")
      .select(
        "id, data_dal, data_al, prezzo_totale, acconto_importo, saldo_importo, evento_calendario_id, animali(nome), servizi(nome), profili(nome,cognome,telefono,email)",
      )
      .eq("id", prenotazione_id)
      .single();

    if (error || !p || p.evento_calendario_id) {
      return new Response(JSON.stringify({ skip: true }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    const cliente = p.profili ?? {};
    const nomeCliente = [cliente.nome, cliente.cognome].filter(Boolean).join(" ");
    const accessToken = await ottieniTokenGoogle();

    const evento = {
      summary: (p.servizi?.nome ?? "Prenotazione") + ": " + (p.animali?.nome ?? "") +
        (nomeCliente ? " (" + nomeCliente + ")" : ""),
      description:
        "Cliente: " + nomeCliente +
        (cliente.telefono ? "\nTelefono: " + cliente.telefono : "") +
        (cliente.email ? "\nEmail: " + cliente.email : "") +
        "\nTotale: " + p.prezzo_totale + " € · acconto: " + p.acconto_importo + " € · saldo: " + p.saldo_importo + " €",
      start: { date: p.data_dal },
      end: { date: aggiungiGiorno(p.data_al) },
    };

    const rispostaCalendario = await fetch(
      "https://www.googleapis.com/calendar/v3/calendars/" + encodeURIComponent(ID_CALENDARIO) + "/events",
      {
        method: "POST",
        headers: { Authorization: "Bearer " + accessToken, "Content-Type": "application/json" },
        body: JSON.stringify(evento),
      },
    );
    const eventoCreato = await rispostaCalendario.json();
    if (!rispostaCalendario.ok) throw new Error("Google Calendar: " + JSON.stringify(eventoCreato));

    await supabase
      .from("prenotazioni")
      .update({ evento_calendario_id: eventoCreato.id })
      .eq("id", prenotazione_id);

    return new Response(JSON.stringify({ ok: true, evento: eventoCreato.id }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (errore) {
    console.error(errore);
    return new Response(JSON.stringify({ error: String(errore) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
