import 'package:dance_evaluation/core/services/service_locator.dart';
import 'package:flutter_test/flutter_test.dart';

// Simple test service classes.
class FooService {
  final String name;
  FooService(this.name);
}

class BarService {
  final int value;
  BarService(this.value);
}

void main() {
  late ServiceLocator locator;

  setUp(() {
    locator = ServiceLocator.instance;
    locator.reset();
  });

  tearDown(() {
    locator.reset();
  });

  group('ServiceLocator', () {
    test('register and get service', () {
      final foo = FooService('test');
      locator.register<FooService>(foo);

      final retrieved = locator.get<FooService>();
      expect(retrieved, same(foo));
      expect(retrieved.name, equals('test'));
    });

    test('throws StateError for unregistered service', () {
      expect(
        () => locator.get<BarService>(),
        throwsA(isA<StateError>()),
      );
    });

    test('has returns true for registered service', () {
      locator.register<FooService>(FooService('test'));
      expect(locator.has<FooService>(), isTrue);
    });

    test('has returns false for unregistered service', () {
      expect(locator.has<BarService>(), isFalse);
    });

    test('reset clears all services', () {
      locator.register<FooService>(FooService('test'));
      locator.register<BarService>(BarService(42));

      expect(locator.has<FooService>(), isTrue);
      expect(locator.has<BarService>(), isTrue);

      locator.reset();

      expect(locator.has<FooService>(), isFalse);
      expect(locator.has<BarService>(), isFalse);
    });

    test('can register multiple different types', () {
      locator.register<FooService>(FooService('hello'));
      locator.register<BarService>(BarService(99));

      expect(locator.get<FooService>().name, equals('hello'));
      expect(locator.get<BarService>().value, equals(99));
    });

    test('re-registering same type overwrites previous', () {
      locator.register<FooService>(FooService('first'));
      locator.register<FooService>(FooService('second'));

      expect(locator.get<FooService>().name, equals('second'));
    });
  });
}
