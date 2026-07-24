/// Iterable / list extensions for the presentation layer.
extension IterableExtensions<T> on Iterable<T> {
  /// Index-based map, useful for list builders with separators.
  List<R> mapIndexed<R>(R Function(int index, T item) fn) {
    var index = 0;
    return map((item) => fn(index++, item)).toList();
  }

  T? firstWhereOrNull(bool Function(T item) test) {
    for (final item in this) {
      if (test(item)) return item;
    }
    return null;
  }
}
