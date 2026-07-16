Repository Guidelines

Do not write to a super file!!!! Do not write to a super file!!!! Do not write to a super file!!!!
All actual build and test commands must be executed within the GitHub workflow; running them on your local machine is prohibited—local device performance is insufficient.

Do not execute any installation commands; simply modify the code.

Regarding the garbled text issue you mentioned, it has been confirmed that it is not caused by file corruption. The file can be read correctly in PowerShell using the following method:
powershell
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
Get-Content -Encoding UTF8 file-path
Each time you complete the addition or modification of a feature according to my requirements, a commit message should be automatically generated and submitted after you finish modifying the code. When submitting a GPG key, you can temporarily omit the signature.auto push

apply_patch 在当前环境可用。

  原因
  之前失败是因为 patch 头写成了：

  *** Begin Patch ***

  正确格式必须是：

  *** Begin Patch
  ...
  *** End Patch

  末尾不能多写 ***。工具只认精确的 *** Begin Patch 作为第一行。


## Project Structure & Module Organization

NexAI is a Flutter/Dart client for OpenAI-compatible APIs. Core app code lives in `lib/`: `main.dart` and `app.dart` bootstrap the app, `pages/` contains screens, `providers/` owns state and API-facing logic, `models/` defines data objects, `services/` handles backend/security integrations, `utils/` contains shared helpers, and `widgets/` holds reusable UI. Tests are under `test/`, with widget tests in `test/widgets/`. Static assets, fonts, Markdown CSS, and icons are in `assets/`. Platform code is in `android/`, `web/`, and `windows/`; project docs are in `docs/`.

## Build, Test, and Development Commands

- `flutter pub get` installs dependencies from `pubspec.yaml`.
- `flutter run -d windows`, `flutter run -d android`, or `flutter run -d chrome` runs the app locally on the target platform.
- `flutter analyze` runs the Dart analyzer with `flutter_lints`.
- `dart format lib test` formats source and tests.
- `flutter test` runs all unit and widget tests.
- `flutter build apk --release` and `flutter build web` create release builds.
- `pwsh scripts/build.ps1 -Arg android` updates Android release metadata; it rewrites `pubspec.yaml` and `nexai_release.json`.
- `scripts\generate-icons.cmd` regenerates Android launcher icons from `assets/icon.png` and requires ImageMagick.

## Coding Style & Naming Conventions

Use two-space Dart formatting via `dart format`. Follow `flutter_lints`; this repo disables `prefer_const_constructors`, `prefer_const_literals_to_create_immutables`, and `avoid_print` in `analysis_options.yaml`. Use `PascalCase` for classes/widgets, `camelCase` for members, and `snake_case.dart` filenames. Keep UI in `pages/` or `widgets/`, state in `providers/`, and network/security behavior in `services/` or `utils/`.

## Testing Guidelines

Name tests `*_test.dart` and mirror the feature path when practical, for example `test/widgets/markdown_renderer_test.dart`. Add focused tests for parser, rendering, update-checking, provider, and utility changes. Run `flutter test` before submitting and `flutter analyze` for shared logic.

## Commit & Pull Request Guidelines

Git history uses Conventional Commits such as `fix: harden backend sync and diagnostics`, `feat: refine chat and tools interactions`, and `chore: clean analyzer issues`. Keep commits scoped and imperative. Pull requests should include a summary, affected platforms, test results, linked issues, and screenshots or recordings for UI changes.

## Security & Configuration Tips

Do not commit API keys, keystores, signing passwords, or local certificate material. Android signing uses GitHub Actions secrets and `android/gradle.properties`; prefer release flows over hardcoded credentials. Review `docs/SERVER_API_SECURITY.md` and related contracts before changing request signing, certificate pinning, sync, or device security code.
