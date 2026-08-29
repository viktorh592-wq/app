/// Create group form (V2 GROUPS_AND_ACTIVITIES.md §3): name, description,
/// type and an optional default activity color. The creator automatically
/// becomes the owner (§4, via GroupService).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:pokatuha/core/errors/app_error.dart';
import 'package:pokatuha/core/tokens/design_tokens.dart';
import 'package:pokatuha/domain/enums/enums.dart';
import 'package:pokatuha/domain/services/group_service.dart';
import 'package:pokatuha/domain/services/service_locator.dart';
import 'package:pokatuha/l10n/app_localizations.dart';
import 'package:pokatuha/presentation/app_view_model.dart';

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key});

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();

  GroupType _type = GroupType.private;
  int? _accentColor;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final user = context.read<AppViewModel>().user!;
      await serviceLocator<GroupService>().createGroup(
        owner: user,
        name: _name.text,
        description:
            _description.text.trim().isEmpty ? null : _description.text.trim(),
        type: _type,
        defaultAccentColor: _accentColor,
      );
      if (mounted) Navigator.of(context).pop(true);
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
    return Scaffold(
      appBar: AppBar(title: Text(l.createGroup)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(DesignTokens.space4),
          children: [
            TextFormField(
              controller: _name,
              decoration: InputDecoration(labelText: l.groupName),
              textCapitalization: TextCapitalization.words,
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
            const SizedBox(height: DesignTokens.space2),
            ...GroupType.values.map((t) => _typeTile(t)),
            const SizedBox(height: DesignTokens.space4),
            Text(l.defaultColor, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: DesignTokens.space2),
            _colorPicker(),
            const SizedBox(height: DesignTokens.space6),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(l.save),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeTile(GroupType type) {
    final l = AppLocalizations.of(context)!;
    final (label, hint, icon) = switch (type) {
      GroupType.public => (
          l.groupTypePublic,
          l.groupTypePublicHint,
          Icons.public_rounded
        ),
      GroupType.private => (
          l.groupTypePrivate,
          l.groupTypePrivateHint,
          Icons.lock_outline_rounded
        ),
      GroupType.inviteOnly => (
          l.groupTypeInviteOnly,
          l.groupTypeInviteOnlyHint,
          Icons.mail_rounded
        ),
    };
    return RadioListTile<GroupType>(
      value: type,
      groupValue: _type,
      onChanged: (v) => setState(() => _type = v ?? _type),
      title: Text(label),
      subtitle: Text(hint),
      secondary: Icon(icon),
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  Widget _colorPicker() {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: ActivityColors.swatches.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          // First item — «no default color» (inherit app primary).
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
}
