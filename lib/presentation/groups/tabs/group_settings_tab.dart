/// Group → Settings tab (V2 GROUPS_AND_ACTIVITIES.md §5 — admins only):
/// rename, description, type, default activity color and group deletion
/// (owner only, §4). Changes are persisted via GroupService.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:pokatuha/core/errors/app_error.dart';
import 'package:pokatuha/core/tokens/design_tokens.dart';
import 'package:pokatuha/database/collections/group_collection.dart';
import 'package:pokatuha/domain/enums/enums.dart';
import 'package:pokatuha/domain/services/group_service.dart';
import 'package:pokatuha/domain/services/service_locator.dart';
import 'package:pokatuha/l10n/app_localizations.dart';
import 'package:pokatuha/presentation/app_view_model.dart';

class GroupSettingsTab extends StatefulWidget {
  const GroupSettingsTab({
    super.key,
    required this.group,
    this.onChanged,
  });

  final GroupCollection group;
  final VoidCallback? onChanged;

  @override
  State<GroupSettingsTab> createState() => _GroupSettingsTabState();
}

class _GroupSettingsTabState extends State<GroupSettingsTab> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late GroupType _type;
  late int? _accentColor;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.group.name);
    _description = TextEditingController(text: widget.group.description ?? '');
    _type = GroupType.values.firstWhere(
      (t) => t.name == widget.group.type,
      orElse: () => GroupType.private,
    );
    _accentColor = widget.group.defaultAccentColor;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final group = widget.group
        ..name = _name.text.trim()
        ..description =
            _description.text.trim().isEmpty ? null : _description.text.trim()
        ..type = _type.name
        ..discoverable = _type == GroupType.public
        ..defaultAccentColor = _accentColor;
      await serviceLocator<GroupService>().updateGroup(group);
      widget.onChanged?.call();
      if (mounted) {
        final l = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.save)));
      }
    } on AppError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final user = context.read<AppViewModel>().user;
    final isOwner = user != null && widget.group.ownerId == user.id;
    return ListView(
      padding: const EdgeInsets.all(DesignTokens.space4),
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _name,
                decoration: InputDecoration(labelText: l.groupName),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? l.groupName : null,
              ),
              const SizedBox(height: DesignTokens.space4),
              TextFormField(
                controller: _description,
                decoration: InputDecoration(labelText: l.groupDescription),
                maxLines: 3,
              ),
              const SizedBox(height: DesignTokens.space4),
              Text(l.groupType, style: Theme.of(context).textTheme.bodyMedium),
              ...GroupType.values.map(
                (t) => RadioListTile<GroupType>(
                  value: t,
                  groupValue: _type,
                  onChanged: (v) => setState(() => _type = v ?? _type),
                  title: Text(_typeLabel(l, t)),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              const SizedBox(height: DesignTokens.space4),
              Text(l.defaultColor,
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: DesignTokens.space2),
              _colorPicker(context),
            ],
          ),
        ),
        const SizedBox(height: DesignTokens.space6),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l.save),
        ),
        if (isOwner) ...[
          const SizedBox(height: DesignTokens.space4),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => _deleteGroup(context),
            icon: const Icon(Icons.delete_outline_rounded),
            label: Text(l.deleteGroup),
          ),
        ],
      ],
    );
  }

  String _typeLabel(AppLocalizations l, GroupType type) => switch (type) {
        GroupType.public => l.groupTypePublic,
        GroupType.private => l.groupTypePrivate,
        GroupType.inviteOnly => l.groupTypeInviteOnly,
      };

  Widget _colorPicker(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: ActivityColors.swatches.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          if (i == 0) {
            final selected = _accentColor == null;
            return GestureDetector(
              onTap: () => setState(() => _accentColor = null),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                    width: selected ? 3 : 1,
                  ),
                ),
                child: Icon(
                  Icons.format_color_reset_outlined,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            );
          }
          final c = ActivityColors.swatches[i - 1];
          final selected = _accentColor == c.value;
          return GestureDetector(
            onTap: () => setState(() => _accentColor = c.value),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: selected
                    ? Border.all(
                        color: Theme.of(context).colorScheme.onSurface,
                        width: 3,
                      )
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _deleteGroup(BuildContext context) async {
    final l = AppLocalizations.of(context)!;
    final user = context.read<AppViewModel>().user;
    if (user == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.deleteGroup),
        content: Text(l.deleteGroupConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await serviceLocator<GroupService>()
          .deleteGroup(group: widget.group, byUserId: user.id);
      if (context.mounted) Navigator.of(context).pop();
    } on AppError catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}
