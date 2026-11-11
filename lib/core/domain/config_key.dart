/// A typed Remote Config parameter. [T] is String, bool, int or double.
class ConfigKey<T extends Object> {
  const ConfigKey(this.key, this.defaultValue);

  final String key;
  final T defaultValue;
}
