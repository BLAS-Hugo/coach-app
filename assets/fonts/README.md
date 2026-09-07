# Fonts

The design uses exactly two families, and the app must embed them rather than
fetch them at runtime — it is offline by design.

| Family | Weights needed | Where it is used |
| --- | --- | --- |
| Archivo | 400, 500, 600 | Headings and running text |
| IBM Plex Mono | 500, 600 | All data, always with tabular figures |

Both are licensed under the SIL Open Font License, so they can ship inside the
app. Neither is vendored yet.

## Adding them

1. Download the static (not variable) TTFs and place them here:

   ```text
   assets/fonts/Archivo-Regular.ttf
   assets/fonts/Archivo-Medium.ttf
   assets/fonts/Archivo-SemiBold.ttf
   assets/fonts/IBMPlexMono-Medium.ttf
   assets/fonts/IBMPlexMono-SemiBold.ttf
   ```

2. Declare them in `pubspec.yaml` under `flutter:`:

   ```yaml
   fonts:
     - family: Archivo
       fonts:
         - asset: assets/fonts/Archivo-Regular.ttf
           weight: 400
         - asset: assets/fonts/Archivo-Medium.ttf
           weight: 500
         - asset: assets/fonts/Archivo-SemiBold.ttf
           weight: 600
     - family: IBMPlexMono
       fonts:
         - asset: assets/fonts/IBMPlexMono-Medium.ttf
           weight: 500
         - asset: assets/fonts/IBMPlexMono-SemiBold.ttf
           weight: 600
   ```

The family names must match `AppFontFamily` in
`lib/app/theme/app_typography.dart`. Until the files land, Flutter silently
falls back to the platform font; every other type token — size, weight, line
height, tracking, tabular figures — already applies.
