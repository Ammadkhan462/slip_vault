import 'package:drift/drift.dart';

/// Supported types of captured images
enum EntryKind { slip, receipt, other }

/// Transaction cash flow direction
enum Direction { received, sent, unknown }

/// Main table holding all parsed payment slips and regular screenshots
class Entries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get kind => textEnum<EntryKind>().withDefault(Constant(EntryKind.slip.name))();
  TextColumn get imagePath => text()();
  TextColumn get imageHash => text().unique()();
  IntColumn get amountMinor => integer().nullable()(); // Paisa (e.g. Rs 50.00 = 5000)
  TextColumn get currency => text().withDefault(const Constant('PKR'))();
  TextColumn get direction => textEnum<Direction>().withDefault(Constant(Direction.unknown.name))();
  TextColumn get counterpartyName => text().nullable()();
  TextColumn get counterpartyAccountMasked => text().nullable()();
  TextColumn get transactionId => text().nullable()();
  TextColumn get provider => text().nullable()(); // JazzCash, Easypaisa, SadaPay, etc.
  IntColumn get feeMinor => integer().nullable()();
  DateTimeColumn get occurredAt => dateTime().nullable()();
  TextColumn get ocrText => text().withDefault(const Constant(''))();
  TextColumn get note => text().nullable()();
  TextColumn get confidenceJson => text().nullable()();
  BoolColumn get needsReview => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Tags table for user-assigned labels
class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  TextColumn get colorHex => text().nullable()();
}

/// Many-to-many relationship between entries and tags
class EntryTags extends Table {
  IntColumn get entryId => integer().references(Entries, #id, onDelete: KeyAction.cascade)();
  IntColumn get tagId => integer().references(Tags, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {entryId, tagId};
}

/// Key-value table for non-sensitive local user settings
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
