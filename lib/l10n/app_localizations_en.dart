// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint


/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Pokatuha';

  @override
  String get tabHome => 'Home';

  @override
  String get tabActivities => 'Activities';

  @override
  String get tabMap => 'Map';

  @override
  String get tabArchive => 'Archive';

  @override
  String get tabProfile => 'Profile';

  @override
  String get createActivity => 'Create activity';

  @override
  String get editActivity => 'Edit activity';

  @override
  String get title => 'Title';

  @override
  String get description => 'Description';

  @override
  String get date => 'Date';

  @override
  String get time => 'Time';

  @override
  String get meetingPoint => 'Meeting point';

  @override
  String get activityType => 'Activity type';

  @override
  String get visibility => 'Visibility';

  @override
  String get maxParticipants => 'Max participants';

  @override
  String get coverImage => 'Cover image';

  @override
  String get weatherPreview => 'Weather preview';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get archive => 'Archive';

  @override
  String get chat => 'Chat';

  @override
  String get polls => 'Polls';

  @override
  String get route => 'Route';

  @override
  String get participants => 'Participants';

  @override
  String get join => 'Join';

  @override
  String get decline => 'Decline';

  @override
  String get leave => 'Leave';

  @override
  String get startRide => 'Start ride';

  @override
  String get finishRide => 'Finish ride';

  @override
  String get settings => 'Settings';

  @override
  String get themes => 'Themes';

  @override
  String get notifications => 'Notifications';

  @override
  String get newMessage => 'New message';

  @override
  String get participantArrived => 'Participant arrived';

  @override
  String get silentMode => 'Silent mode';

  @override
  String get profile => 'Profile';

  @override
  String get organizer => 'Organizer';

  @override
  String get noActivities => 'No activities yet';

  @override
  String get noActivitiesHint => 'Create your first activity to get started';

  @override
  String get noArchive => 'No archived activities';

  @override
  String get upcoming => 'Upcoming';

  @override
  String get live => 'Live';

  @override
  String get finished => 'Finished';

  @override
  String arrivalNear(String name) => '${name} is 500 m away';

  @override
  String arrivalClose(String name) => '${name} is arriving';

  @override
  String arrivalArrived(String name) => '${name} has arrived';

  @override
  String get offlineMode => 'Offline mode';

  @override
  String get syncing => 'Synchronizing…';

  @override
  String get allSynced => 'All changes synced';

  @override
  String get gpsSharingOff => 'GPS sharing is off until you start the ride';

  @override
  String get addPoll => 'Add poll';

  @override
  String get singleChoice => 'Single choice';

  @override
  String get multipleChoice => 'Multiple choice';

  @override
  String get vote => 'Vote';

  @override
  String get addRoute => 'Add route';

  @override
  String get importGpx => 'Import GPX';

  @override
  String get exportGpx => 'Export GPX';

  @override
  String get selectMapProvider => 'Map provider';

  @override
  String get openStreetMap => 'OpenStreetMap';

  @override
  String get mapLibre => 'MapLibre';

  @override
  String get googleMaps => 'Google Maps';

  @override
  String get hereMaps => 'HERE';

  @override
  String get twoGis => '2GIS';

  @override
  String get yandexMaps => 'Yandex Maps';

  @override
  String get cyclOSM => 'CyclOSM';

  @override
  String get openTopoMap => 'OpenTopoMap';

  @override
  String get esriSatellite => 'Esri Satellite';

  @override
  String get cartoVoyager => 'Carto Voyager';

  @override
  String mapLayerByContext(String context) => 'Suggested for: ${context}';

  @override
  String get mapContextCycling => 'cycling';

  @override
  String get mapContextMountains => 'mountains';

  @override
  String get mapContextForest => 'forest';

  @override
  String get mapContextCity => 'city';

  @override
  String get language => 'Language';

  @override
  String get appearance => 'Appearance';

  @override
  String get lightTheme => 'Light';

  @override
  String get darkTheme => 'Dark';

  @override
  String get amoledTheme => 'AMOLED';

  @override
  String get accentColor => 'Accent color';

  @override
  String get english => 'English';

  @override
  String get russian => 'Русский';

  @override
  String get confirmExit => 'Discard unsaved changes?';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get distance => 'Distance';

  @override
  String get duration => 'Duration';

  @override
  String get elevation => 'Elevation';

  @override
  String get avgSpeed => 'Average speed';

  @override
  String get welcome => 'Welcome to Pokatuha';

  @override
  String get welcomeHint => 'Create your local profile to begin';

  @override
  String get yourName => 'Your name';

  @override
  String get continueButton => 'Continue';

  @override
  String get search => 'Search';

  @override
  String get tabGroups => 'Groups';

  @override
  String get createGroup => 'Create group';

  @override
  String get noGroups => 'No groups';

  @override
  String get noGroupsHint => 'Create your first group';

  @override
  String get groupName => 'Group name';

  @override
  String get groupDescription => 'Description';

  @override
  String get groupType => 'Group type';

  @override
  String get groupTypePublic => 'Public';

  @override
  String get groupTypePublicHint => 'Discoverable, join without approval';

  @override
  String get groupTypePrivate => 'Private';

  @override
  String get groupTypePrivateHint => 'Not discoverable, invitation only';

  @override
  String get groupTypeInviteOnly => 'Invite-only';

  @override
  String get groupTypeInviteOnlyHint => 'Requires admin approval';

  @override
  String get groupMembers => 'Members';

  @override
  String get groupMedia => 'Media';

  @override
  String get groupSettings => 'Settings';

  @override
  String get inviteToGroup => 'Invite to group';

  @override
  String get showGroupQr => 'Show group QR';

  @override
  String get shareInviteLink => 'Share invite link';

  @override
  String get searchByNickname => 'Search by nickname';

  @override
  String get leaveGroup => 'Leave group';

  @override
  String get deleteGroup => 'Delete group';

  @override
  String get deleteGroupConfirm => 'Delete the group with its activities?';

  @override
  String get defaultColor => 'Default activity color';

  @override
  String get roleOwner => 'Owner';

  @override
  String get roleAdmin => 'Admin';

  @override
  String get roleMember => 'Member';

  @override
  String get noMembers => 'No members yet';

  @override
  String get noMedia => 'No media yet';

  @override
  String get noMediaHint => 'Photos and videos from group chats will appear here';

  @override
  String get invite => 'Invite';

  @override
  String memberAdded(String name) => '${name} added to the group';

  @override
  String membersCount(int count) => if (count == 0) 'No members' else if (count == 1) '$count member' else '$count members';

  @override
  String get showMyQr => 'Show my QR';

  @override
  String get scanQr => 'Scan QR';

  @override
  String get addToContacts => 'Add to contacts';

  @override
  String get addedToContacts => 'Added to contacts';

  @override
  String get writeMessage => 'Write';

  @override
  String get comingSoon => 'Coming in a later sprint';

  @override
  String get userNotFound => 'User not found on this device';

  @override
  String get noUsersFound => 'No users found';

  @override
  String get noUsersFoundHint => 'Users appear after QR scan or contact exchange';

  @override
  String get invalidQr => 'Unrecognized QR code';

  @override
  String get yourQrCode => 'Your QR code';

  @override
  String get groupQrCode => 'Group QR code';

  @override
  String get copy => 'Copy';

  @override
  String get copied => 'Copied';

  @override
  String get share => 'Share';

  @override
  String get done => 'Done';

  @override
  String get mapActions => 'Map actions';

  @override
  String get findMe => 'Find me';

  @override
  String get shareLocation => 'Share location';

  @override
  String get stopSharingLocation => 'Stop sharing location';

  @override
  String get showRoute => 'Show route';

  @override
  String get downloadGpx => 'Download GPX';

  @override
  String get selectMap => 'Select map';

  @override
  String get showParticipants => 'Show participants';

  @override
  String get noActiveActivity => 'No active activity';

  @override
  String get locationSharingOn => 'Location sharing on';

  @override
  String get locationSharingOff => 'Location sharing off';

  @override
  String get noRoutes => 'No routes yet';

  @override
  String get noRoutesHint => 'Add a route to a group activity';

  @override
  String get gpxExported => 'GPX is ready to share';

  @override
  String get noParticipantsOnMap => 'No participants with live position';

  @override
  String get tabMain => 'Main';

  @override
  String get activityColor => 'Activity color';

  @override
  String get openMap => 'Open map';

  @override
  String get shareActivity => 'Share activity';

  @override
  String get noRouteYet => 'No route yet';

  @override
  String get kmUnit => 'km';

  @override
  String get mUnit => 'm';

  @override
  String get noParticipants => 'No participants yet';

  @override
  String liveSharingCount(int count) => '${count} live';

  @override
  String get noMessagesYet => 'No messages yet';

  @override
  String get details => 'Details';

  @override
  String get menuEdit => 'Edit';

  @override
  String get menuDuplicate => 'Duplicate';

  @override
  String get menuShare => 'Share';

  @override
  String get menuPin => 'Pin in group';

  @override
  String get menuUnpin => 'Unpin from group';

  @override
  String get menuArchive => 'Archive';

  @override
  String get menuShowOnMap => 'Show on map';

  @override
  String get deleteActivityConfirm => 'Delete this activity? The archive record is kept.';

  @override
  String get duplicated => 'Activity duplicated';

  @override
  String get pinned => 'Pinned in group';

  @override
  String get unpinned => 'Unpinned';

  @override
  String get archived => 'Activity moved to archive';

  @override
  String get chatReaction => 'Reaction';

  @override
  String get chatReply => 'Reply';

  @override
  String get chatForward => 'Forward';

  @override
  String get chatPinMessage => 'Pin';

  @override
  String get chatUnpinMessage => 'Unpin';

  @override
  String get chatCopy => 'Copy';

  @override
  String get chatDeleteMessage => 'Delete';

  @override
  String chatForwardedFrom(String name) => 'Forwarded from ${name}';

  @override
  String chatReplyTo(String name) => 'Reply to ${name}';

  @override
  String chatPinnedBar(int count) => '${count} pinned';

  @override
  String get chatAttachCamera => 'Camera';

  @override
  String get chatAttachGallery => 'Gallery';

  @override
  String get chatAttachRoute => 'Route';

  @override
  String get chatAttachFile => 'File';

  @override
  String get chatAttachLocation => 'Location';

  @override
  String get chatAttachPoll => 'Poll';

  @override
  String get chatAttachVoice => 'Voice';

  @override
  String get chatMenuSearch => 'Search';

  @override
  String get chatMenuMedia => 'Media';

  @override
  String get chatMenuPinned => 'Pinned';

  @override
  String get chatMenuSharedRoutes => 'Shared routes';

  @override
  String get chatMenuFiles => 'Shared files';

  @override
  String get chatMenuMute => 'Mute';

  @override
  String get chatMenuUnmute => 'Unmute';

  @override
  String get chatMenuExport => 'Export';

  @override
  String get chatReadOnlyBanner => 'This activity is archived. The chat is read-only.';

  @override
  String get chatVoiceHoldToRecord => 'Hold to record';

  @override
  String get chatVoiceSlideToCancel => 'Slide down to cancel';

  @override
  String get chatVoiceRecording => 'Recording…';

  @override
  String get chatSearchPlaceholder => 'Search messages';

  @override
  String get chatSearchNoResults => 'No messages found';

  @override
  String get chatExportReady => 'Chat exported';

  @override
  String get chatMuted => 'Chat muted';

  @override
  String get chatUnmuted => 'Chat unmuted';

  @override
  String get chatForwardTarget => 'Forward to…';

  @override
  String get chatForwarded => 'Message forwarded';

  @override
  String chatPhotoSizeWarning(int kb) => 'Photo size: ${kb} KB';

  @override
  String get chatNoMedia => 'No media in this chat yet';

  @override
  String get chatNoPinned => 'No pinned messages';

  @override
  String get chatNoFiles => 'No files in this chat yet';

  @override
  String get chatNoRoutes => 'No routes shared in this chat yet';

  @override
  String get chatOpenInMap => 'Open in map';

  @override
  String chatPlaybackSpeed(String speed) => '${speed}x speed';

  @override
  String get chatDocumentOpen => 'Open';

  @override
  String get mapParticipantStatus => 'Status';

  @override
  String get mapParticipantSpeed => 'Speed';

  @override
  String get mapParticipantDistance => 'Distance to me';

  @override
  String get mapParticipantHeading => 'Heading';

  @override
  String get mapParticipantBattery => 'Battery';

  @override
  String get mapParticipantStatusRiding => 'Riding to meeting';

  @override
  String get mapParticipantStatusArrived => 'Arrived';

  @override
  String get mapParticipantStatusIdle => 'Idle';

  @override
  String mapParticipantBatteryValue(int percent) => '${percent}%';

  @override
  String mapParticipantSpeedValue(String kmh) => '${kmh} km/h';

  @override
  String mapParticipantDistanceValue(String meters) => '${meters} m';

  @override
  String get mapHeadingN => 'North';

  @override
  String get mapHeadingNE => 'Northeast';

  @override
  String get mapHeadingE => 'East';

  @override
  String get mapHeadingSE => 'Southeast';

  @override
  String get mapHeadingS => 'South';

  @override
  String get mapHeadingSW => 'Southwest';

  @override
  String get mapHeadingW => 'West';

  @override
  String get mapHeadingNW => 'Northwest';

  @override
  String get gpsPermissionDenied => 'Location permission denied';

  @override
  String get gpsPermissionDeniedForever => 'Location permission permanently denied. Open settings to enable.';

  @override
  String get gpsServiceDisabled => 'Location services are disabled';

  @override
  String get gpsOpenSettings => 'Open settings';

  @override
  String get gpsForegroundTracking => 'Pokatuha is sharing your location';

  @override
  String get gpsForegroundTrackingBody => 'Live position is being shared with activity participants.';

  @override
  String get pollAnonymous => 'Anonymous';

  @override
  String get pollPublic => 'Public';

  @override
  String get pollOpen => 'Open';

  @override
  String get pollClosed => 'Closed';

  @override
  String get closePoll => 'Close';

  @override
  String get pollDeadline => 'No deadline';

  @override
  String get pollOption => 'Option';

  @override
  String get addOption => 'Add option';

  @override
  String closesInMinutes(String minutes) => 'Closes in ${minutes}m';

  @override
  String closesInHours(String hours) => 'Closes in ${hours}h';

  @override
  String closesInDays(String days) => 'Closes in ${days}d';

  @override
  String closedMinutesAgo(String minutes) => 'Closed ${minutes}m ago';

  @override
  String closedHoursAgo(String hours) => 'Closed ${hours}h ago';

  @override
  String closedDaysAgo(String days) => 'Closed ${days}d ago';

  @override
  String routeStats(String km, String elev) => '${km} km • ↑ ${elev} m';

  @override
  String routeStatsWithDuration(String km, String elev, String duration) => '${km} km • ↑ ${elev} m • ⏱ ${duration}';

  @override
  String get importRoute => 'Import route';

  @override
  String get importFailed => 'Import failed';

  @override
  String get fitNotSupported => 'FIT format is not supported (proprietary binary)';

  @override
  String get unsupportedFormat => 'Unsupported file format';

  @override
  String get openInNavigator => 'Navigate';

  @override
  String get noNavigatorApp => 'No navigation app found';

  @override
  String get shareFailed => 'Share failed';

  @override
  String get download => 'Download';

  @override
  String get scanUserQrToInvite => 'Scan user QR to invite';

  @override
  String get inviteFailed => 'Invite failed';

  @override
  String get zoomIn => 'Zoom in';

  @override
  String get zoomOut => 'Zoom out';

  @override
  String get markAllRead => 'Mark all read';

  @override
  String get noNotifications => 'No notifications';

  @override
  String get ok => 'OK';

  @override
  String get noPollsYet => 'No polls yet';

  @override
  String get activityNotFound => 'Activity not found';

  @override
  String get privacy => 'Privacy';

  @override
  String get profileVisibleToPeers => 'Profile visible to peers';

  @override
  String get shareGpsByDefault => 'Share GPS by default';

  @override
  String get tapMapForCoords => 'Tap the map icon to set coordinates';

  @override
  String get imageLabel => 'image';

  @override
  String get relativeNow => 'now';

  @override
  String relativeMinutes(int minutes) => '${minutes}m';

  @override
  String relativeHours(int hours) => '${hours}h';

  @override
  String relativeDays(int days) => '${days}d';

  @override
  String userFallbackName(String id) => 'User $id';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get changePhoto => 'Change photo';

  @override
  String get photoFromCamera => 'Take photo';

  @override
  String get photoFromGallery => 'Choose from gallery';

  @override
  String get removePhoto => 'Remove photo';

  @override
  String get photoSaved => 'Photo saved';

  @override
  String get photoRemoved => 'Photo removed';

  @override
  String get photoError => 'Failed to save photo';

  @override
  String get usernameLabel => '@username';

  @override
  String get bioLabel => 'Bio';

  @override
  String get visibilityPrivate => 'Private';

  @override
  String get visibilityLinkOnly => 'Link only';

  @override
  String get visibilityPublic => 'Public';
}