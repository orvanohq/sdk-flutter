/// The Orvano client for Dart and Flutter apps: open a client for your
/// project with its publishable key, then call its services.
library;

// Deviation DRT-8: the generated barrel carries the show lists, so a new
// service reaches the public API without a hand edit (spec 0014 GNR-9).
export 'src/generated/exports.dart';
export 'src/orvano.dart' show Orvano;
export 'src/version.dart' show packageVersion;
