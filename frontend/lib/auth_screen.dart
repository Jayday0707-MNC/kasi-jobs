import 'package:flutter/material.dart';
import 'api.dart';
import 'models.dart';
import 'session.dart';

InputDecoration _dec(String label, {String? hint}) => InputDecoration(
      labelText: label,
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    );

class SignInPrompt extends StatelessWidget {
  const SignInPrompt({super.key, required this.title, required this.message});
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 48, color: cs.outline),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AuthScreen()),
              ),
              child: const Text('Sign in or create account'),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthScreen extends StatefulWidget {
    const AuthScreen({super.key, this.startOnRegister = false});
  final bool startOnRegister;
  
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final business = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();

  bool register = false;
  bool employer = false;
  bool busy = false;
  bool hidePassword = true;
  bool consentSms = false;
  bool consentEmail = false;
  String? error;
  List<Option> areas = [];
  int? areaId;

  @override
  void initState() {
    super.initState();   
      register = widget.startOnRegister;
    Api.options('/areas').then((a) {
      if (mounted) setState(() => areas = a);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    name.dispose();
    business.dispose();
    phone.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final Map<String, dynamic> res;
      if (register) {
        res = await Api.register({
          'full_name': name.text.trim(),
          'phone': phone.text.trim(),
          if (email.text.trim().isNotEmpty) 'email': email.text.trim(),
          'password': password.text,
          'role': employer ? 'employer' : 'seeker',
          if (employer) 'business_name': business.text.trim(),
          if (areaId != null) 'area_id': areaId,
          'consent_sms': !employer && consentSms,
          'consent_email': !employer && consentEmail,
        });
      } else {
        res = await Api.login(phone.text.trim(), password.text);
      }
      await session.save(
        res['access_token'] as String,
        res['user'] as Map<String, dynamic>,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not reach the server. Is the backend running?');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(register ? 'Create account' : 'Sign in')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Sign in')),
                    ButtonSegment(value: true, label: Text('Create account')),
                  ],
                  selected: {register},
                  onSelectionChanged: (s) => setState(() {
                    register = s.first;
                    error = null;
                  }),
                ),
                if (register) ...[
                  const SizedBox(height: 16),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        label: Text('Job seeker'),
                        icon: Icon(Icons.person_search_outlined),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text('Employer'),
                        icon: Icon(Icons.business_center_outlined),
                      ),
                    ],
                    selected: {employer},
                    onSelectionChanged: (s) =>
                        setState(() => employer = s.first),
                  ),
                ],
                const SizedBox(height: 24),
                if (register) ...[
                  TextFormField(
                    controller: name,
                    textCapitalization: TextCapitalization.words,
                    decoration:
                        _dec(employer ? 'Your name (contact person)' : 'Full name'),
                    validator: (v) => (v == null || v.trim().length < 2)
                        ? 'Enter your name'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  if (employer) ...[
                    TextFormField(
                      controller: business,
                      textCapitalization: TextCapitalization.words,
                      decoration: _dec('Business name'),
                      validator: (v) => (v == null || v.trim().length < 2)
                          ? 'Enter your business name'
                          : null,
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
                TextFormField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: _dec('Phone number', hint: '071 234 5678'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Enter your phone number'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: password,
                  obscureText: hidePassword,
                  decoration: _dec('Password').copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(hidePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () =>
                          setState(() => hidePassword = !hidePassword),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter your password';
                    if (register && v.length < 8) {
                      return 'Use at least 8 characters';
                    }
                    return null;
                  },
                ),
                if (register) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _dec('Email (optional)'),
                    validator: (v) {
                      final t = v?.trim() ?? '';
                      if (!employer && consentEmail && t.isEmpty) {
                        return 'Enter your email to get email alerts';
                      }
                      if (t.isNotEmpty && !t.contains('@')) {
                        return 'Enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    initialValue: areaId,
                    decoration: _dec(employer
                        ? 'Where is your business? (optional)'
                        : 'Where do you live? (optional)'),
                    items: [
                      for (final a in areas)
                        DropdownMenuItem(value: a.id, child: Text(a.name)),
                    ],
                    onChanged: (v) => areaId = v,
                  ),
                  if (!employer) ...[
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: consentSms,
                      onChanged: (v) =>
                          setState(() => consentSms = v ?? false),
                      title:
                          const Text('I agree to receive job alerts by SMS'),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: consentEmail,
                      onChanged: (v) =>
                          setState(() => consentEmail = v ?? false),
                      title:
                          const Text('I agree to receive job alerts by email'),
                    ),
                  ],
                ],
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!, style: TextStyle(color: cs.error)),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: busy ? null : _submit,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: busy
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : Text(register ? 'Create account' : 'Sign in'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}