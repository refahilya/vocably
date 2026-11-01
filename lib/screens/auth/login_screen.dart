import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/login_controller.dart';
import '../../theme/theme.dart';
import '../../widgets/app_brand.dart';
import '../../widgets/app_feedback.dart';
import 'sign_up_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(loginControllerProvider.notifier)
        .submit(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
  }

  String _friendlyError(Object error) {
    if (error is FirebaseAuthException) {
      return switch (error.code) {
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' => 'Email atau password salah.',
        'invalid-email' => 'Format email tidak valid.',
        _ => 'Gagal masuk. Silakan coba lagi.',
      };
    }
    return 'Gagal masuk. Silakan coba lagi.';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginControllerProvider);

    return AppAuthScaffold(
      title: 'Masuk',
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) {
                  if (!state.isLoading) _submit();
                },
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (state.hasError)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.smd),
                  child: AppNotice(
                    text: _friendlyError(state.error!),
                    tone: AppTone.error,
                  ),
                ),
              FilledButton(
                onPressed: state.isLoading ? null : _submit,
                child: state.isLoading
                    ? const AppButtonSpinner()
                    : const Text('Masuk'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SignUpScreen()),
                ),
                child: const Text('Belum punya akun? Daftar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
