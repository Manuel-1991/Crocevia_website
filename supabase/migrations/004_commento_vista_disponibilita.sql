-- Documenta nel database stesso perché la vista bypassa volutamente le RLS
-- di prenotazioni: l'advisor di sicurezza di Supabase la segnala come
-- "Security Definer View", ma qui è intenzionale (vedi commento). Già
-- applicata al progetto live.

comment on view disponibilita_pensione_asilo is
  'Bypassa volutamente le RLS di prenotazioni (mostra le date occupate di TUTTI i clienti, non solo di chi guarda): serve al calendario di disponibilità condiviso. Espone solo categoria e date, mai dati personali. Non cambiare a security_invoker: romperebbe il calendario.';
