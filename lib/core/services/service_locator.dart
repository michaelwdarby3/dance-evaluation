/// Simple service locator for dependency injection.
final class ServiceLocator {
  ServiceLocator._();

  static final instance = ServiceLocator._();

  final Map<Type, Object> _services = {};

  /// Register a service instance by type.
  void register<T extends Object>(T service) {
    _services[T] = service;
  }

  /// Retrieve a registered service by type.
  T get<T extends Object>() {
    final service = _services[T];
    if (service == null) {
      throw StateError('Service $T is not registered in ServiceLocator');
    }
    return service as T;
  }

  /// Check if a service is registered.
  bool has<T extends Object>() => _services.containsKey(T);

  /// Reset all registrations (useful for testing).
  void reset() => _services.clear();
}
