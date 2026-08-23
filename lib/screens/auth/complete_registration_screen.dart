import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_providers.dart';
import '../../providers/complete_registration_controller.dart';

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

    return Scaffold(
      appBar: AppBar(title: const Text('Lengkapi Pendaftaran')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Akun kamu belum lengkap. Lengkapi sebagai siswa untuk '
                  'melanjutkan.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Nama'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                ),
                const SizedBox(height: 24),
                if (state.hasError)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text('Gagal menyimpan profil. Silakan coba lagi.'),
                  ),
                FilledButton(
                  onPressed: state.isLoading ? null : _submit,
                  child: state.isLoading
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Lengkapi sebagai Siswa'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => ref.read(authServiceProvider).signOut(),
                  child: const Text('Keluar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
