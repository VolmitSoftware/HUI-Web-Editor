import 'dart:async';
import 'dart:io';

import 'package:gloss_sync_relay/gloss_sync_relay.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

Future<void> main() async {
  final RelayConfig config = RelayConfig.fromEnvironment(Platform.environment);
  final GlossSyncRelay relay = GlossSyncRelay(
    config: config,
    store: FileRelayStore(config.dataDirectory),
  );
  await relay.start();
  final HttpServer server = await shelf_io.serve(
    relay.handler,
    config.bindAddress,
    config.port,
    poweredByHeader: null,
  );
  server.idleTimeout = const Duration(seconds: 30);
  stdout.writeln(
    'Gloss sync relay listening on ${server.address.address}:${server.port}${config.apiPrefix}',
  );
  final Completer<void> stopping = Completer<void>();
  final List<StreamSubscription<ProcessSignal>> signalSubscriptions =
      <StreamSubscription<ProcessSignal>>[];
  bool stoppingStarted = false;
  Future<void> stop(ProcessSignal signal) async {
    if (stoppingStarted) return;
    stoppingStarted = true;
    try {
      try {
        await server.close(force: false).timeout(const Duration(seconds: 10));
      } on TimeoutException {
        await server.close(force: true);
      }
      await relay.close();
    } catch (error, stackTrace) {
      stderr.writeln('Gloss sync relay shutdown failed: $error');
      stderr.writeln(stackTrace);
      exitCode = 1;
    } finally {
      for (final StreamSubscription<ProcessSignal> subscription
          in signalSubscriptions) {
        await subscription.cancel();
      }
      stopping.complete();
    }
  }

  signalSubscriptions.add(ProcessSignal.sigint.watch().listen(stop));
  if (!Platform.isWindows) {
    signalSubscriptions.add(ProcessSignal.sigterm.watch().listen(stop));
  }
  await stopping.future;
}
