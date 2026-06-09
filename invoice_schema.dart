import 'package:drift/drift.dart';

// ─────────────────────────────────────────────────────────────────────────
// ملاحظات التصميم:
// • العملة تُخزّن كرمز ISO نصّي: 'USD' | 'SAR' | 'YER' ...
// • المبالغ تُخزّن كـ "وحدات صغرى" (المبلغ × 100) باستخدام int — لتجنّب
//   أخطاء الكسور العشرية في الجمع. حوّلها للعرض بقسمتها على 100.
// • لا توجد ضريبة (حسب طلبك).
// • كشف الحساب يُحسب بعملة حساب العميل (accountCurrency):
//     مدين  لكل فاتورة = totalMinor   × fxRateToAccount
//     دائن  لكل تحصيل  = amountMinor  × fxRateToAccount
//     الرصيد = Σ(مدين) − Σ(دائن)
// ─────────────────────────────────────────────────────────────────────────

enum InvoiceStatus { draft, sent, paid, partiallyPaid, overdue, cancelled }

/// ملف شركتي — صف واحد فقط (id = 1).
class Companies extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get logoPath => text().nullable()();        // مسار الشعار محلياً
  TextColumn get address => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get bankDetails => text().nullable()();      // الحساب/المحفظة للتحويل
  TextColumn get defaultCurrency => text().withDefault(const Constant('USD'))();
  // ترقيم الفواتير
  TextColumn get invoicePrefix => text().withDefault(const Constant('INV-'))();
  IntColumn get invoiceCounter => integer().withDefault(const Constant(0))();
}

/// العملاء (الجهات اللي تفوترها).
class Clients extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get contactPerson => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get notes => text().nullable()();
  // عملة حساب العميل — يُعرض بها كشف الحساب والرصيد
  TextColumn get accountCurrency => text().withDefault(const Constant('USD'))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// الفواتير.
class Invoices extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get number => text().unique()();            // INV-2026-0007
  IntColumn get clientId => integer().references(Clients, #id)();
  DateTimeColumn get issueDate => dateTime()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  IntColumn get status =>
      intEnum<InvoiceStatus>().withDefault(const Constant(0))(); // draft
  // عملة الفاتورة كما تظهر في الـ PDF
  TextColumn get currency => text()();
  // سعر صرف عملة الفاتورة → عملة حساب العميل (1.0 عند التطابق)
  RealColumn get fxRateToAccount => real().withDefault(const Constant(1.0))();
  // الإجمالي بعملة الفاتورة (وحدات صغرى) — مُشتق من البنود، يُخزّن للسرعة
  IntColumn get totalMinor => integer().withDefault(const Constant(0))();
  TextColumn get notes => text().nullable()();
  // إن وُلّدت من اشتراك متكرر
  IntColumn get subscriptionId =>
      integer().nullable().references(Subscriptions, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// بنود الفاتورة.
class InvoiceItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get invoiceId => integer().references(Invoices, #id)();
  TextColumn get description => text()();
  RealColumn get quantity => real().withDefault(const Constant(1))();
  IntColumn get unitPriceMinor => integer()();           // سعر الوحدة (وحدات صغرى)
  IntColumn get lineTotalMinor => integer()();           // = quantity × unitPriceMinor
}

/// التحصيلات (المدفوعات).
class Payments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get clientId => integer().references(Clients, #id)();
  // ربط اختياري بفاتورة:
  //   • اتركه فارغاً  → نظام الرصيد المتدحرج (موصى به)
  //   • عيّن قيمة     → نظام البند المفتوح (مطابقة دفعة بفاتورة)
  IntColumn get invoiceId =>
      integer().nullable().references(Invoices, #id)();
  DateTimeColumn get paymentDate => dateTime()();
  IntColumn get amountMinor => integer()();              // المبلغ بعملة الدفع
  TextColumn get currency => text()();                   // عملة الدفع الفعلية
  // سعر صرف عملة الدفع → عملة حساب العميل
  RealColumn get fxRateToAccount => real().withDefault(const Constant(1.0))();
  TextColumn get method => text().nullable()();          // تحويل بنكي / محفظة ...
  TextColumn get notes => text().nullable()();
}

/// الاشتراكات المتكررة — تولّد فاتورة شهرية بنقرة واحدة.
class Subscriptions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get clientId => integer().references(Clients, #id)();
  TextColumn get title => text()();                      // وصف الباقة
  IntColumn get unitPriceMinor => integer()();
  TextColumn get currency => text()();
  IntColumn get billingDayOfMonth =>
      integer().withDefault(const Constant(1))();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  // آخر فترة وُلّدت لها فاتورة — لمنع التكرار عند ضغط زر "توليد فواتير الشهر"
  DateTimeColumn get lastGeneratedPeriod => dateTime().nullable()();
}
