import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:long_term_reminder/data/database/app_database.dart';
import 'package:long_term_reminder/data/repository/entitlement_repository.dart';

void main() {
  late AppDatabase database;
  late EntitlementRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = EntitlementRepository(database.settingsDao);
  });
  tearDown(() => database.close());

  test('defaults to not entitled on a fresh install', () async {
    expect(await repository.isEntitled(), isFalse);
  });

  test('setEntitled persists across reads, offline — no network call anywhere in this path', () async {
    await repository.setEntitled(true);
    expect(await repository.isEntitled(), isTrue);

    await repository.setEntitled(false);
    expect(await repository.isEntitled(), isFalse);
  });

  test('watchEntitled emits live updates as setEntitled changes the flag (REQ-17.3\'s degrade path)', () async {
    final values = <bool>[];
    final subscription = repository.watchEntitled().listen(values.add);
    addTearDown(subscription.cancel);

    await Future<void>.delayed(Duration.zero);
    await repository.setEntitled(true);
    await Future<void>.delayed(Duration.zero);
    await repository.setEntitled(false);
    await Future<void>.delayed(Duration.zero);

    expect(values, [false, true, false]);
  });
}
