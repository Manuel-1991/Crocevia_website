-- Aggiunge il tipo 'completo' ai pagamenti: il cliente può scegliere, già
-- alla prenotazione di stallo/pensione/asilo, di saldare acconto e saldo
-- insieme in un'unica transazione Stripe, invece di pagare solo il 10% e
-- il resto alla fine del soggiorno.
--
-- acconto_importo e saldo_importo restano calcolati come sempre da
-- calcola_importi_prenotazione() (servono comunque a sapere quanto vale la
-- caparra ai fini della politica di rimborso): crea-pagamento somma i due
-- per l'importo del pagamento "completo", e stripe-webhook valorizza sia
-- acconto_pagato_il sia saldo_pagato_il alla conferma.

alter table pagamenti drop constraint if exists pagamenti_tipo_check;
alter table pagamenti add constraint pagamenti_tipo_check
  check (tipo in ('acconto', 'saldo', 'completo'));
