import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:dance_evaluation/core/models/reference_choreography.dart';
import 'package:dance_evaluation/core/services/service_locator.dart';
import 'package:dance_evaluation/data/reference_repository.dart';

/// Shows available reference choreographies and lets the user pick one
/// to evaluate against, or create a new one from a video upload.
class ReferenceListScreen extends StatefulWidget {
  const ReferenceListScreen({super.key, required this.mode});

  /// 'capture', 'upload', or 'manage' — determines behavior when a reference
  /// is tapped. In capture/upload mode, navigates to that flow. In manage mode,
  /// shows reference details.
  final String mode;

  @override
  State<ReferenceListScreen> createState() => _ReferenceListScreenState();
}

class _ReferenceListScreenState extends State<ReferenceListScreen> {
  List<ReferenceChoreography>? _references;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReferences();
  }

  Future<void> _loadReferences() async {
    try {
      final repo = ServiceLocator.instance.get<ReferenceRepository>();
      final refs = await repo.listAll();
      if (mounted) setState(() => _references = refs);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.mode == 'manage' ? 'My References' : 'Choose Reference'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _buildBody(theme),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/create-reference'),
        icon: const Icon(Icons.add),
        label: const Text('Create from Video'),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
      );
    }

    final refs = _references;
    if (refs == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (refs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.library_music, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            const Text(
              'No references yet',
              style: TextStyle(fontSize: 18, color: Colors.white70),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create one from a video to get started.',
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: refs.length,
      itemBuilder: (context, index) {
        final ref = refs[index];
        return _ReferenceTile(
          reference: ref,
          mode: widget.mode,
          onTap: () {
            if (widget.mode == 'capture') {
              context.go('/capture?ref=${ref.id}');
            } else if (widget.mode == 'upload') {
              context.go('/upload?ref=${ref.id}');
            }
            // In 'manage' mode, tap does nothing for now.
          },
        );
      },
    );
  }
}

class _ReferenceTile extends StatelessWidget {
  const _ReferenceTile({
    required this.reference,
    required this.onTap,
    this.mode = 'capture',
  });

  final ReferenceChoreography reference;
  final VoidCallback onTap;
  final String mode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final frameCount = reference.poses.frames.length;
    final durationSec = reference.poses.duration.inMilliseconds / 1000;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: theme.colorScheme.surface,
      child: ListTile(
        onTap: mode == 'manage' ? null : onTap,
        leading: Icon(
          _styleIcon(reference.style.name),
          color: theme.colorScheme.primary,
          size: 36,
        ),
        title: Text(reference.name),
        subtitle: Text(
          '${reference.style.name} · ${reference.difficulty} · '
          '${durationSec.toStringAsFixed(1)}s · $frameCount frames',
        ),
        trailing: mode == 'manage' ? null : const Icon(Icons.chevron_right),
      ),
    );
  }

  IconData _styleIcon(String style) {
    switch (style) {
      case 'hipHop':
        return Icons.music_note;
      case 'kPop':
        return Icons.star;
      case 'contemporary':
        return Icons.water_drop;
      default:
        return Icons.directions_run;
    }
  }
}
