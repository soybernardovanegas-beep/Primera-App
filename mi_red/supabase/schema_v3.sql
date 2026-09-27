-- Mi Red v3: borrado de datos y de cuenta desde la app (requisito de
-- Google Play para apps que permiten crear cuentas).
-- Ejecutar DESPUÉS de schema.sql y schema_v2.sql, en Supabase -> SQL Editor.
-- Se puede ejecutar más de una vez.

-- Borra todos los datos de Mi Red del usuario que llama, sin tocar su
-- cuenta ni los datos de otras apps del mismo proyecto.
create or replace function public.delete_my_crm_data()
returns void
language plpgsql
security invoker
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'No autenticado';
  end if;
  delete from public.crm_interactions where user_id = auth.uid();
  delete from public.crm_reminders where user_id = auth.uid();
  delete from public.crm_sales where user_id = auth.uid();
  delete from public.crm_contacts where user_id = auth.uid();
  delete from public.crm_guides where user_id = auth.uid();
  delete from public.crm_profile where user_id = auth.uid();
end;
$$;

-- Elimina la cuenta del usuario que llama. Todas las tablas que apuntan a
-- auth.users con "on delete cascade" se borran con ella (incluidas las de
-- otras apps que usen este mismo proyecto de Supabase).
-- security definer: borrar de auth.users requiere permisos de administrador;
-- la función solo puede borrar la fila del propio usuario (auth.uid()).
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'No autenticado';
  end if;
  delete from auth.users where id = uid;
end;
$$;

revoke all on function public.delete_my_crm_data() from public, anon;
revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_crm_data() to authenticated;
grant execute on function public.delete_my_account() to authenticated;
