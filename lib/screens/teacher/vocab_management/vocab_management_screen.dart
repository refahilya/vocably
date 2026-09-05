import 'package:flutter/material.dart';

import '../../../models/app_user.dart';
import '../../../theme/theme.dart';
import 'edit_kata_screen.dart';
import 'tambah_kosakata_screen.dart';

/// Sub-tabs for the guru "Kosakata" destination (`DESIGN_REFERENCE.md` §5.4).
enum VocabManagementTab {
  tambahKosakata,
  editKata,
}

/// The parent wrapper shell for teacher vocabulary management, hosting a
/// segmented control between "Tambah Kosakata" and "Edit Kata".
class VocabManagementScreen extends StatefulWidget {
  const VocabManagementScreen({super.key, required this.profile});

  final AppUser profile;

  @override
  State<VocabManagementScreen> createState() => _VocabManagementScreenState();
}

class _VocabManagementScreenState extends State<VocabManagementScreen> {
  VocabManagementTab _selectedTab = VocabManagementTab.tambahKosakata;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: SegmentedButton<VocabManagementTab>(
            segments: const [
              ButtonSegment(
                value: VocabManagementTab.tambahKosakata,
                label: Text('Tambah Kosakata'),
                icon: Icon(Icons.add),
              ),
              ButtonSegment(
                value: VocabManagementTab.editKata,
                label: Text('Edit Kata'),
                icon: Icon(Icons.edit),
              ),
            ],
            selected: {_selectedTab},
            onSelectionChanged: (newSelection) {
              setState(() {
                _selectedTab = newSelection.first;
              });
            },
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: switch (_selectedTab) {
            VocabManagementTab.tambahKosakata =>
              TambahKosakataScreen(profile: widget.profile),
            VocabManagementTab.editKata =>
              EditKataScreen(profile: widget.profile),
          },
        ),
      ],
    );
  }
}
