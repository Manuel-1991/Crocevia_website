// Crea una sessione di pagamento Stripe per l'acconto o il saldo di una
// prenotazione. Richiede un utente autenticato (verify_jwt attivo): usa il
// suo stesso token per leggere la prenotazione, così le RLS garantiscono
// che non possa pagare (o vedere) prenotazioni di qualcun altro.

import Stripe from "npm:stripe";
import { createClient } from "npm:@supabase/supabase-js@2";

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY")!);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function risposta(corpo: unknown, status = 200) {
  return new Response(JSON.stringify(corpo), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return risposta({ error: "Accesso richiesto." }, 401);

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const supabaseUtente = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: { user }, error: erroreUtente } = await supabaseUtente.auth.getUser();
    if (erroreUtente || !user) return risposta({ error: "Sessione non valida." }, 401);

    const { prenotazione_id, tipo } = await req.json();
    if (!prenotazione_id || !["acconto", "saldo"].includes(tipo)) {
      return risposta({ error: "Richiesta non valida." }, 400);
    }

    const { data: prenotazione, error: erroreLettura } = await supabaseUtente
      .from("prenotazioni")
      .select("id, stato, acconto_importo, acconto_pagato_il, saldo_importo, saldo_pagato_il, servizi(nome), animali(nome)")
      .eq("id", prenotazione_id)
      .single();

    if (erroreLettura || !prenotazione) return risposta({ error: "Prenotazione non trovata." }, 404);

    let importo: number, descrizione: string;
    if (tipo === "acconto") {
      if (prenotazione.stato !== "in_attesa_pagamento" || prenotazione.acconto_pagato_il) {
        return risposta({ error: "L'acconto non risulta dovuto per questa prenotazione." }, 409);
      }
      importo = Number(prenotazione.acconto_importo);
      descrizione = "Acconto " + (prenotazione.servizi?.nome ?? "prenotazione") + " — " + (prenotazione.animali?.nome ?? "");
    } else {
      if (prenotazione.stato !== "confermata" || prenotazione.saldo_pagato_il) {
        return risposta({ error: "Il saldo non risulta dovuto per questa prenotazione." }, 409);
      }
      importo = Number(prenotazione.saldo_importo);
      descrizione = "Saldo " + (prenotazione.servizi?.nome ?? "prenotazione") + " — " + (prenotazione.animali?.nome ?? "");
    }

    if (!importo || importo <= 0) return risposta({ error: "Importo non valido." }, 400);

    const origine = req.headers.get("origin") || "https://croceviacani.it";

    const session = await stripe.checkout.sessions.create({
      mode: "payment",
      payment_method_types: ["card"],
      customer_email: user.email,
      line_items: [{
        price_data: {
          currency: "eur",
          unit_amount: Math.round(importo * 100),
          product_data: { name: descrizione },
        },
        quantity: 1,
      }],
      metadata: { prenotazione_id, tipo },
      success_url: origine + "/area-privata.html?pagamento=riuscito",
      cancel_url: origine + "/area-privata.html?pagamento=annullato",
    });

    const supabaseServizio = createClient(supabaseUrl, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    await supabaseServizio.from("pagamenti").insert({
      prenotazione_id,
      tipo,
      importo,
      stripe_payment_id: session.id,
      stato: "in_attesa",
    });

    return risposta({ url: session.url });
  } catch (errore) {
    console.error(errore);
    return risposta({ error: "Errore interno." }, 500);
  }
});
