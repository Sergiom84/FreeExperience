begin;

create extension if not exists pgtap with schema extensions;
select plan(12);

select has_table('public', 'content_items', 'content_items existe');
select has_table('public', 'media_assets', 'media_assets existe');
select has_table('public', 'profiles', 'profiles existe');
select has_table('public', 'favorites', 'favorites existe');
select has_table('public', 'playback_progress', 'playback_progress existe');
select has_table('public', 'playback_sessions', 'playback_sessions existe');

select ok(
  (select relrowsecurity from pg_class where oid = 'public.content_items'::regclass),
  'content_items has RLS enabled'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.media_assets'::regclass),
  'media_assets has RLS enabled'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.profiles'::regclass),
  'profiles has RLS enabled'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.favorites'::regclass),
  'favorites has RLS enabled'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.playback_progress'::regclass),
  'playback_progress has RLS enabled'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.playback_sessions'::regclass),
  'playback_sessions has RLS enabled'
);

select * from finish();
rollback;
