-- Admin authoring layer: role table, helper functions, write policies (content, media, storage).
-- Additive: does not alter existing data or read policies.

-- 1) Admin role registry. Only service_role / SECURITY DEFINER functions may touch it.
create table public.admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.admins enable row level security;
revoke all on public.admins from anon, authenticated;

-- 2) is_admin(): callable inside RLS policies. SECURITY DEFINER so it can read
--    public.admins regardless of the caller's own RLS.
create or replace function public.is_admin()
returns boolean
language sql
security definer
stable
set search_path = pg_catalog, public
as $$
  select exists (
    select 1 from public.admins where user_id = (select auth.uid())
  );
$$;
revoke all on function public.is_admin() from public;
revoke execute on function public.is_admin() from anon;
grant execute on function public.is_admin() to authenticated;

-- 3) grant_admin(email): privileged helper to promote a user by email.
--    Lives in private schema => only service_role / MCP can call it.
create or replace function private.grant_admin(target_email text)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  uid uuid;
begin
  select id into uid from auth.users where lower(email) = lower(target_email);
  if uid is null then
    raise exception 'No auth user with email %', target_email;
  end if;
  insert into public.admins (user_id) values (uid)
  on conflict (user_id) do nothing;
  return uid;
end;
$$;

-- 4) Content write access for admins (read of published stays via existing policy;
--    this also grants admins read of drafts/archived).
grant insert, update, delete on public.content_items to authenticated;
grant insert, update, delete on public.media_assets to authenticated;

create policy content_items_admin_all
on public.content_items for all to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy media_assets_admin_all
on public.media_assets for all to authenticated
using (public.is_admin())
with check (public.is_admin());

-- 5) Storage: admins manage covers (public bucket) and media (private bucket),
--    and can read private media objects for preview/management.
create policy covers_admin_insert
on storage.objects for insert to authenticated
with check (bucket_id = 'covers' and public.is_admin());

create policy covers_admin_update
on storage.objects for update to authenticated
using (bucket_id = 'covers' and public.is_admin())
with check (bucket_id = 'covers' and public.is_admin());

create policy covers_admin_delete
on storage.objects for delete to authenticated
using (bucket_id = 'covers' and public.is_admin());

-- The storage API reads the object back after writing (RETURNING), so admins
-- need SELECT on covers too; the public flag only covers the anon read endpoint.
create policy covers_admin_read
on storage.objects for select to authenticated
using (bucket_id = 'covers' and public.is_admin());

create policy media_admin_read
on storage.objects for select to authenticated
using (bucket_id = 'media' and public.is_admin());

create policy media_admin_insert
on storage.objects for insert to authenticated
with check (bucket_id = 'media' and public.is_admin());

create policy media_admin_update
on storage.objects for update to authenticated
using (bucket_id = 'media' and public.is_admin())
with check (bucket_id = 'media' and public.is_admin());

create policy media_admin_delete
on storage.objects for delete to authenticated
using (bucket_id = 'media' and public.is_admin());

comment on table public.admins is 'Editorial admins; write access to catalogue and storage';
comment on function public.is_admin() is 'True when current auth user is an editorial admin';
