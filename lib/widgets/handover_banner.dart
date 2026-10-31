import 'package:flutter/material.dart';

import '../models/handover_session.dart';
import '../screens/shared/handover_session_screen.dart';
import '../services/handover_service.dart';
import '../services/supabase_service.dart';
import '../utils/app_theme.dart';
import '../utils/formatting.dart';
import '../utils/stream_cache.dart';
import 'inset_group.dart';

/// Today: a handover someone else started in one of my wards (in the
/// last 12 hours) — the incoming person opens it here to receive.
class HandoverBanner extends StatelessWidget {
  const HandoverBanner({super.key, required this.wardIds});

  final List<String> wardIds;

  static final _streams = StreamCache<List<HandoverSession>>();

  @override
  Widget build(BuildContext context) {
    if (wardIds.isEmpty) return const SizedBox.shrink();
    final me = supabase.auth.currentUser?.id;
    return StreamBuilder<List<HandoverSession>>(
      stream: _streams.get(([...wardIds]..sort()).join(','), () => HandoverService().sessions(wardIds)),
      builder: (context, snap) {
        final now = DateTime.now();
        final waiting = (snap.data ?? const <HandoverSession>[])
            .where((s) => s.isOpen && s.givenBy != me && now.difference(s.startedAt) < const Duration(hours: 12))
            .toList();
        if (waiting.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: InsetGroup(children: [
            for (final s in waiting)
              SettingsRow(
                icon: Icons.handshake_outlined,
                iconColor: AppColors.stable,
                title: 'Handover from ${s.givenByName.isEmpty ? 'a colleague' : s.givenByName}',
                subtitle: '${s.scopeLabel} · started ${formatClock(s.startedAt)} — tap to receive',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => HandoverSessionScreen(handoverId: s.id, wardId: s.wardId))),
              ),
          ]),
        );
      },
    );
  }
}
