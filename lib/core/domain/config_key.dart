/// A typed Remote Config parameter. [T] is String, bool, int or double.
///
/// Keys with the same [runtimeType], [key] and [defaultValue] are equal.
class ConfigKey<T extends Object> {
  const ConfigKey(this.key, this.defaultValue);

  final String key;
  final T defaultValue;

  @override
  bool operator ==(Object other) =>
      other is ConfigKey<Object> &&
      other.runtimeType == runtimeType &&
      other.key == key &&
      other.defaultValue == defaultValue;

  @override
  int get hashCode => Object.hash(runtimeType, key, defaultValue);
}
