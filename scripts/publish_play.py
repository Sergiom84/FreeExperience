"""Sube un .aab a una pista de Google Play vía la Android Publisher API.

Requiere la clave JSON de la cuenta de servicio (play-publisher@free-experience.iam.gserviceaccount.com)
vinculada en Play Console > Users and permissions con permiso de "Release to testing tracks"
sobre la app "La llaves" (com.freeexperience.free_experience).

Uso:
  python scripts/publish_play.py [--track internal] [--aab PATH] [--notes "Texto"]

Variables de entorno:
  GOOGLE_PLAY_SERVICE_ACCOUNT_JSON  ruta a la clave JSON (por defecto ~/.play-publish-keys/free-experience.json)
"""
import argparse
import os

from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

PACKAGE_NAME = "com.freeexperience.free_experience"
DEFAULT_KEY_PATH = os.path.expanduser("~/.play-publish-keys/free-experience.json")
DEFAULT_AAB_PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "build", "app", "outputs", "bundle", "release", "app-release.aab",
)
SCOPES = ["https://www.googleapis.com/auth/androidpublisher"]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--track", default="internal", choices=["internal", "alpha", "beta", "production"])
    parser.add_argument("--aab", default=DEFAULT_AAB_PATH)
    parser.add_argument("--notes", default=None, help="Notas de la versión (release notes) en es-ES")
    args = parser.parse_args()

    key_path = os.environ.get("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON", DEFAULT_KEY_PATH)
    if not os.path.isfile(key_path):
        raise SystemExit(f"No se encuentra la clave de la cuenta de servicio en: {key_path}")
    if not os.path.isfile(args.aab):
        raise SystemExit(f"No se encuentra el .aab en: {args.aab}")

    credentials = service_account.Credentials.from_service_account_file(key_path, scopes=SCOPES)
    service = build("androidpublisher", "v3", credentials=credentials)

    edit = service.edits().insert(packageName=PACKAGE_NAME, body={}).execute()
    edit_id = edit["id"]
    print(f"Edit abierto: {edit_id}")

    media = MediaFileUpload(args.aab, mimetype="application/octet-stream", resumable=True)
    bundle = service.edits().bundles().upload(
        packageName=PACKAGE_NAME,
        editId=edit_id,
        media_body=media,
    ).execute()
    version_code = bundle["versionCode"]
    print(f"Bundle subido, versionCode={version_code}")

    release = {"versionCodes": [str(version_code)], "status": "completed"}
    if args.notes:
        release["releaseNotes"] = [{"language": "es-ES", "text": args.notes}]

    service.edits().tracks().update(
        packageName=PACKAGE_NAME,
        editId=edit_id,
        track=args.track,
        body={"releases": [release]},
    ).execute()
    print(f"Pista '{args.track}' actualizada con versionCode={version_code}")

    result = service.edits().commit(packageName=PACKAGE_NAME, editId=edit_id).execute()
    print(f"Edit publicado: {result['id']}")


if __name__ == "__main__":
    main()
