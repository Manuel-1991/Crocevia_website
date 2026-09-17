-- L'email è l'unico identificativo di accesso (nessun nome utente
-- separato in questo sistema). Se cambia in auth.users, questo trigger
-- tiene allineata la copia in profili usata per mostrare i dati senza
-- dover interrogare la parte protetta di Supabase.
-- Già applicata al progetto live, verificata con un utente di prova.

create or replace function sincronizza_email_profilo()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.email is distinct from old.email then
    update profili set email = new.email where id = new.id;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_sincronizza_email_profilo on auth.users;
create trigger trg_sincronizza_email_profilo
  after update of email on auth.users
  for each row execute function sincronizza_email_profilo();
