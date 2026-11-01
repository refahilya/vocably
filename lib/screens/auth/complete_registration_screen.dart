import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_providers.dart';
import '../../providers/complete_registration_controller.dart';
import '../../theme/theme.dart';
import '../../widgets/app_brand.dart';
import '../../widgets/app_feedback.dart';

/// Shown when Firebase Auth has a signed-in user but `users/{uid}` doesn't
/// exist yet (see [AppAuthNeedsProfile]). Always completes registration as
/// a default `siswa` — never silently grants `guru`.
class CompleteRegistrationScreen extends ConsumerStatefulWidget {
  const CompleteRegistrationScreen({
    super.key,
    required this.uid,
    required this.email,
  });

  final String uid;
  final String email;

  @override
  ConsumerState<CompleteRegistrationScreen> createState() =>
      _CompleteRegistrationScreenState();
}

class _CompleteRegistrationScreenState
    extends ConsumerState<CompleteRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(completeRegistrationControllerProvider.notifier)
        .submit(
          uid: widget.uid,
          email: widget.email,
          name: _nameController.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(completeRegistrationControllerProvider);

    return AppAuthScaffold(
      title: 'Lengkapi Pendaftaran',
      subtitle:
          'Akun kamu belum lengkap. Lengkapi sebagai siswa untuk '
          'melanjutkan.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nama'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (state.hasError)
              const Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.smd),
                child: AppNotice(
                  text: 'Gagal menyimpan profil. Silakan coba lagi.',
                  tone: AppTone.error,
                ),
              ),
            FilledButton(
              onPressed: state.isLoading ? null : _submit,
              child: state.isLoading
                  ? const AppButtonSpinner()
                  : const Text('Lengkapi sebagai Siswa'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () => ref.read(authServiceProvider).signOut(),
              child: const Text('Keluar'),
            ),
          ],
        ),
      ),
    );
  }
}
