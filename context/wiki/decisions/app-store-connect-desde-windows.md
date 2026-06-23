# App Store Connect — preparación desde Windows (sin Mac)

Todo lo que se puede configurar en App Store Connect sin necesitar Xcode ni Mac.

## Completado

- Bundle ID `com.freeexperience.app` registrado en Apple Developer.
- App creada con nombre **Free Experience**, subtítulo "Biblioteca de meditacion" (24 chars).
- Descripción, keywords, contacto y URLs configuradas:
  - Soporte: https://github.com/Sergiom84/FreeExperience_Support-URL-
  - Privacidad: https://github.com/Sergiom84/FreeExperience_Support-URL-/blob/main/PRIVACY.md
- Categorías: Health & Fitness / Lifestyle.
- Age Rating: 4+.
- Disponibilidad: España + 18 países latinoamericanos.
- App Privacy publicada: **Data Not Collected**.

## Requiere Mac (Xcode)

- Cambiar Bundle ID en `ios/Runner.xcodeproj/project.pbxproj` si difiere de `com.freeexperience.app`.
- Capturas de pantalla en simulador de iPhone.
- Archive + Upload vía Xcode Organizer o `xcrun altool`.

## Estado actual (2026-06-23)
Build subida a TestFlight desde Mac. Pendiente review de Apple para distribución pública.
