import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/sign_up_controller.dart';
import '../../theme/theme.dart';
import '../../widgets/app_brand.dart';
import '../../widgets/app_feedback.dart';
import 'login_screen.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _teacherCodeController = TextEditingController();
  bool _asTeacher = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _teacherCodeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    await ref
        .read(signUpControllerProvider.notifier)
        .submit(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
          asTeacher: _asTeacher,
          teacherCode: _asTeacher ? _teacherCodeController.text.trim() : null,
        );
  }

  String _friendlyError(Object error) {
    if (error is InvalidTeacherCodeException) {
      return 'Kode akses tidak valid.';
    }
    if (error is FirebaseAuthException) {
      return switch (error.code) {
        'email-already-in-use' => 'Email ini sudah terdaftar.',
        'invalid-email' => 'Format email tidak valid.',
        'weak-password' => 'Password terlalu lemah (minimal 6 karakter).',
        _ => 'Gagal mendaftar. Silakan coba lagi.',
      };
    }
    return 'Gagal mendaftar. Silakan coba lagi.';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(signUpControllerProvider);

    return AppAuthScaffold(
      title: 'Daftar',
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nama'),
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: AppSpacing.md),
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
                autofillHints: const [AutofillHints.newPassword],
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Daftar sebagai Guru?'),
                value: _asTeacher,
                onChanged: (value) => setState(() => _asTeacher = value),
              ),
              if (_asTeacher) ...[
                const SizedBox(height: AppSpacing.xs),
                TextFormField(
                  controller: _teacherCodeController,
                  decoration: const InputDecoration(
                    labelText: 'Kode Akses Guru',
                    prefixIcon: Icon(Icons.key_outlined),
                  ),
                  autocorrect: false,
                  textCapitalization: TextCapitalization.none,
                  validator: (v) =>
                      (_asTeacher && (v == null || v.trim().isEmpty))
                      ? 'Wajib diisi'
                      : null,
                ),
              ],
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
                    : const Text('Daftar'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ),
                child: const Text('Sudah punya akun? Masuk'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
