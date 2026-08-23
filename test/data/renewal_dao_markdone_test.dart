// Regression test for the bug named in scope doc §3d (2026-08-21 revision)
// and in the developer task brief for this slice: `RenewalDao.markDone` used
// to set `isDone: true` unconditionally, which permanently parked every
// *recurring* item in the collapsed Done section the moment it was marked
// done, even when a next due date had just been chosen — silently
// suppressing that item's entire next-cycle ladder, since both
// `StatusCalculator` and (once notifications exist) the reconciliation
// planner both short-circuit on `isDone` before ever looking at the due
// date. Exercised here against a real (in-memory) database, not just the
// pure domain layer, since the bug lived in the DAO's write, not in
// `StatusCalculator` itself.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:long_term_reminder/data/database/app_database.dart';
import 'package:long_term_reminder/data/repository/renewal_repository.dart';
import 'package:long_term_reminder/domain/models/renewal_type.dart';

void main() {
  late AppDatabase database;
  late RenewalRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = RenewalRepository(database.renewalDao);
  });

  tearDown(() => database.close());

  test('marking a RECURRING item done with a next due date does NOT persist isDone — §3d', () async {
    final id = await repository.createItem(
      type: RenewalType.insurance,
      label: 'Car insurance',
      dueDate: DateTime(2027, 3, 21),
    );

    await repository.commitMarkDone(id, nextDueDate: DateTime(2028, 3, 21));

    final after = (await repository.getById(id))!;
    expect(after.isDone, isFalse, reason: 'a recurring item mid-cycle must never be parked in Done');
    expect(after.dueDate, DateTime(2028, 3, 21), reason: 'the due date must still advance to the next cycle');
    expect(after.lastCompletedAt, isNotNull, reason: 'history should still record the completion');
  });

  test('marking a TERMINAL item done (no next due date) DOES persist isDone — Warranty, REQ-9.3', () async {
    final id = await repository.createItem(
      type: RenewalType.warranty,
      label: 'Washing machine',
      dueDate: DateTime(2027, 1, 1),
    );

    await repository.commitMarkDone(id, nextDueDate: null);

    final after = (await repository.getById(id))!;
    expect(after.isDone, isTrue, reason: 'a genuinely terminal outcome (no next cycle) is the one case Done persists');
    expect(after.dueDate, DateTime(2027, 1, 1), reason: 'no next cycle means the due date is left untouched');
  });

  test('marking a Custom item done with "No" to the repeat prompt behaves like Warranty (terminal)', () async {
    final id = await repository.createItem(
      type: RenewalType.custom,
      label: 'One-off task',
      dueDate: DateTime(2027, 6, 1),
    );

    await repository.commitMarkDone(id, nextDueDate: null);

    final after = (await repository.getById(id))!;
    expect(after.isDone, isTrue);
  });
}
