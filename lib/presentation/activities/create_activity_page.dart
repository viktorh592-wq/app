/// Create / edit activity form (UC-001 — Create Ride). Opens only from a
/// group context — V2 Group-first model (GROUPS_AND_ACTIVITIES.md §1: users
/// never create standalone activities from the main screen). Implements
/// FR-001 fields plus the V2 §10 activity color picker (accent propagates to
/// cards, chat, polls, route and map — S2-T6). When [event] is provided the
/// form edits that activity instead of creating a new one (V2 §9 — Edit).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:pokatuha/core/errors/app_error.dart';
import 'package:pokatuha/core/tokens/design_tokens.dart';
import 'package:pokatuha/database/collections/activity_type_collection.dart';
import 'package:pokatuha/database/collections/event_collection.dart';
import 'package:pokatuha/database/collections/group_collection.dart';
import 'package:pokatuha/domain/enums/enums.dart';
import 'package:pokatuha/domain/repositories/activity_type_repository.dart';
import 'package:pokatuha/domain/repositories/group_repository.dart';
import 'package:pokatuha/domain/services/event_service.dart';
import 'package:pokatuha/domain/services/gps_service.dart';
import 'package:pokatuha/domain/services/service_locator.dart';
import 'package:pokatuha/l10n/app_localizations.dart';
import 'package:pokatuha/presentation/app_view_model.dart';

class CreateActivityPage extends StatefulWidget {
  const CreateActivityPage({super.key, required this.groupId, this.event});

  /// Group the activity belongs to (required — V2 Group-first).
  final String groupId;

  /// Activity to edit (V2 §9 — activity menu → Edit); null = create.
  final EventCollection? event;

  @override
  State<CreateActivityPage> createState() => _CreateActivityPageState();
}

