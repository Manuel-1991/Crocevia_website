-- Le passeggiate non si svolgono più in un luogo fisso: il riferimento al
-- bosco di Campagnola diventa un generico "Lago Maggiore" (uscite sul lago).

alter table passeggiate alter column luogo set default 'Lago Maggiore';

update passeggiate
   set luogo = 'Lago Maggiore'
 where luogo ilike '%campagnola%';
