import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/account_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_typography.dart';
import '../../utils/friendly_error.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/inset_group.dart';

/// Picture choices: clinical and neutral symbols; "none" shows initials.
const _avatars = ['🩺', '🩻', '💊', '🧪', '🫀', '🧠', '👶', '🌿', '⭐', '☀️', '🌙', '🦉'];

Future<void> showEditAccount(BuildContext context) => showAppSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _EditAccountSheet(),
    );

class _EditAccountSheet extends StatefulWidget {
  const _EditAccountSheet();

  @override
  State<_EditAccountSheet> createState() => _EditAccountSheetState();
}

class _EditAccountSheetState extends State<_EditAccountSheet> {
  late final _me = context.read<AccountProvider>().currentUser!;
  late final _name = TextEditingController(text: _me.name);
  late final _specialty = TextEditingController(text: _me.specialty ?? '');
  late String _avatar = _me.avatarEmoji ?? '';
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _specialty.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final account = context.read<AccountProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await account.updateProfile(
      name: _name.text.trim(),
      specialty: _specialty.text.trim(),
      avatarEmoji: _avatar,
    );
    if (!mounted) return;
    if (ok) {
      navigator.pop();
    } else {
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(
          backgroundColor: AppColors.danger, content: Text("Not saved — ${friendlyError(account.error ?? 'error')}")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final valid = _name.text.trim().length >= 2;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                CupertinoButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
                Expanded(
                  child: Text('Edit Profile',
                      textAlign: TextAlign.center, style: AppTypography.headline(color: AppColors.textPrimary)),
                ),
                _saving
                    ? const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: CupertinoActivityIndicator())
                    : CupertinoButton(
                        onPressed: valid ? _save : null,
                        child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  InsetGroup(
                    dividerIndent: 16,
                    children: [
                      InsetTextRow(
                        label: 'Name',
                        controller: _name,
                        placeholder: 'Shown on your notes',
                        textCapitalization: TextCapitalization.words,
                        onChanged: (_) => setState(() {}),
                      ),
                      InsetTextRow(
                        label: 'Specialty',
                        controller: _specialty,
                        placeholder: 'Optional, e.g. Neonatology',
                        textCapitalization: TextCapitalization.words,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  InsetGroup(
                    header: 'Picture',
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _choice('', label: 'AB'),
                            for (final e in _avatars) _choice(e),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _choice(String emoji, {String? label}) {
    final on = _avatar == emoji;
    return Semantics(
      button: true,
      selected: on,
      label: emoji.isEmpty ? 'Use initials' : 'Picture $emoji',
      child: GestureDetector(
        onTap: () => setState(() => _avatar = emoji),
        child: Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surface,
            border: Border.all(color: on ? AppColors.primary : Colors.transparent, width: 2.5),
          ),
          child: emoji.isEmpty
              ? Text(label ?? '', style: AppTypography.subheadline(color: AppColors.textSecondary, weight: FontWeight.w700))
              : Text(emoji, style: const TextStyle(fontSize: 24)),
        ),
      ),
    );
  }
}
