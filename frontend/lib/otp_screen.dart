import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api.dart';
import 'session.dart';
import 'theme.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({
    super.key,
    required this.phone,
    required this.password,
    required this.hasEmail,
    required this.sendOnOpen,
    this.channel = 'sms',
  });
  final String phone;
  final String password;
  final bool hasEmail;
  final bool sendOnOpen;
  final String channel;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final code = TextEditingController();
  late String channel = widget.channel;
  Timer? timer;
  int wait = 0;
  bool busy = false;
  String? error;
  String? info;

  @override
  void initState() {
    super.initState();
    if (widget.sendOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _send());
    } else {
      wait = 60;
      _startTimer();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    code.dispose();
    super.dispose();
  }

  void _startTimer() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (wait <= 1) {
        t.cancel();
        setState(() => wait = 0);
      } else {
        setState(() => wait--);
      }
    });
  }

  Future<void> _send() async {
    setState(() {
      busy = true;
      error = null;
      info = null;
    });
    try {
      await Api.sendOtp(widget.phone, widget.password, channel: channel);
      if (!mounted) return;
      setState(() {
        info = channel == 'email'
            ? 'We sent a new code to your email.'
            : 'We sent a new code by SMS.';
        wait = 60;
      });
      _startTimer();
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) setState(() => error = 'Could not reach the server.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _verify() async {
    final c = code.text.trim();
    if (c.length != 6) {
      setState(() => error = 'Enter the 6-digit code.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final res = await Api.verifyOtp(widget.phone, widget.password, c);
      await session.save(
        res['access_token'] as String,
        res['user'] as Map<String, dynamic>,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) setState(() => error = 'Could not reach the server.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final p = widget.phone;
    final last4 = p.length >= 4 ? p.substring(p.length - 4) : p;
    final target = channel == 'email'
        ? 'We sent a 6-digit code to your email.'
        : 'We sent a 6-digit code by SMS to the number ending $last4.';

    return Scaffold(
      appBar: AppBar(title: const Text('Verify your account')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [kViolet, kSky],
                    ),
                  ),
                  child: Icon(
                    channel == 'email'
                        ? Icons.mark_email_read_rounded
                        : Icons.sms_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Enter your code',
                textAlign: TextAlign.center,
                style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                target,
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: code,
                autofocus: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 12,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '------',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onChanged: (v) {
                  if (v.length == 6 && !busy) _verify();
                },
                onSubmitted: (_) => _verify(),
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.error)),
              ],
              if (info != null) ...[
                const SizedBox(height: 12),
                Text(info!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.primary)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: busy ? null : _verify,
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54)),
                child: busy
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Text('Verify'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: (busy || wait > 0) ? null : _send,
                child: Text(wait > 0 ? 'Send a new code in ${wait}s' : 'Send a new code'),
              ),
              if (widget.hasEmail && channel == 'sms')
                TextButton(
                  onPressed: (busy || wait > 0)
                      ? null
                      : () {
                          channel = 'email';
                          _send();
                        },
                  child: const Text('Send the code to my email instead'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}