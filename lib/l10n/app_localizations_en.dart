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
  String arrivalNear(String name) {
    return '$name is 500 m away';
  }

  @override
  String arrivalClose(String name) {
    return '$name is arriving';
  }

  @override
  String arrivalArrived(String name) {
    return '$name has arrived';
  }

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
}
