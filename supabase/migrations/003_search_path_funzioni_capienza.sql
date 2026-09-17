-- Irrobustisce le funzioni della capienza contro un search_path manomesso
-- (segnalazione dell'advisor di sicurezza di Supabase). Non cambia il
-- comportamento, solo la sicurezza. Già applicata al progetto live.

create or replace function capienza_pensione_asilo()
returns int language sql immutable set search_path = public, pg_temp as $$ select 5 $$;

create or replace function controlla_capienza_pensione_asilo()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  categoria_riga text;
  giorno date;
  occupati int;
begin
  if new.stato not in ('in_attesa_pagamento','confermata') then
    return new;
  end if;

  select categoria into categoria_riga from servizi where id = new.servizio_id;
  if categoria_riga is null or categoria_riga not in ('pensione','asilo') then
    return new;
  end if;

  for giorno in select generate_series(new.data_dal, new.data_al, interval '1 day')::date loop
    select count(*) into occupati
    from prenotazioni p
    join servizi s on s.id = p.servizio_id
    where p.id <> new.id
      and s.categoria in ('pensione','asilo')
      and p.stato in ('in_attesa_pagamento','confermata')
      and daterange(p.data_dal, p.data_al, '[]') @> giorno;

    if occupati >= capienza_pensione_asilo() then
      raise exception 'Il % è già al completo (% cani)', giorno, capienza_pensione_asilo();
    end if;
  end loop;

  return new;
end;
$$;
