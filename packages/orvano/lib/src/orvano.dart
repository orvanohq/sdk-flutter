import 'package:http/http.dart' as http;

import 'core/options.dart';
import 'core/transport.dart';
import 'generated/services.dart';
import 'version.dart';

/// A client for one Orvano project (spec 0004 CLN-1). Open one per project
/// and endpoint with [Orvano.open], and [close] it when you are done.
///
/// In a Flutter app, open it through `OrvanoFlutter.open` from
/// `package:orvano_flutter` instead.
final class Orvano extends OrvanoServices {
  Orvano._(super.transport);

  /// Opens a client for [projectId] on [endpoint], with the project's
  /// publishable key (`orv_pk_...`, spec 0006 KEY-6). A publishable key is
  /// safe in app code; never pass a secret key here.
  ///
  /// Throws `ArgumentError` when the endpoint is not absolute, carries a
  /// user, a query, or a fragment, is `http` for a host other than localhost
  /// (unless `allowInsecureEndpoint` is set), or when [projectId] or
  /// [publishableKey] is empty. Pass [httpClient] to use your own
  /// `http.Client`; the SDK never closes a client it did not create.
  ///
  /// [clientName] is for Orvano's own Flutter layer, which sends
  /// `orvano_flutter/<version>`; apps leave it unset.
  static Future<Orvano> open({
    required Uri endpoint,
    required String projectId,
    required String publishableKey,
    http.Client? httpClient,
    OrvanoClientOptions options = const OrvanoClientOptions(),
    String? clientName,
  }) async => Orvano._(
    OrvanoTransport(
      endpoint: endpoint,
      projectId: projectId,
      clientName: clientName ?? 'orvano/$packageVersion',
      auth: KeyAuth(publishableKey),
      options: options,
      httpClient: httpClient,
    ),
  );

  /// Closes the client (spec 0004 CLN-5): every call in flight fails with
  /// `OrvanoCancelledException`, and the `http.Client` is closed if the SDK
  /// created it. Any call after this fails with `StateError`. Safe to call
  /// more than once.
  Future<void> close() async => transport.close();

  @override
  String toString() => 'Orvano(projectId: ${transport.projectId})';
}
