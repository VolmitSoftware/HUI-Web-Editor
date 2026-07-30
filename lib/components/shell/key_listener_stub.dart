/// Off-web no-op backend for `key_listener.dart`.
library;

import 'shell_keys.dart';

void Function() installShellKeyListener(ShellKeyHandler handler) => () {};

bool isApplePlatform() => false;
