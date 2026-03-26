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
  String _difficultyFilter = 'All';

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
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(child: _buildBody(theme)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/create-reference'),
        icon: const Icon(Icons.add),
        label: const Text('Create from Video'),
      ),
    );
  }

  void _showManageSheet(BuildContext context, ReferenceChoreography ref) {
    final durationSec = ref.poses.duration.inMilliseconds / 1000;
    final isUserCreated = !ref.id.contains('_'); // Simple heuristic; built-ins use underscored IDs.
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ref.name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${ref.style.name} · ${ref.difficulty} · ${durationSec.toStringAsFixed(1)}s',
              style: const TextStyle(color: Colors.white54),
            ),
            if (ref.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                ref.description,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              '${ref.poses.frames.length} frames · ${ref.personCount} person(s) · ${ref.bpm.round()} BPM',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 24),
            if (isUserCreated)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final confirmed = await _confirmDelete(ref.name);
                    if (confirmed) {
                      final repo = ServiceLocator.instance.get<ReferenceRepository>();
                      repo.delete(ref.id);
                      _loadReferences();
                    }
                  },
                  icon: const Icon(Icons.delete),
                  label: const Text('Delete Reference'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                  ),
                ),
              )
            else
              const Center(
                child: Text(
                  'Built-in references cannot be deleted',
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(String name) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Reference'),
            content: Text('Delete "$name"? This cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Widget _buildFilterChips() {
    const filters = ['All', 'beginner', 'intermediate', 'advanced'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: filters.map((f) {
          final label = f == 'All' ? 'All' : f[0].toUpperCase() + f.substring(1);
          final selected = _difficultyFilter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(label),
              selected: selected,
              onSelected: (_) => setState(() => _difficultyFilter = f),
            ),
          );
        }).toList(),
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

    final filtered = _difficultyFilter == 'All'
        ? refs
        : refs.where((r) => r.difficulty == _difficultyFilter).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          'No ${_difficultyFilter} references',
          style: const TextStyle(color: Colors.white54, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final ref = filtered[index];
        return _ReferenceTile(
          reference: ref,
          mode: widget.mode,
          onTap: () {
            if (widget.mode == 'capture') {
              context.go('/capture?ref=${ref.id}');
            } else if (widget.mode == 'upload') {
              context.go('/upload?ref=${ref.id}');
            } else if (widget.mode == 'manage') {
              _showManageSheet(context, ref);
            }
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
        onTap: onTap,
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
        trailing: Icon(
          mode == 'manage' ? Icons.info_outline : Icons.chevron_right,
        ),
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
