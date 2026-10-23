import 'package:flutter/widgets.dart';
import 'package:orvano/orvano.dart' hide packageVersion;

import 'version.dart';

/// Opens the Orvano client in a Flutter app (spec 0004 CLN-1).
abstract final class OrvanoFlutter {
  /// Opens a client for [projectId] on [endpoint], with the project's
  /// publishable key (`orv_pk_...`), and returns the same [Orvano] type the
  /// pure Dart package gives. It initializes Flutter's bindings itself, so
  /// you can call it first thing in `main`.
  ///
  /// Throws `ArgumentError` for the same inputs [Orvano.open] refuses.
  static Future<Orvano> open({
    required Uri endpoint,
    required String projectId,
    required String publishableKey,
    OrvanoClientOptions options = const OrvanoClientOptions(),
  }) {
    WidgetsFlutterBinding.ensureInitialized();
    return Orvano.open(
      endpoint: endpoint,
      projectId: projectId,
      publishableKey: publishableKey,
      options: options,
      clientName: 'orvano_flutter/$packageVersion',
    );
  }
}
