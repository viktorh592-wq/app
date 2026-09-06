/// V3.0.3 fix (user feedback): group member picker — used by the activity
/// ParticipantsBlock «Invite» button. Lets the inviter select one or
/// several members of the activity's group instead of searching the
/// entire local user database (USER_DISCOVERY.md §2). Members already
/// invited to the activity (existing participant record) are disabled
/// with a chip indicating their current status.
import 'package:flutter/material.dart';

import 'package:pokatuha/core/tokens/design_tokens.dart';
import 'package:pokatuha/database/collections/group_member_collection.dart';
import 'package:pokatuha/database/collections/participant_collection.dart';
import 'package:pokatuha/database/collections/user_collection.dart';
import 'package:pokatuha/domain/enums/enums.dart';
import 'package:pokatuha/domain/repositories/group_member_repository.dart';
import 'package:pokatuha/domain/repositories/participant_repository.dart';
import 'package:pokatuha/domain/repositories/user_repository.dart';
import 'package:pokatuha/domain/services/service_locator.dart';
import 'package:pokatuha/l10n/app_localizations.dart';

class GroupMemberPickerPage extends StatefulWidget {
  const GroupMemberPickerPage({
    super.key,
    required this.groupId,
    required this.eventId,
    required this.onMembersSelected,
    this.multiSelect = true,
  });

  final String groupId;
  final String eventId;

  /// Called with the list of selected users when the user taps the
  /// «Done» action (single-select mode also calls this with one item).
  final void Function(List<UserCollection> users) onMembersSelected;

  final bool multiSelect;

  @override
  State<GroupMemberPickerPage> createState() => _GroupMemberPickerPageState();
}

class _GroupMemberPickerPageState extends State<GroupMemberPickerPage> {
  late Future<_PickerData> _future;
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = () async {
      final members = await serviceLocator<GroupMemberRepository>()
          .byGroup(widget.groupId);
      final participants = await serviceLocator<ParticipantRepository>()
          .byEvent(widget.eventId);
      final participantsByUserId = <String, ParticipantCollection>{};
      for (final p in participants) {
        participantsByUserId[p.userId] = p;
      }
      final users = serviceLocator<UserRepository>();
      final me = await users.getCurrent();
      final meId = me?.id;
      final items = <_PickerItem>[];
      for (final m in members) {
        final user = await users.getById(m.userId);
        final p = participantsByUserId[m.userId];
        items.add(_PickerItem(
          member: m,
          user: user,
          participant: p,
          isMe: meId == m.userId,
        ));
      }
      // Sort: known users first (with displayName), then by id.
      items.sort((a, b) {
        final an = a.user?.displayName ?? a.member.userId.substring(0, 6);
        final bn = b.user?.displayName ?? b.member.userId.substring(0, 6);
        return an.toLowerCase().compareTo(bn.toLowerCase());
      });
      return _PickerData(items: items);
    }();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.invite),
        actions: [
          if (_selected.isNotEmpty)
            TextButton.icon(
              onPressed: _confirm,
              icon: const Icon(Icons.check_rounded),
              label: Text(l.done),
            ),
        ],
      ),
      body: FutureBuilder<_PickerData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          if (data.items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(DesignTokens.space6),
                child: Text(
                  l.noMembers,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            );
          }
          return ListView.builder(
            itemCount: data.items.length,
            itemBuilder: (context, i) {
              final item = data.items[i];
              final name = item.user?.displayName ??
                  item.member.userId.substring(0, 6);
              final nickname = item.user?.username.isNotEmpty == true
                  ? '@${item.user!.username}'
                  : null;
              final p = item.participant;
              final alreadyIn = p != null &&
                  (p.status == ParticipantStatus.invited.name ||
                      p.status == ParticipantStatus.accepted.name);
              final isSelected = _selected.contains(item.member.userId);
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: Text(
                    name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
                  ),
                ),
                title: Text(name + (item.isMe ? ' (Вы)' : '')),
                subtitle: nickname == null ? null : Text(nickname),
                trailing: alreadyIn
                    ? _statusChip(context, p!)
                    : (widget.multiSelect
                        ? Checkbox(
                            value: isSelected,
                            onChanged: (v) => _toggle(item, v ?? false),
                          )
                        : Radio<String>(
                            value: item.member.userId,
                            groupValue:
                                _selected.isEmpty ? null : _selected.first,
                            onChanged: (v) => _toggleSingle(item, v),
                          )),
                enabled: !alreadyIn,
                onTap: alreadyIn ? null : () => _toggle(item, !isSelected),
              );
            },
          );
        },
      ),
    );
  }

  void _toggle(_PickerItem item, bool selected) {
    setState(() {
      if (selected) {
        if (!widget.multiSelect) _selected.clear();
        _selected.add(item.member.userId);
      } else {
        _selected.remove(item.member.userId);
      }
    });
  }

  void _toggleSingle(_PickerItem item, String? userId) {
    if (userId == null) return;
    setState(() {
      _selected.clear();
      _selected.add(userId);
    });
  }

  void _confirm() {
    _future.then((pickerData) {
      final selected = <UserCollection>[];
      for (final item in pickerData.items) {
        if (_selected.contains(item.member.userId) && item.user != null) {
          selected.add(item.user!);
        }
      }
      Navigator.of(context).pop();
      widget.onMembersSelected(selected);
    });
  }

  Widget _statusChip(BuildContext context, ParticipantCollection p) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final status = ParticipantStatus.values.firstWhere(
      (s) => s.name == p.status,
      orElse: () => ParticipantStatus.invited,
    );
    final label = switch (status) {
      ParticipantStatus.accepted => l.join,
      ParticipantStatus.invited => l.alreadyInvited,
      _ => l.alreadyInvited,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.outline.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
      ),
      child: Text(label, style: DesignTokens.pin(color: scheme.outline)),
    );
  }
}

class _PickerData {
  _PickerData({required this.items});
  final List<_PickerItem> items;
}

class _PickerItem {
  _PickerItem({
    required this.member,
    this.user,
    this.participant,
    this.isMe = false,
  });
  final GroupMemberCollection member;
  final UserCollection? user;
  final ParticipantCollection? participant;
  final bool isMe;
}

/// Convenience: open the picker as a pushed route. Returns the selected
/// users via [onMembersSelected] callback (the picker pops itself before
/// the callback fires).
Future<void> openGroupMemberPicker(
  BuildContext context, {
  required String groupId,
  required String eventId,
  required void Function(List<UserCollection> users) onMembersSelected,
  bool multiSelect = true,
}) async {
  await Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => GroupMemberPickerPage(
      groupId: groupId,
      eventId: eventId,
      onMembersSelected: onMembersSelected,
      multiSelect: multiSelect,
    ),
  ));
}
