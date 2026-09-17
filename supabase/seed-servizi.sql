-- Crocevia — listino iniziale
-- Da eseguire una volta, dopo schema.sql, in Dashboard Supabase → SQL Editor.
-- Rieseguibile senza duplicare: cancella e ricrea il listino.

delete from servizi;

insert into servizi (categoria, nome, prezzo, unita_misura) values
  ('pensione',    'Stallo / Pensione',                        35.00, 'giorno'),
  ('asilo',       'Asilo diurno',                              25.00, 'giorno'),
  ('educazione',  'Valutazione cane (primo incontro)',         50.00, 'una_tantum'),
  ('educazione',  'Lezione individuale in presenza',           30.00, 'ora'),
  ('educazione',  'Lezione online',                            30.00, 'ora'),
  ('passeggiate', 'Passeggiata di gruppo',                     15.00, 'una_tantum');

-- Nota su pensione/asilo: il prezzo è per notte. Nel calendario lo sconto a
-- scaglioni si applica in automatico sul totale, stessa logica di oggi:
--   1-6 notti   → prezzo pieno
--   7-29 notti  → -10%
--   30+ notti   → -20%
-- (35€/gg → 840€ per 30 notti, 25€/gg → 600€ per 30 notti: torna con i
-- prezzi già pubblicati su pensione-asilo.html)

-- Educazione e passeggiate restano fuori dal calendario e dal pagamento
-- online (contatto diretto via WhatsApp, come oggi): questi prezzi sono nel
-- database solo per uniformità e per un domani, non li usa ancora nessuna pagina.
