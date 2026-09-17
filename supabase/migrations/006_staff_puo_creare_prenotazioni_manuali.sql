-- Permette a addetto/admin di creare una prenotazione per conto di un
-- cliente già registrato (es. chi telefona invece di usare il sito).
-- Si affianca alla policy esistente che permette al cliente di creare
-- solo prenotazioni proprie: le policy INSERT sono in OR tra loro.
-- Già applicata al progetto live.

create policy prenotazioni_insert_staff on prenotazioni for insert
  with check (ruolo_utente_corrente() in ('addetto', 'admin'));
