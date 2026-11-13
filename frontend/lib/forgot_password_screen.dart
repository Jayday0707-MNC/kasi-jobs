// frontend/lib/forgot_password_screen.dart
// Step 1: enter phone number -> a code is emailed.  Step 2: enter code + new password.
// Uses the `http` package and `baseUrl` from lib/api.dart (same as the rest of your app).
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'api.dart' show baseUrl;

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();

  bool _codeSent = false;
  bool _busy = false;
  bool _hidePassword = true;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  String _errorText(dynamic data, int status) {
    if (data is Map && data['detail'] is String) return data['detail'] as String;
    if (data is Map && data['detail'] is List && (data['detail'] as List).isNotEmpty) {
      final first = (data['detail'] as List).first;
      if (first is Map && first['msg'] is String) {
        return (first['msg'] as String).replaceFirst('Value error, ', '');
      }
    }
    return 'Something went wrong (error $status). Please try again.';
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl$path'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 60)); // Render may need time to wake up
    dynamic data;
    try {
      data = jsonDecode(res.body);
    } catch (_) {}
    if (res.statusCode >= 400) throw _errorText(data, res.statusCode);
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<void> _sendCode() async {
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await _post('/auth/forgot-password', {'phone': _phone.text.trim()});
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _info = 'If this number has an email on its account, we sent a 6-digit code to it. '
            'Check your inbox and spam folder.';
      });
    } catch (e) {
      if (mounted) setState(() => _error = e is String ? e : 'Could not reach the server. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _post('/auth/reset-password', {
        'phone': _phone.text.trim(),
        'code': _code.text.trim(),
        'new_password': _password.text,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated. You can sign in now.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = e is String ? e : 'Could not reach the server. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot password')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              _codeSent
                  ? 'Enter the code we emailed you and choose a new password.'
                  : 'Enter the phone number you registered with. We will email a code to the address on your account.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _phone,
              enabled: !_codeSent,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                hintText: '082 123 4567',
                border: OutlineInputBorder(),
              ),
            ),
            if (_codeSent) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _code,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: '6-digit code',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _password,
                obscureText: _hidePassword,
                decoration: InputDecoration(
                  labelText: 'New password (8+ characters)',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_hidePassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _hidePassword = !_hidePassword),
                  ),
                ),
              ),
            ],
            if (_info != null) ...[
              const SizedBox(height: 12),
              Text(_info!, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : (_codeSent ? _reset : _sendCode),
              child: _busy
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_codeSent ? 'Set new password' : 'Send code'),
            ),
            if (_codeSent)
              TextButton(
                onPressed: _busy ? null : _sendCode,
                child: const Text('Send a new code'),
              ),
          ],
        ),
      ),
    );
  }
}