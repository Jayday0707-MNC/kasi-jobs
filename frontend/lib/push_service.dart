// lib/push_service.dart - Android push notifications with Firebase Cloud Messaging.
// Assumes you use the `http` package and have `baseUrl` in lib/api.dart (ADAPT the import path if needed).
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'api.dart' show baseUrl;

class PushService {
  static bool _listening = false;

  /// Call right after a successful login, passing the user's JWT.
  static Future<void> registerDevice(String jwt) async {
    if (kIsWeb) return; // push is Android-only for now
    final fm = FirebaseMessaging.instance;

    // Android 13+ asks the user for permission here.
    final settings = await fm.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    final token = await fm.getToken();
    if (token != null) await _send(jwt, token);

    if (!_listening) {
      _listening = true;
      fm.onTokenRefresh.listen((t) => _send(jwt, t));
    }
  }

  static Future<void> _send(String jwt, String token) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/devices/register'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwt',
        },
        body: jsonEncode({'token': token, 'platform': 'android'}),
      );
    } catch (_) {
      // not fatal; it retries on the next login
    }
  }
}