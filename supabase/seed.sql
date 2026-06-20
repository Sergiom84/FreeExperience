insert into public.content_items
  (id, kind, status, title, author, body, external_url, cover_path, duration_seconds, is_featured, sort_order, published_at)
values
  ('10000000-0000-4000-8000-000000000001', 'meditation', 'draft', 'El espacio entre pensamientos', 'Lina Ávila', null, null, 'seed/meditation-01.webp', 1080, true, 10, now()),
  ('10000000-0000-4000-8000-000000000002', 'meditation', 'draft', 'Respirar sin esfuerzo', 'Lina Ávila', null, null, 'seed/meditation-02.webp', 540, false, 20, now()),
  ('10000000-0000-4000-8000-000000000003', 'meditation', 'draft', 'Quietud al anochecer', 'Noa Beltrán', null, null, 'seed/meditation-03.webp', 840, false, 30, now()),
  ('20000000-0000-4000-8000-000000000001', 'practice', 'draft', 'Presencia en movimiento', 'Mara Salvat', null, null, 'seed/practice-01.webp', 720, true, 10, now()),
  ('20000000-0000-4000-8000-000000000002', 'practice', 'draft', 'La escucha profunda', 'Mara Salvat', null, null, 'seed/practice-02.webp', 900, false, 20, now()),
  ('30000000-0000-4000-8000-000000000001', 'channeling', 'draft', 'La calma que permanece', 'Noa Beltrán', null, null, 'seed/channeling-01.webp', 1140, true, 10, now()),
  ('30000000-0000-4000-8000-000000000002', 'channeling', 'draft', 'Umbral', 'Lina Ávila', null, null, 'seed/channeling-02.webp', 1260, false, 20, now()),
  ('40000000-0000-4000-8000-000000000001', 'video', 'draft', 'Respirar con el paisaje', 'Mara Salvat', null, null, 'seed/video-01.webp', 480, true, 10, now()),
  ('40000000-0000-4000-8000-000000000002', 'video', 'draft', 'Ritual de tarde', 'Noa Beltrán', null, null, 'seed/video-02.webp', 620, false, 20, now()),
  ('50000000-0000-4000-8000-000000000001', 'recommendation', 'published', 'El arte de detenerse', 'Free Experience', 'Una selección editorial para volver a un ritmo más humano.', 'https://example.com/el-arte-de-detenerse', 'seed/recommendation-01.webp', 0, true, 10, now()),
  ('50000000-0000-4000-8000-000000000002', 'recommendation', 'published', 'Escuchar antes de responder', 'Free Experience', 'Notas sobre atención, presencia y conversación.', 'https://example.com/escuchar', 'seed/recommendation-02.webp', 0, false, 20, now()),
  ('50000000-0000-4000-8000-000000000003', 'recommendation', 'published', 'Una habitación en silencio', 'Free Experience', 'Una lectura breve para el final del día.', 'https://example.com/habitacion-en-silencio', 'seed/recommendation-03.webp', 0, false, 30, now())
on conflict (id) do nothing;

insert into public.media_assets
  (content_id, kind, storage_path, mime_type, duration_seconds)
values
  ('10000000-0000-4000-8000-000000000001', 'audio', '10000000-0000-4000-8000-000000000001/audio.m4a', 'audio/mp4', 1080),
  ('10000000-0000-4000-8000-000000000002', 'audio', '10000000-0000-4000-8000-000000000002/audio.m4a', 'audio/mp4', 540),
  ('10000000-0000-4000-8000-000000000003', 'audio', '10000000-0000-4000-8000-000000000003/audio.m4a', 'audio/mp4', 840),
  ('20000000-0000-4000-8000-000000000001', 'audio', '20000000-0000-4000-8000-000000000001/audio.m4a', 'audio/mp4', 720),
  ('20000000-0000-4000-8000-000000000002', 'audio', '20000000-0000-4000-8000-000000000002/audio.m4a', 'audio/mp4', 900),
  ('30000000-0000-4000-8000-000000000001', 'audio', '30000000-0000-4000-8000-000000000001/audio.m4a', 'audio/mp4', 1140),
  ('30000000-0000-4000-8000-000000000002', 'audio', '30000000-0000-4000-8000-000000000002/audio.m4a', 'audio/mp4', 1260),
  ('40000000-0000-4000-8000-000000000001', 'video', '40000000-0000-4000-8000-000000000001/video.mp4', 'video/mp4', 480),
  ('40000000-0000-4000-8000-000000000002', 'video', '40000000-0000-4000-8000-000000000002/video.mp4', 'video/mp4', 620)
on conflict (content_id, kind) do nothing;

update public.content_items
set status = 'published'
where status = 'draft';

