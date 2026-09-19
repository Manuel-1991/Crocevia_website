// Riceve la conferma di pagamento da Stripe e aggiorna il database.
// Non usa l'autenticazione Supabase (Stripe non ha un token utente): la
// sicurezza sta nella firma verificata con STRIPE_WEBHOOK_SECRET, per
// questo la funzione va distribuita con verify_jwt disattivato.

import Stripe from "npm:stripe";
import { createClient } from "npm:@supabase/supabase-js@2";

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY")!);
const webhookSecret = Deno.env.get("STRIPE_WEBHOOK_SECRET")!;

Deno.serve(async (req) => {
  const firma = req.headers.get("stripe-signature");
  const corpo = await req.text();

  let evento: Stripe.Event;
  try {
    evento = await stripe.webhooks.constructEventAsync(corpo, firma!, webhookSecret);
  } catch (errore) {
    console.error("Firma webhook non valida:", (errore as Error).message);
    return new Response("Firma non valida", { status: 400 });
  }

  if (evento.type === "checkout.session.completed") {
    const session = evento.data.object as Stripe.Checkout.Session;
    const prenotazioneId = session.metadata?.prenotazione_id;
    const tipo = session.metadata?.tipo;

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    await supabase
      .from("pagamenti")
      .update({ stato: "pagato", pagato_il: new Date().toISOString() })
      .eq("stripe_payment_id", session.id);

    if (prenotazioneId && tipo === "acconto") {
      await supabase
        .from("prenotazioni")
        .update({ stato: "confermata", acconto_pagato_il: new Date().toISOString() })
        .eq("id", prenotazioneId);
    } else if (prenotazioneId && tipo === "saldo") {
      await supabase
        .from("prenotazioni")
        .update({ saldo_pagato_il: new Date().toISOString() })
        .eq("id", prenotazioneId);
    } else if (prenotazioneId && tipo === "completo") {
      const adesso = new Date().toISOString();
      await supabase
        .from("prenotazioni")
        .update({ stato: "confermata", acconto_pagato_il: adesso, saldo_pagato_il: adesso })
        .eq("id", prenotazioneId);
    }
  }

  return new Response(JSON.stringify({ received: true }), {
    headers: { "Content-Type": "application/json" },
  });
});