class _CreateActivityPageState extends State<CreateActivityPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _meetingLabel = TextEditingController();
  final _maxParticipants = TextEditingController();

  DateTime _dateTime = DateTime.now().add(const Duration(hours: 1));
  String? _activityTypeId;
  EventVisibility _visibility = EventVisibility.private;
  double _meetingLat = 0;
  double _meetingLng = 0;
  bool _hasMeeting = false;
  bool _saving = false;

  /// Selected accent color ARGB (V2 §10, S2-T6). Defaults to violet;
  /// overridden by the group default color when the form opens.
  int _accentColor = EventCollection.defaultAccentColorArgb;

  bool get _isEditing => widget.event != null;

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    if (e != null) {
      _title.text = e.title;
      _description.text = e.description;
      _meetingLabel.text = e.meetingPointLabel ?? '';
      _meetingLat = e.meetingPoint?.lat ?? 0;
      _meetingLng = e.meetingPoint?.lng ?? 0;
      _hasMeeting = e.meetingPoint != null;
      _dateTime = DateTime.fromMillisecondsSinceEpoch(e.startAt).toLocal();
      _activityTypeId = e.activityTypeId.isEmpty ? null : e.activityTypeId;
      _visibility = EventVisibility.values.firstWhere(
        (v) => v.name == e.visibility,
        orElse: () => EventVisibility.private,
      );
      _maxParticipants.text = e.maxParticipants?.toString() ?? '';
      _accentColor = e.accentColor ?? EventCollection.defaultAccentColorArgb;
    } else {
      _loadGroupDefaultColor();
    }
  }

  /// New activities inherit the group default accent color when set
  /// (GROUPS_AND_ACTIVITIES.md §3 — defaultAccentColor).
  Future<void> _loadGroupDefaultColor() async {
    final group =
        await serviceLocator<GroupRepository>().getById(widget.groupId);
    final argb = group?.defaultAccentColor;
    if (argb != null && mounted) {
      setState(() => _accentColor = argb);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _meetingLabel.dispose();
    _maxParticipants.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _dateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) {
      setState(() => _dateTime =
          DateTime(d.year, d.month, d.day, _dateTime.hour, _dateTime.minute));
    }
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime),
    );
    if (t != null) {
      setState(() => _dateTime = DateTime(
          _dateTime.year, _dateTime.month, _dateTime.day, t.hour, t.minute));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_activityTypeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.activityType)));
      return;
    }
    setState(() => _saving = true);
    try {
      final user = context.read<AppViewModel>().user!;
      final service = serviceLocator<EventService>();
      if (_isEditing) {
        await service.editActivity(
          event: widget.event!,
          title: _title.text,
          description: _description.text,
          startAt: _dateTime.toUtc().millisecondsSinceEpoch,
          activityTypeId: _activityTypeId!,
          meetingLat: _hasMeeting ? _meetingLat : null,
          meetingLng: _hasMeeting ? _meetingLng : null,
          meetingPointLabel: _meetingLabel.text.trim().isEmpty
              ? null
              : _meetingLabel.text.trim(),
          visibility: _visibility,
          maxParticipants: _maxParticipants.text.trim().isEmpty
              ? null
              : int.tryParse(_maxParticipants.text.trim()),
          accentColor: _accentColor,
        );
      } else {
        await service.createActivity(
          organizer: user,
          groupId: widget.groupId,
          title: _title.text,
          description: _description.text,
          startAt: _dateTime.toUtc().millisecondsSinceEpoch,
          activityTypeId: _activityTypeId!,
          meetingLat: _hasMeeting ? _meetingLat : null,
          meetingLng: _hasMeeting ? _meetingLng : null,
          meetingPointLabel: _meetingLabel.text.trim().isEmpty
              ? null
              : _meetingLabel.text.trim(),
          visibility: _visibility,
          maxParticipants: _maxParticipants.text.trim().isEmpty
              ? null
              : int.tryParse(_maxParticipants.text.trim()),
          accentColor: _accentColor,
        );
      }
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
      appBar:
          AppBar(title: Text(_isEditing ? l.editActivity : l.createActivity)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FutureBuilder<GroupCollection?>(
              future: serviceLocator<GroupRepository>().getById(widget.groupId),
              builder: (context, snapshot) {
                final group = snapshot.data;
                if (group == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      Icon(Icons.group_outlined,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          group.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            TextFormField(
              controller: _title,
              decoration: InputDecoration(labelText: l.title),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l.title : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _description,
              decoration: InputDecoration(labelText: l.description),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<ActivityTypeCollection>>(
              future: serviceLocator<ActivityTypeRepository>().all(),
              builder: (context, snapshot) {
                final types = snapshot.data ?? [];
                return DropdownButtonFormField<String>(
                  decoration: InputDecoration(labelText: l.activityType),
                  value: _activityTypeId,
                  items: types
                      .map((t) => DropdownMenuItem(
                            value: t.id,
                            child: Text(t.label),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _activityTypeId = v),
                );
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(
                        '${_dateTime.day}/${_dateTime.month}/${_dateTime.year}'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.access_time_rounded),
                    label: Text(
                        '${_dateTime.hour.toString().padLeft(2, '0')}:${_dateTime.minute.toString().padLeft(2, '0')}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _meetingLabel,
              decoration: InputDecoration(
                labelText: l.meetingPoint,
                helperText: l.tapMapForCoords,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.map_outlined),
                  onPressed: _setMeetingFromDefault,
                ),
              ),
            ),
            if (_hasMeeting)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${_meetingLat.toStringAsFixed(5)}, ${_meetingLng.toStringAsFixed(5)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _maxParticipants,
                    decoration: InputDecoration(labelText: l.maxParticipants),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<EventVisibility>(
                    decoration: InputDecoration(labelText: l.visibility),
                    value: _visibility,
                    items: EventVisibility.values
                        .map((v) => DropdownMenuItem(
                              value: v,
                              child: Text(_visibilityLabel(l, v)),
                            ))
                        .toList(),
                    onChanged: (v) => setState(
                        () => _visibility = v ?? EventVisibility.private),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _colorPicker(l),
            const SizedBox(height: 16),
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

  /// V3.0.2 — localized [EventVisibility] label. The previous version used
  /// `v.name` which exposed raw enum names ("private" / "linkOnly" / "public")
  /// in the UI for both locales.
  String _visibilityLabel(AppLocalizations l, EventVisibility v) {
    return switch (v) {
      EventVisibility.private => l.visibilityPrivate,
      EventVisibility.linkOnly => l.visibilityLinkOnly,
      EventVisibility.public => l.visibilityPublic,
    };
  }

  /// V2 §10 — activity color picker: horizontal row of swatches from
  /// ActivityColors; the selected one gets a black outline. Default violet;
  /// pre-set from group.defaultAccentColor for new activities.
  Widget _colorPicker(AppLocalizations l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.activityColor, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: ActivityColors.swatches.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final c = ActivityColors.swatches[i];
              final selected = c.value == _accentColor;
              return GestureDetector(
                onTap: () => setState(() => _accentColor = c.value),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: selected
                        ? Border.all(color: Colors.black, width: 3)
                        : Border.all(color: Colors.transparent, width: 3),
                  ),
                  child: selected
                      ? const Icon(Icons.check_rounded,
                          color: Colors.black, size: 20)
                      : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// For Local-First UX the meeting point defaults to the user's current GPS
  /// if available (FR-005). Falls back to a neutral coordinate.
  Future<void> _setMeetingFromDefault() async {
    try {
      final sample = await serviceLocator<GpsService>().current();
      setState(() {
        _meetingLat = sample.lat;
        _meetingLng = sample.lng;
        _hasMeeting = true;
      });
    } catch (_) {
      setState(() {
        _meetingLat = 50.4501;
        _meetingLng = 30.5234;
        _hasMeeting = true;
      });
    }
  }
}
