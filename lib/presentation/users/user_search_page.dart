/// User search page (V2 USER_DISCOVERY.md §2 — discovery by nickname).
/// Local-First: searches only users already known on this device. Used both
/// standalone and from the group invite flow (onUserSelected).
import 'dart:async';

import 'package:flutter/material.dart';

import 'package:pokatuha/core/tokens/design_tokens.dart';
import 'package:pokatuha/database/collections/user_collection.dart';
import 'package:pokatuha/domain/repositories/user_repository.dart';
import 'package:pokatuha/domain/services/service_locator.dart';
import 'package:pokatuha/l10n/app_localizations.dart';
import 'package:pokatuha/presentation/users/user_profile_page.dart';
import 'package:pokatuha/presentation/widgets/empty_state.dart';

class UserSearchPage extends StatefulWidget {
  const UserSearchPage({super.key, this.title, this.onUserSelected});

  /// Optional page title (e.g. «Пригласить» in the invite flows).
  final String? title;

  /// When provided, tapping a result pops the page and calls back with the
  /// selected user (group / activity invite flows, FIX_PLAN S1-T10).
  /// Otherwise the tapped user's profile page is opened (§4).
  final void Function(UserCollection user)? onUserSelected;

  @override
  State<UserSearchPage> createState() => _UserSearchPageState();
}

class _UserSearchPageState extends State<UserSearchPage> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  List<UserCollection>? _results;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _search(value);
    });
  }

  Future<void> _search(String query) async {
    setState(() => _query = query.trim());
    if (_query.isEmpty) {
      setState(() => _results = null);
      return;
    }
    final results =
        await serviceLocator<UserRepository>().searchByNickname(_query);
    if (mounted) setState(() => _results = results);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title ?? l.searchByNickname)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(DesignTokens.space4),
            child: TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: l.search,
                prefixIcon: const Icon(Icons.search_rounded),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: _onChanged,
            ),
          ),
          Expanded(
            child: _results == null
                ? EmptyState(
                    icon: Icons.person_search_rounded,
                    title: l.search,
                    subtitle: l.noUsersFoundHint,
                  )
                : _results!.isEmpty
                    ? EmptyState(
                        icon: Icons.person_off_outlined,
                        title: l.noUsersFound,
                        subtitle: l.noUsersFoundHint,
                      )
                    : ListView.builder(
                        itemCount: _results!.length,
                        itemBuilder: (context, i) {
                          final user = _results![i];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              child: Text(
                                user.displayName.isEmpty
                                    ? '?'
                                    : user.displayName
                                        .substring(0, 1)
                                        .toUpperCase(),
                              ),
                            ),
                            title: Text(user.displayName),
                            subtitle: user.username.isEmpty
                                ? null
                                : Text('@${user.username}'),
                            onTap: () {
                              final selected = widget.onUserSelected;
                              if (selected != null) {
                                Navigator.of(context).pop();
                                selected(user);
                              } else {
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => UserProfilePage(user: user),
                                ));
                              }
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
