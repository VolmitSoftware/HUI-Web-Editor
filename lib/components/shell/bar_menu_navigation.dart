library;

int huiBarMenuTargetIndex({
  required int current,
  required int count,
  required String key,
}) {
  if (count <= 0) return -1;
  return switch (key) {
    'Home' => 0,
    'End' => count - 1,
    'ArrowUp' => current <= 0 ? count - 1 : current - 1,
    'ArrowDown' => current < 0 || current >= count - 1 ? 0 : current + 1,
    _ => -1,
  };
}
