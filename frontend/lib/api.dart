import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';
import 'session.dart';

const String baseUrl = 'http://127.0.0.1:8000';

class ApiException implements Exception {
  final int status;
  final String message;
  ApiException(this.status, this.message);

  @override
  String toString() => message;
}

String _errorMessage(http.Response res) {
  try {
    final body = jsonDecode(res.body);
    final d = body['detail'];
    if (d is String) return d;
    if (d is List && d.isNotEmpty) {
      final first = d.first as Map<String, dynamic>;
      return (first['msg'] ?? '').toString().replaceFirst('Value error, ', '');
    }
  } catch (_) {}
  return 'Something went wrong (${res.statusCode})';
}

class Api {
  static Future<dynamic> _request(
    String method,
    String path, {
    Object? body,
    bool auth = false,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{
      if (body != null) 'Content-Type': 'application/json',
      if (auth && session.token != null)
        'Authorization': 'Bearer ${session.token}',
    };

    final http.Response res;
    switch (method) {
      case 'POST':
        res = await http.post(uri, headers: headers, body: jsonEncode(body));
      case 'DELETE':
        res = await http.delete(uri, headers: headers);
      default:
        res = await http.get(uri, headers: headers);
    }

    if (res.statusCode == 401 && auth) await session.clear();
    if (res.statusCode >= 400) {
      throw ApiException(res.statusCode, _errorMessage(res));
    }
    return jsonDecode(res.body);
  }

  static Future<List<Job>> jobs({int? areaId, int? categoryId}) async {
    final query = [
      if (areaId != null) 'area_id=$areaId',
      if (categoryId != null) 'category_id=$categoryId',
    ].join('&');
        final data = await _request(
        'GET', query.isEmpty ? '/jobs' : '/jobs?$query',
        auth: true) as List;
    return data.map((e) => Job.fromJson(e as Map<String, dynamic>)).toList();
  }
  


  static Future<List<Option>> options(String path) async {
    final data = await _request('GET', path) as List;
    return data
        .map((e) => Option.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Map<String, dynamic>> login(String phone, String password) async {
    final res = await _request('POST', '/auth/login',
        body: {'phone': phone, 'password': password});
    return res as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> register(Map<String, dynamic> body) async {
    final res = await _request('POST', '/auth/register', body: body);
    return res as Map<String, dynamic>;
  }

  static Future<List<Sub>> subscriptions() async {
    final data = await _request('GET', '/subscriptions', auth: true) as List;
    return data.map((e) => Sub.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> subscribe(int categoryId, int areaId) async {
    await _request('POST', '/subscriptions',
        body: {'category_id': categoryId, 'area_id': areaId}, auth: true);
  }

  static Future<void> unsubscribe(int id) async {
    await _request('DELETE', '/subscriptions/$id', auth: true);
  }
    static Future<List<Job>> myJobs() async {
    final data = await _request('GET', '/jobs/mine', auth: true) as List;
    return data.map((e) => Job.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> createJob(Map<String, dynamic> body) async {
    await _request('POST', '/jobs', body: body, auth: true);
  }

  static Future<List<Map<String, dynamic>>> pendingEmployers() async {
    final data =
        await _request('GET', '/admin/employers/pending', auth: true) as List;
    return data.map((e) => e as Map<String, dynamic>).toList();
  }

  static Future<List<Job>> pendingJobs() async {
    final data = await _request('GET', '/admin/jobs/pending', auth: true) as List;
    return data.map((e) => Job.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> verifyEmployer(int id) async {
    await _request('POST', '/admin/employers/$id/verify', auth: true);
  }

  static Future<void> approveJob(int id) async {
    await _request('POST', '/admin/jobs/$id/approve', auth: true);
  }

  static Future<void> rejectJob(int id) async {
    await _request('POST', '/admin/jobs/$id/reject', auth: true);
  }
    static Future<EmployerInfo> employerMe() async {
    final res = await _request('GET', '/employer/me', auth: true);
    return EmployerInfo.fromJson(res as Map<String, dynamic>);
  }

  static Future<void> uploadDocument(
      String docType, List<int> bytes, String filename) async {
    final req = http.MultipartRequest(
        'POST', Uri.parse('$baseUrl/employer/documents'));
    req.headers['Authorization'] = 'Bearer ${session.token}';
    req.fields['doc_type'] = docType;
    req.files
        .add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode == 401) await session.clear();
    if (res.statusCode >= 400) {
      throw ApiException(res.statusCode, _errorMessage(res));
    }
  }

  static Future<void> deleteDocument(int id) async {
    await _request('DELETE', '/employer/documents/$id', auth: true);
  }

  static Future<String> documentUrl(int docId) async {
    final res = await _request('GET', '/admin/documents/$docId/link',
        auth: true) as Map<String, dynamic>;
    return '$baseUrl${res['path']}';
  }

  static Future<void> rejectEmployer(int id, String reason) async {
    await _request('POST', '/admin/employers/$id/reject',
        body: {'reason': reason}, auth: true);
  }
}
