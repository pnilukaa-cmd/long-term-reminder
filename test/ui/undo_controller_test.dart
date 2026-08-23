// Exercises REQ-10's deferred-write undo contract against a real
// (in-memory) database, without waiting out the real 6-second window —
// this slice's approved dependency list doesn't include a fake-clock
// package, and a test suite that sleeps 6+ real seconds per case isn't
// "cheap" per the brief. What's covered instead:
//   - scheduling doesn't write to the database until commit
//   - the overlay correctly reflects the pending action
//   - undo() reverts with zero database writes
//   - REQ-10.2's overlap rule: scheduling a second action commits the
//     first immediately (this path runs synchronously, no timer wait
//     needed, so it's exercised directly).
// The "window lapses on its own after 6s" path is the one path this file
// does *not* exercise end-to-end — flagged in the developer handoff.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:long_term_reminder/data/database/app_database.dart';
import 'package:long_term_reminder/data/repository/renewal_repository.dart';
import 'package:long_term_reminder/domain/models/renewal_type.dart';
import 'package:long_term_reminder/ui/common/undo_controller.dart';

void main() {
  late AppDatabase database;
  late RenewalRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = RenewalRepository(database.renewalDao);
  });

  tearDown(() => database.close());

  test('scheduleDelete hides the item via overlay without deleting it from the database', () async {
    final id = await repository.createItem(
      type: RenewalType.warranty,
      label: 'Washing machine',
      dueDate: DateTime(2027, 1, 1),
    );
    final controller = UndoController(repository);
    addTearDown(controller.dispose);

    final item = (await repository.getById(id))!;
    await controller.scheduleDelete(item);

    final allItems = await repository.watchAll().first;
    expect(allItems, hasLength(1), reason: 'nothing should be deleted from the DB yet');

    final overlaid = controller.applyOverlay(allItems);
    expect(overlaid, isEmpty, reason: 'the pending delete should hide it from the UI');
  });

  test('undo() after scheduleDelete leaves the database untouched and clears the overlay', () async {
    final id = await repository.createItem(
      type: RenewalType.warranty,
      label: 'Washing machine',
      dueDate: DateTime(2027, 1, 1),
    );
    final controller = UndoController(repository);
    addTearDown(controller.dispose);

    final item = (await repository.getById(id))!;
    await controller.scheduleDelete(item);
    controller.undo();

    final allItems = await repository.watchAll().first;
    expect(allItems, hasLength(1));
    expect(controller.applyOverlay(allItems), hasLength(1));
    expect(controller.pending, isNull);
  });

  test('scheduleMarkDone overlay shows the item as done without writing to the database yet', () async {
    final id = await repository.createItem(
      type: RenewalType.warranty,
      label: 'Washing machine',
      dueDate: DateTime(2027, 1, 1),
    );
    final controller = UndoController(repository);
    addTearDown(controller.dispose);

    final item = (await repository.getById(id))!;
    await controller.scheduleMarkDone(item);

    final fromDb = (await repository.getById(id))!;
    expect(fromDb.isDone, isFalse, reason: 'not committed yet');

    final overlaid = controller.applyOverlay([fromDb]);
    expect(overlaid.single.isDone, isTrue);
  });

  test(
    'scheduleMarkDone overlay does NOT flag a RECURRING item as Done (§3d bug fix) — '
    'it shows the new due date immediately instead',
    () async {
      final id = await repository.createItem(
        type: RenewalType.insurance,
        label: 'Car insurance',
        dueDate: DateTime(2027, 3, 21),
      );
      final controller = UndoController(repository);
      addTearDown(controller.dispose);

      final item = (await repository.getById(id))!;
      final nextDueDate = DateTime(2028, 3, 21);
      await controller.scheduleMarkDone(item, nextDueDate: nextDueDate);

      final overlaid = controller.applyOverlay([item]);
      expect(overlaid.single.isDone, isFalse, reason: 'a recurring item mid-cycle is never Done, per scope doc §3d');
      expect(overlaid.single.dueDate, nextDueDate);
    },
  );

  test('REQ-10.2 overlap rule: scheduling a second action commits the first immediately', () async {
    final firstId = await repository.createItem(
      type: RenewalType.warranty,
      label: 'First item',
      dueDate: DateTime(2027, 1, 1),
    );
    final secondId = await repository.createItem(
      type: RenewalType.warranty,
      label: 'Second item',
      dueDate: DateTime(2027, 1, 1),
    );
    final controller = UndoController(repository);
    addTearDown(controller.dispose);

    final first = (await repository.getById(firstId))!;
    final second = (await repository.getById(secondId))!;

    await controller.scheduleDelete(first);
    // Scheduling a second covered action while the first is still pending
    // should commit the first one right away (its own undo window ends
    // early), per REQ-10.2's stated default.
    await controller.scheduleDelete(second);

    final remaining = await repository.watchAll().first;
    expect(remaining.map((i) => i.id), isNot(contains(firstId)), reason: 'first delete should have committed');
    expect(remaining.map((i) => i.id), contains(secondId), reason: 'second delete is still pending, not committed');

    // Only the second action is now undoable.
    expect(controller.pending?.item.id, secondId);
  });
}
