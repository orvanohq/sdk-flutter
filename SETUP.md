# Set up this repo

You made this repo from `orvanohq/sdk-template-dart` (spec 0010 TPL-4). Work through this list, then delete this file.

## Placeholders to fill in

- `{{PRODUCT_NAME}}` in `NOTICE` and `README.md`: the repo's name from spec 0009 LIC-2's table
- `{{PACKAGE_NAME}}` in `README.md`: the package name from spec 0007 REP-3
- The package name and description in the language manifest: `pubspec.yaml` (`name`, `description`, `repository`)

## Steps

1. Make the repo **public** from the start ("Use this template" with visibility public). On GitHub Free, its
   ruleset, CodeQL, and secret scanning need that.
2. Fill in the placeholders above.
3. From a clone of `orvanohq/orvano`, apply the settings (a template doesn't copy rulesets or settings):

   ```bash
   node tooling/scripts/github-settings.mjs orvanohq/<this-repo> --profile sdk-dart --apply
   ```

4. Open a first PR. Its green CI is the proof these starter files work (spec 0008 KIT-3).
5. Delete this file.

CI calls the core's shared workflows at `a91f23fe6a3452c66d4d3516abbefae168136de7` (`main` as of 2026-10-18). Move that pin forward with the
core.

## Common files

Every SDK repo has these at its root:

- `.editorconfig`, `.gitattributes`: the same basics as the core repo (spec 0008 FMT-4, GIT-4)
- `LICENSE`, `NOTICE`: Apache 2.0 (spec 0009 LIC-1, LIC-2). Replace `{{PRODUCT_NAME}}` in `NOTICE` with the repo's
  name from spec 0009 LIC-2's table (for example `Orvano .NET Server SDK`); leave `LICENSE` exactly as it is
- `.github/dependency-review-config.yml`: the SDK license lists (spec 0009 DEP-8); keep only your repo's exceptions
- `typos.toml`: keep only the excludes that exist in your repo
- `.github/pull_request_template.md`: keep the blocks that fit the SDK (Security always stays, PRT-1)
- `.github/dependabot.yml`: the ecosystems the repo uses (the export keeps the language's and `github-actions`)
- `.github/zizmor.yml`: the same zizmor settings as the core repo
- `.github/CODEOWNERS`: added by the export (spec 0010 OWN-1)
- `.github/workflows/ci.yml`: calls the shared workflows at a pinned core SHA (KIT-1). The export sets the language,
  the SHA, and its date; move the pin forward with the core
- `.github/workflows/codeql.yml` (not for Dart) and `.github/workflows/dependency-review.yml`: the security checks
  the repo's `main` ruleset requires (spec 0010 TPL-5, RUL-3). Both need a public repo on GitHub Free

Community files (security policy, code of conduct, support, contributing, and issue forms) come from the org's
`orvanohq/.github` repo, so an SDK repo doesn't carry its own (spec 0010 COM-4, ISS-3).

## Dart and Flutter SDK starter

For the `sdk-dart` and `sdk-flutter` repos (spec 0004, names from spec 0007 REP-3).

- `analysis_options.yaml`: at the repo root (DRT-4). Confirm the casing of `no_runtimeType_toString` and that
  every rule exists in the floor's analyzer (DRT-1); drop any that don't, with a note in spec 0004.
- `example/analysis_options.yaml` and `tool/analysis_options.yaml`: copies of `analysis_options.tool.yaml` (the export writes both).
- `.github/dependabot.yml`: `pub` and `github-actions` (the export trims the rest).

The `tool/check_*.dart` scripts spec 0004 names (imports, deps, version, pana) are written with the first Dart repo
(LNT-7, KIT-3). `sdk-dart.yml` runs them when they exist.
