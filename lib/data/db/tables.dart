import 'package:drift/drift.dart';

// المبالغ تُخزّن كوحدات صغرى (المبلغ × 100) بـ int. العملة رمز ISO نصّي.
// بلا ضريبة. كشف الحساب بعملة حساب العميل عبر fxRateToAccount.

enum InvoiceStatus { draft, sent, paid, partiallyPaid, overdue, cancelled }

/// ملف شركتي — صف واحد فقط (id = 1).
class Companies extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get logoPath => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get bankDetails => text().nullable()();
  TextColumn get defaultCurrency => text().withDefault(const Constant('USD'))();
  TextColumn get invoicePrefix => text().withDefault(const Constant('INV-'))();
  IntColumn get invoiceCounter => integer().withDefault(const Constant(0))();
}

class Clients extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get contactPerson => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get accountCurrency => text().withDefault(const Constant('USD'))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Invoices extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get number => text().unique()();
  IntColumn get clientId => integer().references(Clients, #id)();
  DateTimeColumn get issueDate => dateTime()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  IntColumn get status =>
      intEnum<InvoiceStatus>().withDefault(const Constant(0))();
  TextColumn get currency => text()();
  RealColumn get fxRateToAccount => real().withDefault(const Constant(1.0))();
  IntColumn get totalMinor => integer().withDefault(const Constant(0))();
  TextColumn get notes => text().nullable()();
  IntColumn get subscriptionId =>
      integer().nullable().references(Subscriptions, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class InvoiceItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get invoiceId => integer().references(Invoices, #id)();
  TextColumn get description => text()();
  RealColumn get quantity => real().withDefault(const Constant(1))();
  IntColumn get unitPriceMinor => integer()();
  IntColumn get lineTotalMinor => integer()();
}

class Payments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get clientId => integer().references(Clients, #id)();
  IntColumn get invoiceId =>
      integer().nullable().references(Invoices, #id)();
  DateTimeColumn get paymentDate => dateTime()();
  IntColumn get amountMinor => integer()();
  TextColumn get currency => text()();
  RealColumn get fxRateToAccount => real().withDefault(const Constant(1.0))();
  TextColumn get method => text().nullable()();
  TextColumn get notes => text().nullable()();
}

class Subscriptions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get clientId => integer().references(Clients, #id)();
  TextColumn get title => text()();
  IntColumn get unitPriceMinor => integer()();
  TextColumn get currency => text()();
  IntColumn get billingDayOfMonth =>
      integer().withDefault(const Constant(1))();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get lastGeneratedPeriod => dateTime().nullable()();
}
