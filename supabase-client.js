/* Client Supabase condiviso dalle pagine dell'area privata.
   La chiave qui sotto è quella "pubblicabile": è fatta apposta per stare
   nel codice del sito, non dà accesso oltre a quello che le regole del
   database (RLS) permettono a un utente non autenticato o autenticato. */
window.CroceviaSupabase = supabase.createClient(
  'https://gcjxhgvghncjjvcnacbv.supabase.co',
  'sb_publishable_sOjgcoZOrz_cLo6fHcy8jg_QnsxGqqx'
);
