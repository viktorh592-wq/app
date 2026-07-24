/// Notifications page — grouped by activity (Notifications.md). Mark read.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:pokatuha/core/utils/timestamps.dart';
import 'package:pokatuha/database/collections/notification_collection.dart';
import 'package:pokatuha/domain/repositories/notification_repository.dart';
import 'package:pokatuha/domain/services/service_locator.dart';
import 'package:pokatuha/l10n/app_localizations.dart';
import 'package:pokatuha/presentation/app_view_model.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late Future<List<NotificationCollection>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final userId = context.read<AppViewModel>().user!.id;
    _future = serviceLocator<NotificationRepository>().forUser(userId);
  }

  Future<void> _markAllRead() async {
    final userId = context.read<AppViewModel>().user!.id;
    await serviceLocator<NotificationRepository>().markAllRead(userId);
    setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.notifications),
        actions: [
          TextButton(
            onPressed: _markAllRead,
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: FutureBuilder<List<NotificationCollection>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snapshot.data!;
          if (list.isEmpty) {
            return const Center(child: Text('No notifications'));
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final n = list[i];
              return ListTile(
                leading: Icon(
                  _icon(n.category),
                  color: n.read
                      ? Theme.of(context).colorScheme.outline
                      : Theme.of(context).colorScheme.primary,
                ),
                title: Text(
                  n.title,
                  style: TextStyle(
                    fontWeight: n.read ? FontWeight.normal : FontWeight.w600,
                  ),
                ),
                subtitle: Text(n.body),
                trailing: Text(
                  Timestamps.relativeFromNow(n.createdAt, 'en'),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                onTap: () async {
                  await serviceLocator<NotificationRepository>().markRead(n);
                  setState(_load);
                },
              );
            },
          );
        },
      ),
    );
  }

  IconData _icon(String category) {
    return switch (category) {
      'newMessage' ||
      'pinnedMessage' ||
      'mention' ||
      'reply' =>
        Icons.chat_bubble_outline_rounded,
      'participantApproaching' ||
      'participantArrived' ||
      'organizerArrived' =>
        Icons.location_on_outlined,
      'newPoll' ||
      'pollClosed' ||
      'pollResultsPublished' =>
        Icons.poll_outlined,
      'rideStarted' || 'rideFinished' => Icons.directions_bike_rounded,
      'enableGpsReminder' => Icons.location_searching_outlined,
      'weatherChanged' => Icons.cloud_outlined,
      _ => Icons.notifications_outlined,
    };
  }
}
