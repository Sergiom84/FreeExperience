-- Añade 'intro' como valor válido en content_items.kind.
-- Este tipo almacena el audio de bienvenida que se reproduce al pulsar el sol
-- en la pantalla WelcomeSunsetScreen.

alter table public.content_items
  drop constraint content_items_kind_check,
  add constraint content_items_kind_check
    check (kind in ('meditation', 'practice', 'channeling', 'video', 'recommendation', 'intro'));

-- Actualiza el trigger de validación para exigir audio en contenido 'intro'
-- publicado, igual que con los demás tipos de audio.
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

  if new.kind in ('meditation', 'practice', 'channeling', 'intro') and not exists (
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
