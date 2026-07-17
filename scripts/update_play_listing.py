# -*- coding: utf-8 -*-
"""Actualiza el listing de Play Store: titulo, descripciones (SoulKey) e
imagenes (icono + feature graphic). Uso puntual, no forma parte del pipeline
de releases (scripts/publish_play.py se encarga de eso).

Uso:
  python scripts/update_play_listing.py
"""
import os

from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

PACKAGE_NAME = "com.freeexperience.free_experience"
DEFAULT_KEY_PATH = os.path.expanduser("~/.play-publish-keys/free-experience.json")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICON_PATH = os.path.join(ROOT, "assets", "Google", "play", "icon_512.png")
FEATURE_PATH = os.path.join(ROOT, "assets", "Google", "play", "feature_1024x500.png")
SCOPES = ["https://www.googleapis.com/auth/androidpublisher"]

SHORT_DESCRIPTION = (
    "Meditaciones, prácticas, canalizaciones e inspiración para tu día a día."
)

FULL_DESCRIPTION = (
    "SoulKey reúne meditaciones, prácticas guiadas, canalizaciones e "
    "inspiración en un espacio sereno y sin distracciones.\n\n"
    "Qué encontrarás:\n\n"
    "Medita: sesiones de meditación para calmar la mente y volver al presente.\n"
    "Canaliza: canalizaciones con alma, con contenido nuevo cada semana.\n"
    "Duerme: prácticas para acompañar el descanso.\n"
    "Inspira: piezas breves para reconectar a lo largo del día.\n\n"
    "Escucha con la pantalla bloqueada y en segundo plano, y guarda tus piezas "
    "favoritas para reproducirlas sin conexión. Tu progreso, tus favoritos y "
    "tus descargas se conservan para que retomes donde lo dejaste, en cualquier "
    "momento y desde cualquier dispositivo.\n\n"
    "Aviso de bienestar: las prácticas y meditaciones no sustituyen atención "
    "médica, psicológica ni profesional. Detén la reproducción si una "
    "práctica provoca malestar y busca apoyo profesional cuando sea necesario."
)


def main():
    key_path = os.environ.get("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON", DEFAULT_KEY_PATH)
    credentials = service_account.Credentials.from_service_account_file(
        key_path, scopes=SCOPES
    )
    service = build("androidpublisher", "v3", credentials=credentials)

    edit = service.edits().insert(packageName=PACKAGE_NAME, body={}).execute()
    edit_id = edit["id"]
    print(f"Edit abierto: {edit_id}")

    listings = service.edits().listings().list(
        packageName=PACKAGE_NAME, editId=edit_id
    ).execute()
    languages = [l["language"] for l in listings.get("listings", [])]
    print(f"Idiomas de listing existentes: {languages}")

    for lang in languages:
        service.edits().listings().update(
            packageName=PACKAGE_NAME,
            editId=edit_id,
            language=lang,
            body={
                "language": lang,
                "title": "SoulKey",
                "shortDescription": SHORT_DESCRIPTION,
                "fullDescription": FULL_DESCRIPTION,
            },
        ).execute()
        print(f"Listing '{lang}' actualizado: titulo=SoulKey, descripciones reescritas")

    for lang in languages:
        service.edits().images().deleteall(
            packageName=PACKAGE_NAME,
            editId=edit_id,
            language=lang,
            imageType="icon",
        ).execute()
        service.edits().images().upload(
            packageName=PACKAGE_NAME,
            editId=edit_id,
            language=lang,
            imageType="icon",
            media_body=MediaFileUpload(ICON_PATH, mimetype="image/png"),
        ).execute()
        print(f"Icono subido para '{lang}'")

        service.edits().images().deleteall(
            packageName=PACKAGE_NAME,
            editId=edit_id,
            language=lang,
            imageType="featureGraphic",
        ).execute()
        service.edits().images().upload(
            packageName=PACKAGE_NAME,
            editId=edit_id,
            language=lang,
            imageType="featureGraphic",
            media_body=MediaFileUpload(FEATURE_PATH, mimetype="image/png"),
        ).execute()
        print(f"Feature graphic subido para '{lang}'")

    result = service.edits().commit(packageName=PACKAGE_NAME, editId=edit_id).execute()
    print(f"Edit publicado: {result['id']}")


if __name__ == "__main__":
    main()
