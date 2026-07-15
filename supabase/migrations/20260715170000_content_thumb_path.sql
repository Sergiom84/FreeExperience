-- Miniatura cuadrada independiente de la portada 4:5.
-- La app encuadra por separado el thumb (1:1) y la portada grande (4:5); esta
-- columna guarda la ruta de storage del recorte cuadrado. Nullable y
-- retrocompatible: el contenido ya publicado sigue mostrando cover_path
-- recortado en cliente hasta que se reedite.
alter table public.content_items
  add column if not exists thumb_path text;

comment on column public.content_items.thumb_path is
  'Ruta en el bucket covers del recorte cuadrado (1:1) para miniaturas. Si es null, la UI cae a cover_path.';
