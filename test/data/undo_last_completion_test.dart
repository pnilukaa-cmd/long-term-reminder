// Exercises `Undo last completion` (scope doc §3d, developer task brief
// item 2) against a real (in-memory) database — this is the revert logic
// the task brief explicitly calls out as genuinely testable without
// hardware, since it's a database read-modify-write with no plugin/device
// dependency. Also covers the single-level-undo invalidation rules and the
// deferred-recurrence-decision flag the notification gap (item 3) depends
// on.

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

  group('Undo last completion — recurring item', () {
    test('reverts a recurring mark-done back to its exact prior due date and lastCompletedAt', () async {
      final id = await repository.createItem(
        type: RenewalType.insurance,
        label: 'Car insurance',
        dueDate: DateTime(2027, 3, 21),
      );

      await repository.commitMarkDone(id, nextDueDate: DateTime(2028, 3, 21));
      final afterMarkDone = (await repository.getById(id))!;
      expect(afterMarkDone.dueDate, DateTime(2028, 3, 21));
      expect(afterMarkDone.hasUndoableCompletion, isTrue);
      expect(afterMarkDone.isDone, isFalse, reason: 'a recurring item mid-cycle is never Done (§3d)');

      final reverted = await repository.undoLastCompletion(id);
      expect(reverted, isTrue);

      final after = (await repository.getById(id))!;
      expect(after.dueDate, DateTime(2027, 3, 21), reason: 'due date restored to its pre-completion value');
      expect(after.isDone, isFalse);
      expect(after.lastCompletedAt, isNull, reason: 'this was the item\'s first-ever completion');
      expect(after.hasUndoableCompletion, isFalse, reason: 'single-level undo — cannot undo again');
    });

    test('a second mark-done overwrites the snapshot — only the most recent event is undoable', () async {
      final id = await repository.createItem(
        type: RenewalType.insurance,
        label: 'Car insurance',
        dueDate: DateTime(2026, 3, 21),
      );

      await repository.commitMarkDone(id, nextDueDate: DateTime(2027, 3, 21));
      await repository.commitMarkDone(id, nextDueDate: DateTime(2028, 3, 21));

      final reverted = await repository.undoLastCompletion(id);
      expect(reverted, isTrue);

      final after = (await repository.getById(id))!;
      expect(
        after.dueDate,
        DateTime(2027, 3, 21),
        reason: 'reverts only the most recent (2nd) completion, landing back on the 1st cycle\'s result',
      );
      expect(after.lastCompletedAt, isNotNull, reason: 'the first completion\'s history is still real, not erased');
    });
  });

  group('Undo last completion — terminal item (Warranty)', () {
    test('reverts a terminal mark-done back to not-done with the original due date untouched', () async {
      final id = await repository.createItem(
        type: RenewalType.warranty,
        label: 'Washing machine',
        dueDate: DateTime(2027, 1, 1),
      );

      await repository.commitMarkDone(id, nextDueDate: null);
      final afterMarkDone = (await repository.getById(id))!;
      expect(afterMarkDone.isDone, isTrue);

      final reverted = await repository.undoLastCompletion(id);
      expect(reverted, isTrue);

      final after = (await repository.getById(id))!;
      expect(after.isDone, isFalse);
      expect(after.dueDate, DateTime(2027, 1, 1), reason: 'terminal mark-done never touched the due date to begin with');
    });
  });

  group('Undo last completion — invalidation boundary (scope doc §3d)', () {
    test('returns false when nothing has ever been completed', () async {
      final id = await repository.createItem(
        type: RenewalType.warranty,
        label: 'Washing machine',
        dueDate: DateTime(2027, 1, 1),
      );
      expect(await repository.undoLastCompletion(id), isFalse);
    });

    test('an edit after mark-done invalidates the undo — "invalidated by any subsequent edit"', () async {
      final id = await repository.createItem(
        type: RenewalType.insurance,
        label: 'Car insurance',
        dueDate: DateTime(2027, 3, 21),
      );
      await repository.commitMarkDone(id, nextDueDate: DateTime(2028, 3, 21));

      final current = (await repository.getById(id))!;
      expect(current.hasUndoableCompletion, isTrue);

      await repository.updateItem(
        id: id,
        type: current.type,
        label: 'Car insurance (renamed)',
        dueDate: current.dueDate,
        isDone: current.isDone,
        lastCompletedAt: current.lastCompletedAt,
        createdAt: current.createdAt,
      );

      final afterEdit = (await repository.getById(id))!;
      expect(afterEdit.hasUndoableCompletion, isFalse);
      expect(await repository.undoLastCompletion(id), isFalse);
    });

    test('using Undo last completion once means it cannot be used again (no redo stack)', () async {
      final id = await repository.createItem(
        type: RenewalType.warranty,
        label: 'Washing machine',
        dueDate: DateTime(2027, 1, 1),
      );
      await repository.commitMarkDone(id, nextDueDate: null);
      expect(await repository.undoLastCompletion(id), isTrue);
      expect(await repository.undoLastCompletion(id), isFalse);
    });

    test('returns false for a deleted item rather than throwing', () async {
      final id = await repository.createItem(
        type: RenewalType.warranty,
        label: 'Washing machine',
        dueDate: DateTime(2027, 1, 1),
      );
      await repository.commitMarkDone(id, nextDueDate: null);
      await repository.deleteItem(id);
      expect(await repository.undoLastCompletion(id), isFalse);
    });
  });

  group('Deferred recurrence decision flag (REQ-9.5, developer task brief item 3)', () {
    test('markPendingRecurrenceDecision sets the flag without touching dueDate/isDone', () async {
      final id = await repository.createItem(
        type: RenewalType.insurance,
        label: 'Car insurance',
        dueDate: DateTime(2027, 1, 1),
      );
      await repository.markPendingRecurrenceDecision(id);

      final after = (await repository.getById(id))!;
      expect(after.pendingRecurrenceDecision, isTrue);
      expect(after.isDone, isFalse);
      expect(after.dueDate, DateTime(2027, 1, 1), reason: 'no recurrence decision has actually been made yet');
    });

    test('resolving it via the ordinary mark-done path clears the flag', () async {
      final id = await repository.createItem(
        type: RenewalType.insurance,
        label: 'Car insurance',
        dueDate: DateTime(2027, 1, 1),
      );
      await repository.markPendingRecurrenceDecision(id);
      await repository.commitMarkDone(id, nextDueDate: DateTime(2028, 1, 1));

      final after = (await repository.getById(id))!;
      expect(after.pendingRecurrenceDecision, isFalse);
      expect(after.dueDate, DateTime(2028, 1, 1));
    });

    test('editing the item while a decision is pending also clears the flag', () async {
      final id = await repository.createItem(
        type: RenewalType.insurance,
        label: 'Car insurance',
        dueDate: DateTime(2027, 1, 1),
      );
      await repository.markPendingRecurrenceDecision(id);

      final current = (await repository.getById(id))!;
      await repository.updateItem(
        id: id,
        type: current.type,
        label: current.label,
        dueDate: DateTime(2027, 6, 1),
        isDone: current.isDone,
        lastCompletedAt: current.lastCompletedAt,
        createdAt: current.createdAt,
      );

      final after = (await repository.getById(id))!;
      expect(after.pendingRecurrenceDecision, isFalse, reason: 'a manual edit supersedes the deferred question');
    });
  });
}
