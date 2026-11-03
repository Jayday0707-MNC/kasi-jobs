class Option {
  final int id;
  final String name;
  const Option(this.id, this.name);

  factory Option.fromJson(Map<String, dynamic> j) =>
      Option(j['id'] as int, j['name'] as String);
}

class Job {
  final int id;
  final String title;
  final String description;
  final String category;
  final String area;
  final String employer;
  final String? pay;
  final String? howToApply;
  final DateTime? closingDate;
  final String status;

  const Job({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.area,
    required this.employer,
    this.pay,
    this.howToApply,
    this.closingDate,
    this.status = 'approved',
  });

  factory Job.fromJson(Map<String, dynamic> j) => Job(
        id: j['id'] as int,
        title: j['title'] as String,
        description: j['description'] as String,
        category: j['category'] as String,
        area: j['area'] as String,
        employer: j['employer'] as String,
        pay: j['pay'] as String?,
        howToApply: j['how_to_apply'] as String?,
        closingDate: j['closing_date'] == null
            ? null
            : DateTime.parse(j['closing_date'] as String),
        status: (j['status'] as String?) ?? 'approved',
      );

  int? get daysLeft {
    final d = closingDate;
    if (d == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return d.difference(today).inDays;
  }
}

class Sub {
  final int id;
  final String category;
  final String area;
  const Sub(this.id, this.category, this.area);

  factory Sub.fromJson(Map<String, dynamic> j) =>
      Sub(j['id'] as int, j['category'] as String, j['area'] as String);
}
class RequiredDoc {
  final String type;
  final String label;
  const RequiredDoc(this.type, this.label);
}

class EmployerDoc {
  final int id;
  final String docType;
  final String filename;
  final String status;
  final String? reviewNote;

  const EmployerDoc({
    required this.id,
    required this.docType,
    required this.filename,
    required this.status,
    this.reviewNote,
  });

  factory EmployerDoc.fromJson(Map<String, dynamic> j) => EmployerDoc(
        id: j['id'] as int,
        docType: j['doc_type'] as String,
        filename: j['filename'] as String,
        status: j['status'] as String,
        reviewNote: j['review_note'] as String?,
      );
}

class EmployerInfo {
  final String businessName;
  final bool verified;
  final String status;
  final List<RequiredDoc> required;
  final List<EmployerDoc> documents;

  const EmployerInfo({
    required this.businessName,
    required this.verified,
    required this.status,
    required this.required,
    required this.documents,
  });

  factory EmployerInfo.fromJson(Map<String, dynamic> j) => EmployerInfo(
        businessName: j['business_name'] as String,
        verified: j['verified'] as bool,
        status: j['status'] as String,
        required: (j['required'] as List)
            .map((e) => RequiredDoc(e['type'] as String, e['label'] as String))
            .toList(),
        documents: (j['documents'] as List)
            .map((e) => EmployerDoc.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  EmployerDoc? docFor(String type) {
    for (final d in documents.reversed) {
      if (d.docType == type) return d;
    }
    return null;
  }

  int get uploaded => required.where((r) {
        final d = docFor(r.type);
        return d != null && d.status != 'rejected';
      }).length;
}