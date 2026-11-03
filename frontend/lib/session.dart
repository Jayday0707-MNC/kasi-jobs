import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Session extends ChangeNotifier {
  String? token;
  Map<String, dynamic>? user;

  bool get loggedIn => token != null;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    token = p.getString('token');
    final u = p.getString('user');
    user = u == null ? null : jsonDecode(u) as Map<String, dynamic>;
    notifyListeners();
  }

  Future<void> save(String t, Map<String, dynamic> u) async {
    token = t;
    user = u;
    final p = await SharedPreferences.getInstance();
    await p.setString('token', t);
    await p.setString('user', jsonEncode(u));
    notifyListeners();
  }

  Future<void> clear() async {
    token = null;
    user = null;
    final p = await SharedPreferences.getInstance();
    await p.remove('token');
    await p.remove('user');
    notifyListeners();
  }
}

final session = Session();