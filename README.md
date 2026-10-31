# Orvano Flutter SDK

The [Orvano](https://github.com/orvanohq/orvano) SDK for Flutter and Dart apps, as a pub workspace (spec 0004 PKG-1):

| Package                                              | What it is                                                                  |
| ---------------------------------------------------- | --------------------------------------------------------------------------- |
| [`packages/orvano`](packages/orvano)                 | The pure Dart client (VM, web, Flutter), generated from the Orvano contract |
| [`packages/orvano_flutter`](packages/orvano_flutter) | The Flutter layer: `OrvanoFlutter.open`, exporting all of `orvano`          |

For a backend or a CLI with a secret key, use [`orvano_server`](https://github.com/orvanohq/sdk-dart).

## Working on this repo

The workspace contains a Flutter package, so it resolves only with the Flutter tool (Flutter 3.38 or later). Most of `packages/orvano` is generated from the Orvano contract (spec 0014): `lib/src/generated/`, `lib/src/core/` (the runtime shared with `orvano_server`), and `test/conformance/dispatch.g.dart`. Never edit them by hand; change the generator or its templates in `orvanohq/orvano`, then regenerate. Regenerating needs git, Node 24, and pnpm (`corepack enable`).

```bash
flutter pub get
dart run tool/regenerate.dart             # regenerate from the commit in orvano-contract.json
dart run tool/regenerate.dart --pin <sha> # move the pin to another orvano commit first
for check in tool/check_*.dart; do dart run "$check"; done
(cd packages/orvano && flutter test --exclude-tags conformance)
(cd packages/orvano_flutter && flutter test)
```

The conformance suite runs every shared client scenario against a real Orvano server and the stub server, from the pinned commit's `api/conformance/compose.yaml`:

```bash
dart run tool/regenerate.dart --fetch-only
docker build --file .orvano/deploy/Dockerfile --tag orvano:pinned .orvano
ORVANO_IMAGE=orvano ORVANO_IMAGE_TAG=pinned docker compose --file .orvano/api/conformance/compose.yaml up --detach --wait
(cd packages/orvano && dart test --tags conformance)
```

A scenario that requires a project gets one from `orvano admin bootstrap-project`, run through `docker compose exec` in that stack (spec 0017 SDK-4). Set `ORVANO_CONFORMANCE_PARTIAL=1` when you run only some scenarios with `--name`. A scenario that can't run here goes in `packages/orvano/test/conformance/skip.json` with a reason and an issue link.

## License

Apache License 2.0 (see `LICENSE` and `NOTICE`). The name "Orvano" and its logo aren't covered by the license; see [TRADEMARKS.md](https://github.com/orvanohq/orvano/blob/main/TRADEMARKS.md).
