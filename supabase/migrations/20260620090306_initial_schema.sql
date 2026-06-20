create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create table public.content_items (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('meditation', 'practice', 'channeling', 'video', 'recommendation')),
  status text not null default 'draft' check (status in ('draft', 'published', 'archived')),
  title text not null check (char_length(trim(title)) between 1 and 120),
  author text,
  body text,
  external_url text check (external_url is null or external_url ~ '^https://'),
  cover_path text,
  duration_seconds integer not null default 0 check (duration_seconds >= 0),
  is_featured boolean not null default false,
  sort_order integer not null default 0,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.media_assets (
  id uuid primary key default gen_random_uuid(),
  content_id uuid not null references public.content_items(id) on delete cascade,
  kind text not null check (kind in ('audio', 'video')),
  storage_path text not null check (char_length(trim(storage_path)) > 0),
  mime_type text not null,
  bytes bigint check (bytes is null or bytes >= 0),
  duration_seconds integer check (duration_seconds is null or duration_seconds >= 0),
  created_at timestamptz not null default now(),
  unique (content_id, kind)
);

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text check (display_name is null or char_length(display_name) <= 80),
  design_direction text not null default 'umbral' check (design_direction in ('umbral', 'materia', 'mineral')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.favorites (
  user_id uuid not null references auth.users(id) on delete cascade,
  content_id uuid not null references public.content_items(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, content_id)
);

create table public.playback_progress (
  user_id uuid not null references auth.users(id) on delete cascade,
  content_id uuid not null references public.content_items(id) on delete cascade,
  position_seconds integer not null default 0 check (position_seconds >= 0),
  completed boolean not null default false,
  updated_at timestamptz not null default now(),
  primary key (user_id, content_id)
);

create table public.playback_sessions (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  content_id uuid not null references public.content_items(id) on delete cascade,
  started_at timestamptz not null,
  ended_at timestamptz,
  listened_seconds integer not null default 0 check (listened_seconds >= 0),
  completed boolean not null default false,
  created_at timestamptz not null default now(),
  check (ended_at is null or ended_at >= started_at)
);

create index content_items_catalog_idx
  on public.content_items (kind, status, sort_order, published_at desc);
create index content_items_featured_idx
  on public.content_items (is_featured, status, sort_order)
  where is_featured = true;
create index media_assets_content_idx on public.media_assets (content_id);
create index playback_sessions_user_started_idx
  on public.playback_sessions (user_id, started_at desc);

create or replace function private.set_updated_at()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger content_items_set_updated_at
before update on public.content_items
for each row execute function private.set_updated_at();
create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function private.set_updated_at();
create trigger favorites_set_updated_at
before update on public.favorites
for each row execute function private.set_updated_at();
create trigger playback_progress_set_updated_at
before update on public.playback_progress
for each row execute function private.set_updated_at();

create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
begin
  insert into public.profiles (id) values (new.id)
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function private.handle_new_user();

create or replace function private.validate_content_publication()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
begin
  if new.status <> 'published' then
    return new;
  end if;

  if new.cover_path is null or trim(new.cover_path) = '' then
    raise exception 'Published content requires a cover';
  end if;

  if new.published_at is null then
    new.published_at = now();
  end if;

  if new.kind in ('meditation', 'practice', 'channeling') and not exists (
    select 1 from public.media_assets
    where content_id = new.id and kind = 'audio'
  ) then
    raise exception 'Published audio content requires an audio asset';
  end if;

  if new.kind = 'video' and not exists (
    select 1 from public.media_assets
    where content_id = new.id and kind = 'video'
  ) then
    raise exception 'Published video content requires a video asset';
  end if;

  if new.kind = 'recommendation'
     and coalesce(trim(new.body), '') = ''
     and new.external_url is null then
    raise exception 'Published recommendations require body or external URL';
  end if;

  return new;
end;
$$;

create trigger content_items_validate_publication
before insert or update of status, cover_path, body, external_url
on public.content_items
for each row execute function private.validate_content_publication();

alter table public.content_items enable row level security;
alter table public.media_assets enable row level security;
alter table public.profiles enable row level security;
alter table public.favorites enable row level security;
alter table public.playback_progress enable row level security;
alter table public.playback_sessions enable row level security;

revoke all on public.content_items from anon, authenticated;
revoke all on public.media_assets from anon, authenticated;
revoke all on public.profiles from anon, authenticated;
revoke all on public.favorites from anon, authenticated;
revoke all on public.playback_progress from anon, authenticated;
revoke all on public.playback_sessions from anon, authenticated;

grant usage on schema public to authenticated;
grant select on public.content_items, public.media_assets to authenticated;
grant select, insert, update on public.profiles to authenticated;
grant select, insert, update, delete on public.favorites to authenticated;
grant select, insert, update, delete on public.playback_progress to authenticated;
grant select, insert on public.playback_sessions to authenticated;

create policy content_items_read_published
on public.content_items for select to authenticated
using (status = 'published');

create policy media_assets_read_published
on public.media_assets for select to authenticated
using (exists (
  select 1 from public.content_items
  where content_items.id = media_assets.content_id
    and content_items.status = 'published'
));

create policy profiles_read_own
on public.profiles for select to authenticated
using ((select auth.uid()) is not null and (select auth.uid()) = id);
create policy profiles_insert_own
on public.profiles for insert to authenticated
with check ((select auth.uid()) is not null and (select auth.uid()) = id);
create policy profiles_update_own
on public.profiles for update to authenticated
using ((select auth.uid()) is not null and (select auth.uid()) = id)
with check ((select auth.uid()) is not null and (select auth.uid()) = id);

create policy favorites_read_own
on public.favorites for select to authenticated
using ((select auth.uid()) is not null and (select auth.uid()) = user_id);
create policy favorites_insert_own
on public.favorites for insert to authenticated
with check ((select auth.uid()) is not null and (select auth.uid()) = user_id);
create policy favorites_update_own
on public.favorites for update to authenticated
using ((select auth.uid()) is not null and (select auth.uid()) = user_id)
with check ((select auth.uid()) is not null and (select auth.uid()) = user_id);
create policy favorites_delete_own
on public.favorites for delete to authenticated
using ((select auth.uid()) is not null and (select auth.uid()) = user_id);

create policy progress_read_own
on public.playback_progress for select to authenticated
using ((select auth.uid()) is not null and (select auth.uid()) = user_id);
create policy progress_insert_own
on public.playback_progress for insert to authenticated
with check ((select auth.uid()) is not null and (select auth.uid()) = user_id);
create policy progress_update_own
on public.playback_progress for update to authenticated
using ((select auth.uid()) is not null and (select auth.uid()) = user_id)
with check ((select auth.uid()) is not null and (select auth.uid()) = user_id);
create policy progress_delete_own
on public.playback_progress for delete to authenticated
using ((select auth.uid()) is not null and (select auth.uid()) = user_id);

create policy sessions_read_own
on public.playback_sessions for select to authenticated
using ((select auth.uid()) is not null and (select auth.uid()) = user_id);
create policy sessions_insert_own
on public.playback_sessions for insert to authenticated
with check ((select auth.uid()) is not null and (select auth.uid()) = user_id);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('covers', 'covers', true, 10485760, array['image/jpeg', 'image/png', 'image/webp']),
  ('media', 'media', false, 524288000, array['audio/mpeg', 'audio/mp4', 'audio/x-m4a', 'video/mp4'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy media_objects_read_published
on storage.objects for select to authenticated
using (
  bucket_id = 'media'
  and exists (
    select 1 from public.content_items
    where content_items.id::text = (storage.foldername(name))[1]
      and content_items.status = 'published'
  )
);

comment on schema private is 'Non-exposed trigger and privileged functions';
comment on table public.content_items is 'Editorial catalogue; mobile clients can only read published rows';
comment on table public.media_assets is 'Private media metadata; objects use content UUID as first folder';
