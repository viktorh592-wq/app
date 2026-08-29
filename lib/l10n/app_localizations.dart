import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
/// ```
///
/// ## iOS Integration
///
/// Also update your iOS Info.plist file. Add entries for the supported locales.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru')
  ];


  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Pokatuha'**
  String get appName;

  /// No description provided for @tabHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get tabHome;

  /// No description provided for @tabActivities.
  ///
  /// In en, this message translates to:
  /// **'Activities'**
  String get tabActivities;

  /// No description provided for @tabMap.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get tabMap;

  /// No description provided for @tabArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get tabArchive;

  /// No description provided for @tabProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get tabProfile;

  /// No description provided for @createActivity.
  ///
  /// In en, this message translates to:
  /// **'Create activity'**
  String get createActivity;

  /// No description provided for @editActivity.
  ///
  /// In en, this message translates to:
  /// **'Edit activity'**
  String get editActivity;

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @meetingPoint.
  ///
  /// In en, this message translates to:
  /// **'Meeting point'**
  String get meetingPoint;

  /// No description provided for @activityType.
  ///
  /// In en, this message translates to:
  /// **'Activity type'**
  String get activityType;

  /// No description provided for @visibility.
  ///
  /// In en, this message translates to:
  /// **'Visibility'**
  String get visibility;

  /// No description provided for @maxParticipants.
  ///
  /// In en, this message translates to:
  /// **'Max participants'**
  String get maxParticipants;

  /// No description provided for @coverImage.
  ///
  /// In en, this message translates to:
  /// **'Cover image'**
  String get coverImage;

  /// No description provided for @weatherPreview.
  ///
  /// In en, this message translates to:
  /// **'Weather preview'**
  String get weatherPreview;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @archive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archive;

  /// No description provided for @chat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chat;

  /// No description provided for @polls.
  ///
  /// In en, this message translates to:
  /// **'Polls'**
  String get polls;

  /// No description provided for @route.
  ///
  /// In en, this message translates to:
  /// **'Route'**
  String get route;

  /// No description provided for @participants.
  ///
  /// In en, this message translates to:
  /// **'Participants'**
  String get participants;

  /// No description provided for @join.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get join;

  /// No description provided for @decline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get decline;

  /// No description provided for @leave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leave;

  /// No description provided for @startRide.
  ///
  /// In en, this message translates to:
  /// **'Start ride'**
  String get startRide;

  /// No description provided for @finishRide.
  ///
  /// In en, this message translates to:
  /// **'Finish ride'**
  String get finishRide;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @themes.
  ///
  /// In en, this message translates to:
  /// **'Themes'**
  String get themes;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @newMessage.
  ///
  /// In en, this message translates to:
  /// **'New message'**
  String get newMessage;

  /// No description provided for @participantArrived.
  ///
  /// In en, this message translates to:
  /// **'Participant arrived'**
  String get participantArrived;

  /// No description provided for @silentMode.
  ///
  /// In en, this message translates to:
  /// **'Silent mode'**
  String get silentMode;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @organizer.
  ///
  /// In en, this message translates to:
  /// **'Organizer'**
  String get organizer;

  /// No description provided for @noActivities.
  ///
  /// In en, this message translates to:
  /// **'No activities yet'**
  String get noActivities;

  /// No description provided for @noActivitiesHint.
  ///
  /// In en, this message translates to:
  /// **'Create your first activity to get started'**
  String get noActivitiesHint;

  /// No description provided for @noArchive.
  ///
  /// In en, this message translates to:
  /// **'No archived activities'**
  String get noArchive;

  /// No description provided for @upcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get upcoming;

  /// No description provided for @live.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get live;

  /// No description provided for @finished.
  ///
  /// In en, this message translates to:
  /// **'Finished'**
  String get finished;

  /// No description provided for @arrivalNear.
  ///
  /// In en, this message translates to:
  /// **'{name} is 500 m away'**
  String arrivalNear(String name);

  /// No description provided for @arrivalClose.
  ///
  /// In en, this message translates to:
  /// **'{name} is arriving'**
  String arrivalClose(String name);

  /// No description provided for @arrivalArrived.
  ///
  /// In en, this message translates to:
  /// **'{name} has arrived'**
  String arrivalArrived(String name);

  /// No description provided for @offlineMode.
  ///
  /// In en, this message translates to:
  /// **'Offline mode'**
  String get offlineMode;

  /// No description provided for @syncing.
  ///
  /// In en, this message translates to:
  /// **'Synchronizing…'**
  String get syncing;

  /// No description provided for @allSynced.
  ///
  /// In en, this message translates to:
  /// **'All changes synced'**
  String get allSynced;

  /// No description provided for @gpsSharingOff.
  ///
  /// In en, this message translates to:
  /// **'GPS sharing is off until you start the ride'**
  String get gpsSharingOff;

  /// No description provided for @addPoll.
  ///
  /// In en, this message translates to:
  /// **'Add poll'**
  String get addPoll;

  /// No description provided for @singleChoice.
  ///
  /// In en, this message translates to:
  /// **'Single choice'**
  String get singleChoice;

  /// No description provided for @multipleChoice.
  ///
  /// In en, this message translates to:
  /// **'Multiple choice'**
  String get multipleChoice;

  /// No description provided for @vote.
  ///
  /// In en, this message translates to:
  /// **'Vote'**
  String get vote;

  /// No description provided for @addRoute.
  ///
  /// In en, this message translates to:
  /// **'Add route'**
  String get addRoute;

  /// No description provided for @importGpx.
  ///
  /// In en, this message translates to:
  /// **'Import GPX'**
  String get importGpx;

  /// No description provided for @exportGpx.
  ///
  /// In en, this message translates to:
  /// **'Export GPX'**
  String get exportGpx;

  /// No description provided for @selectMapProvider.
  ///
  /// In en, this message translates to:
  /// **'Map provider'**
  String get selectMapProvider;

  /// No description provided for @openStreetMap.
  ///
  /// In en, this message translates to:
  /// **'OpenStreetMap'**
  String get openStreetMap;

  /// No description provided for @mapLibre.
  ///
  /// In en, this message translates to:
  /// **'MapLibre'**
  String get mapLibre;

  /// No description provided for @googleMaps.
  ///
  /// In en, this message translates to:
  /// **'Google Maps'**
  String get googleMaps;

  /// No description provided for @hereMaps.
  ///
  /// In en, this message translates to:
  /// **'HERE'**
  String get hereMaps;

  /// No description provided for @twoGis.
  ///
  /// In en, this message translates to:
  /// **'2GIS'**
  String get twoGis;

  /// No description provided for @yandexMaps.
  ///
  /// In en, this message translates to:
  /// **'Yandex Maps'**
  String get yandexMaps;

  /// No description provided for @cyclOSM.
  ///
  /// In en, this message translates to:
  /// **'CyclOSM'**
  String get cyclOSM;

  /// No description provided for @openTopoMap.
  ///
  /// In en, this message translates to:
  /// **'OpenTopoMap'**
  String get openTopoMap;

  /// No description provided for @esriSatellite.
  ///
  /// In en, this message translates to:
  /// **'Esri Satellite'**
  String get esriSatellite;

  /// No description provided for @cartoVoyager.
  ///
  /// In en, this message translates to:
  /// **'Carto Voyager'**
  String get cartoVoyager;

  /// No description provided for @mapLayerByContext.
  ///
  /// In en, this message translates to:
  /// **'Suggested for: {context}'**
  String mapLayerByContext(String context);

  /// No description provided for @mapContextCycling.
  ///
  /// In en, this message translates to:
  /// **'cycling'**
  String get mapContextCycling;

  /// No description provided for @mapContextMountains.
  ///
  /// In en, this message translates to:
  /// **'mountains'**
  String get mapContextMountains;

  /// No description provided for @mapContextForest.
  ///
  /// In en, this message translates to:
  /// **'forest'**
  String get mapContextForest;

  /// No description provided for @mapContextCity.
  ///
  /// In en, this message translates to:
  /// **'city'**
  String get mapContextCity;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @lightTheme.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get lightTheme;

  /// No description provided for @darkTheme.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get darkTheme;

  /// No description provided for @amoledTheme.
  ///
  /// In en, this message translates to:
  /// **'AMOLED'**
  String get amoledTheme;

  /// No description provided for @accentColor.
  ///
  /// In en, this message translates to:
  /// **'Accent color'**
  String get accentColor;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @russian.
  ///
  /// In en, this message translates to:
  /// **'Русский'**
  String get russian;

  /// No description provided for @confirmExit.
  ///
  /// In en, this message translates to:
  /// **'Discard unsaved changes?'**
  String get confirmExit;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @distance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get distance;

  /// No description provided for @duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// No description provided for @elevation.
  ///
  /// In en, this message translates to:
  /// **'Elevation'**
  String get elevation;

  /// No description provided for @avgSpeed.
  ///
  /// In en, this message translates to:
  /// **'Average speed'**
  String get avgSpeed;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Pokatuha'**
  String get welcome;

  /// No description provided for @welcomeHint.
  ///
  /// In en, this message translates to:
  /// **'Create your local profile to begin'**
  String get welcomeHint;

  /// No description provided for @yourName.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get yourName;

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @tabGroups.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get tabGroups;

  /// No description provided for @createGroup.
  ///
  /// In en, this message translates to:
  /// **'Create group'**
  String get createGroup;

  /// No description provided for @noGroups.
  ///
  /// In en, this message translates to:
  /// **'No groups'**
  String get noGroups;

  /// No description provided for @noGroupsHint.
  ///
  /// In en, this message translates to:
  /// **'Create your first group'**
  String get noGroupsHint;

  /// No description provided for @groupName.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get groupName;

  /// No description provided for @groupDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get groupDescription;

  /// No description provided for @groupType.
  ///
  /// In en, this message translates to:
  /// **'Group type'**
  String get groupType;

  /// No description provided for @groupTypePublic.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get groupTypePublic;

  /// No description provided for @groupTypePublicHint.
  ///
  /// In en, this message translates to:
  /// **'Discoverable, join without approval'**
  String get groupTypePublicHint;

  /// No description provided for @groupTypePrivate.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get groupTypePrivate;

  /// No description provided for @groupTypePrivateHint.
  ///
  /// In en, this message translates to:
  /// **'Not discoverable, invitation only'**
  String get groupTypePrivateHint;

  /// No description provided for @groupTypeInviteOnly.
  ///
  /// In en, this message translates to:
  /// **'Invite-only'**
  String get groupTypeInviteOnly;

  /// No description provided for @groupTypeInviteOnlyHint.
  ///
  /// In en, this message translates to:
  /// **'Requires admin approval'**
  String get groupTypeInviteOnlyHint;

  /// No description provided for @groupMembers.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get groupMembers;

  /// No description provided for @groupMedia.
  ///
  /// In en, this message translates to:
  /// **'Media'**
  String get groupMedia;

  /// No description provided for @groupSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get groupSettings;

  /// No description provided for @inviteToGroup.
  ///
  /// In en, this message translates to:
  /// **'Invite to group'**
  String get inviteToGroup;

  /// No description provided for @showGroupQr.
  ///
  /// In en, this message translates to:
  /// **'Show group QR'**
  String get showGroupQr;

  /// No description provided for @shareInviteLink.
  ///
  /// In en, this message translates to:
  /// **'Share invite link'**
  String get shareInviteLink;

  /// No description provided for @searchByNickname.
  ///
  /// In en, this message translates to:
  /// **'Search by nickname'**
  String get searchByNickname;

  /// No description provided for @leaveGroup.
  ///
  /// In en, this message translates to:
  /// **'Leave group'**
  String get leaveGroup;

  /// No description provided for @deleteGroup.
  ///
  /// In en, this message translates to:
  /// **'Delete group'**
  String get deleteGroup;

  /// No description provided for @deleteGroupConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete the group with its activities?'**
  String get deleteGroupConfirm;

  /// No description provided for @defaultColor.
  ///
  /// In en, this message translates to:
  /// **'Default activity color'**
  String get defaultColor;

  /// No description provided for @roleOwner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get roleOwner;

  /// No description provided for @roleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get roleAdmin;

  /// No description provided for @roleMember.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get roleMember;

  /// No description provided for @noMembers.
  ///
  /// In en, this message translates to:
  /// **'No members yet'**
  String get noMembers;

  /// No description provided for @noMedia.
  ///
  /// In en, this message translates to:
  /// **'No media yet'**
  String get noMedia;

  /// No description provided for @noMediaHint.
  ///
  /// In en, this message translates to:
  /// **'Photos and videos from group chats will appear here'**
  String get noMediaHint;

  /// No description provided for @invite.
  ///
  /// In en, this message translates to:
  /// **'Invite'**
  String get invite;

  /// No description provided for @memberAdded.
  ///
  /// In en, this message translates to:
  /// **'{name} added to the group'**
  String memberAdded(String name);

  /// No description provided for @membersCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No members} one{# member} other{# members}}'**
  String membersCount(int count);

  /// No description provided for @showMyQr.
  ///
  /// In en, this message translates to:
  /// **'Show my QR'**
  String get showMyQr;

  /// No description provided for @scanQr.
  ///
  /// In en, this message translates to:
  /// **'Scan QR'**
  String get scanQr;

  /// No description provided for @addToContacts.
  ///
  /// In en, this message translates to:
  /// **'Add to contacts'**
  String get addToContacts;

  /// No description provided for @addedToContacts.
  ///
  /// In en, this message translates to:
  /// **'Added to contacts'**
  String get addedToContacts;

  /// No description provided for @writeMessage.
  ///
  /// In en, this message translates to:
  /// **'Write'**
  String get writeMessage;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming in a later sprint'**
  String get comingSoon;

  /// No description provided for @userNotFound.
  ///
  /// In en, this message translates to:
  /// **'User not found on this device'**
  String get userNotFound;

  /// No description provided for @noUsersFound.
  ///
  /// In en, this message translates to:
  /// **'No users found'**
  String get noUsersFound;

  /// No description provided for @noUsersFoundHint.
  ///
  /// In en, this message translates to:
  /// **'Users appear after QR scan or contact exchange'**
  String get noUsersFoundHint;

  /// No description provided for @invalidQr.
  ///
  /// In en, this message translates to:
  /// **'Unrecognized QR code'**
  String get invalidQr;

  /// No description provided for @yourQrCode.
  ///
  /// In en, this message translates to:
  /// **'Your QR code'**
  String get yourQrCode;

  /// No description provided for @groupQrCode.
  ///
  /// In en, this message translates to:
  /// **'Group QR code'**
  String get groupQrCode;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @mapActions.
  ///
  /// In en, this message translates to:
  /// **'Map actions'**
  String get mapActions;

  /// No description provided for @findMe.
  ///
  /// In en, this message translates to:
  /// **'Find me'**
  String get findMe;

  /// No description provided for @shareLocation.
  ///
  /// In en, this message translates to:
  /// **'Share location'**
  String get shareLocation;

  /// No description provided for @stopSharingLocation.
  ///
  /// In en, this message translates to:
  /// **'Stop sharing location'**
  String get stopSharingLocation;

  /// No description provided for @showRoute.
  ///
  /// In en, this message translates to:
  /// **'Show route'**
  String get showRoute;

  /// No description provided for @downloadGpx.
  ///
  /// In en, this message translates to:
  /// **'Download GPX'**
  String get downloadGpx;

  /// No description provided for @selectMap.
  ///
  /// In en, this message translates to:
  /// **'Select map'**
  String get selectMap;

  /// No description provided for @showParticipants.
  ///
  /// In en, this message translates to:
  /// **'Show participants'**
  String get showParticipants;

  /// No description provided for @noActiveActivity.
  ///
  /// In en, this message translates to:
  /// **'No active activity'**
  String get noActiveActivity;

  /// No description provided for @locationSharingOn.
  ///
  /// In en, this message translates to:
  /// **'Location sharing on'**
  String get locationSharingOn;

  /// No description provided for @locationSharingOff.
  ///
  /// In en, this message translates to:
  /// **'Location sharing off'**
  String get locationSharingOff;

  /// No description provided for @noRoutes.
  ///
  /// In en, this message translates to:
  /// **'No routes yet'**
  String get noRoutes;

  /// No description provided for @noRoutesHint.
  ///
  /// In en, this message translates to:
  /// **'Add a route to a group activity'**
  String get noRoutesHint;

  /// No description provided for @gpxExported.
  ///
  /// In en, this message translates to:
  /// **'GPX is ready to share'**
  String get gpxExported;

  /// No description provided for @noParticipantsOnMap.
  ///
  /// In en, this message translates to:
  /// **'No participants with live position'**
  String get noParticipantsOnMap;

  /// No description provided for @tabMain.
  ///
  /// In en, this message translates to:
  /// **'Main'**
  String get tabMain;

  /// No description provided for @activityColor.
  ///
  /// In en, this message translates to:
  /// **'Activity color'**
  String get activityColor;

  /// No description provided for @openMap.
  ///
  /// In en, this message translates to:
  /// **'Open map'**
  String get openMap;

  /// No description provided for @shareActivity.
  ///
  /// In en, this message translates to:
  /// **'Share activity'**
  String get shareActivity;

  /// No description provided for @noRouteYet.
  ///
  /// In en, this message translates to:
  /// **'No route yet'**
  String get noRouteYet;

  /// No description provided for @kmUnit.
  ///
  /// In en, this message translates to:
  /// **'km'**
  String get kmUnit;

  /// No description provided for @mUnit.
  ///
  /// In en, this message translates to:
  /// **'m'**
  String get mUnit;

  /// No description provided for @noParticipants.
  ///
  /// In en, this message translates to:
  /// **'No participants yet'**
  String get noParticipants;

  /// No description provided for @liveSharingCount.
  ///
  /// In en, this message translates to:
  /// **'{count} live'**
  String liveSharingCount(int count);

  /// No description provided for @noMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get noMessagesYet;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// No description provided for @menuEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get menuEdit;

  /// No description provided for @menuDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get menuDuplicate;

  /// No description provided for @menuShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get menuShare;

  /// No description provided for @menuPin.
  ///
  /// In en, this message translates to:
  /// **'Pin in group'**
  String get menuPin;

  /// No description provided for @menuUnpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin from group'**
  String get menuUnpin;

  /// No description provided for @menuArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get menuArchive;

  /// No description provided for @deleteActivityConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this activity? The archive record is kept.'**
  String get deleteActivityConfirm;

  /// No description provided for @duplicated.
  ///
  /// In en, this message translates to:
  /// **'Activity duplicated'**
  String get duplicated;

  /// No description provided for @pinned.
  ///
  /// In en, this message translates to:
  /// **'Pinned in group'**
  String get pinned;

  /// No description provided for @unpinned.
  ///
  /// In en, this message translates to:
  /// **'Unpinned'**
  String get unpinned;

  /// No description provided for @archived.
  ///
  /// In en, this message translates to:
  /// **'Activity moved to archive'**
  String get archived;

  /// No description provided for @chatReaction.
  ///
  /// In en, this message translates to:
  /// **'Reaction'**
  String get chatReaction;

  /// No description provided for @chatReply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get chatReply;

  /// No description provided for @chatForward.
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get chatForward;

  /// No description provided for @chatPinMessage.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get chatPinMessage;

  /// No description provided for @chatUnpinMessage.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get chatUnpinMessage;

  /// No description provided for @chatCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get chatCopy;

  /// No description provided for @chatDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get chatDeleteMessage;

  /// No description provided for @chatForwardedFrom.
  ///
  /// In en, this message translates to:
  /// **'Forwarded from {name}'**
  String chatForwardedFrom(String name);

  /// No description provided for @chatReplyTo.
  ///
  /// In en, this message translates to:
  /// **'Reply to {name}'**
  String chatReplyTo(String name);

  /// No description provided for @chatPinnedBar.
  ///
  /// In en, this message translates to:
  /// **'{count} pinned'**
  String chatPinnedBar(int count);

  /// No description provided for @chatAttachCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get chatAttachCamera;

  /// No description provided for @chatAttachGallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get chatAttachGallery;

  /// No description provided for @chatAttachRoute.
  ///
  /// In en, this message translates to:
  /// **'Route'**
  String get chatAttachRoute;

  /// No description provided for @chatAttachFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get chatAttachFile;

  /// No description provided for @chatAttachLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get chatAttachLocation;

  /// No description provided for @chatAttachPoll.
  ///
  /// In en, this message translates to:
  /// **'Poll'**
  String get chatAttachPoll;

  /// No description provided for @chatAttachVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get chatAttachVoice;

  /// No description provided for @chatMenuSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get chatMenuSearch;

  /// No description provided for @chatMenuMedia.
  ///
  /// In en, this message translates to:
  /// **'Media'**
  String get chatMenuMedia;

  /// No description provided for @chatMenuPinned.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get chatMenuPinned;

  /// No description provided for @chatMenuSharedRoutes.
  ///
  /// In en, this message translates to:
  /// **'Shared routes'**
  String get chatMenuSharedRoutes;

  /// No description provided for @chatMenuFiles.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get chatMenuFiles;

  /// No description provided for @chatMenuMute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get chatMenuMute;

  /// No description provided for @chatMenuUnmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get chatMenuUnmute;

  /// No description provided for @chatMenuExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get chatMenuExport;

  /// No description provided for @chatReadOnlyBanner.
  ///
  /// In en, this message translates to:
  /// **'This activity is archived. The chat is read-only.'**
  String get chatReadOnlyBanner;

  /// No description provided for @chatVoiceHoldToRecord.
  ///
  /// In en, this message translates to:
  /// **'Hold to record'**
  String get chatVoiceHoldToRecord;

  /// No description provided for @chatVoiceSlideToCancel.
  ///
  /// In en, this message translates to:
  /// **'Slide down to cancel'**
  String get chatVoiceSlideToCancel;

  /// No description provided for @chatVoiceRecording.
  ///
  /// In en, this message translates to:
  /// **'Recording…'**
  String get chatVoiceRecording;

  /// No description provided for @chatSearchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search messages'**
  String get chatSearchPlaceholder;

  /// No description provided for @chatSearchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No messages found'**
  String get chatSearchNoResults;

  /// No description provided for @chatExportReady.
  ///
  /// In en, this message translates to:
  /// **'Chat exported'**
  String get chatExportReady;

  /// No description provided for @chatMuted.
  ///
  /// In en, this message translates to:
  /// **'Chat muted'**
  String get chatMuted;

  /// No description provided for @chatUnmuted.
  ///
  /// In en, this message translates to:
  /// **'Chat unmuted'**
  String get chatUnmuted;

  /// No description provided for @chatForwardTarget.
  ///
  /// In en, this message translates to:
  /// **'Forward to…'**
  String get chatForwardTarget;

  /// No description provided for @chatForwarded.
  ///
  /// In en, this message translates to:
  /// **'Message forwarded'**
  String get chatForwarded;

  /// No description provided for @chatPhotoSizeWarning.
  ///
  /// In en, this message translates to:
  /// **'Photo size: {kb} KB'**
  String chatPhotoSizeWarning(int kb);

  /// No description provided for @chatNoMedia.
  ///
  /// In en, this message translates to:
  /// **'No media in this chat yet'**
  String get chatNoMedia;

  /// No description provided for @chatNoPinned.
  ///
  /// In en, this message translates to:
  /// **'No pinned messages'**
  String get chatNoPinned;

  /// No description provided for @chatNoFiles.
  ///
  /// In en, this message translates to:
  /// **'No files in this chat yet'**
  String get chatNoFiles;

  /// No description provided for @chatNoRoutes.
  ///
  /// In en, this message translates to:
  /// **'No routes shared in this chat yet'**
  String get chatNoRoutes;

  /// No description provided for @chatOpenInMap.
  ///
  /// In en, this message translates to:
  /// **'Open in map'**
  String get chatOpenInMap;

  /// No description provided for @chatPlaybackSpeed.
  ///
  /// In en, this message translates to:
  /// **'{speed}x speed'**
  String chatPlaybackSpeed(String speed);

  /// No description provided for @chatDocumentOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get chatDocumentOpen;

  /// No description provided for @mapParticipantStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get mapParticipantStatus;

  /// No description provided for @mapParticipantSpeed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get mapParticipantSpeed;

  /// No description provided for @mapParticipantDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance to me'**
  String get mapParticipantDistance;

  /// No description provided for @mapParticipantHeading.
  ///
  /// In en, this message translates to:
  /// **'Heading'**
  String get mapParticipantHeading;

  /// No description provided for @mapParticipantBattery.
  ///
  /// In en, this message translates to:
  /// **'Battery'**
  String get mapParticipantBattery;

  /// No description provided for @mapParticipantStatusRiding.
  ///
  /// In en, this message translates to:
  /// **'Riding to meeting'**
  String get mapParticipantStatusRiding;

  /// No description provided for @mapParticipantStatusArrived.
  ///
  /// In en, this message translates to:
  /// **'Arrived'**
  String get mapParticipantStatusArrived;

  /// No description provided for @mapParticipantStatusIdle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get mapParticipantStatusIdle;

  /// No description provided for @mapParticipantBatteryValue.
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String mapParticipantBatteryValue(int percent);

  /// No description provided for @mapParticipantSpeedValue.
  ///
  /// In en, this message translates to:
  /// **'{kmh} km/h'**
  String mapParticipantSpeedValue(String kmh);

  /// No description provided for @mapParticipantDistanceValue.
  ///
  /// In en, this message translates to:
  /// **'{meters} m'**
  String mapParticipantDistanceValue(String meters);

  /// No description provided for @mapHeadingN.
  ///
  /// In en, this message translates to:
  /// **'North'**
  String get mapHeadingN;

  /// No description provided for @mapHeadingNE.
  ///
  /// In en, this message translates to:
  /// **'Northeast'**
  String get mapHeadingNE;

  /// No description provided for @mapHeadingE.
  ///
  /// In en, this message translates to:
  /// **'East'**
  String get mapHeadingE;

  /// No description provided for @mapHeadingSE.
  ///
  /// In en, this message translates to:
  /// **'Southeast'**
  String get mapHeadingSE;

  /// No description provided for @mapHeadingS.
  ///
  /// In en, this message translates to:
  /// **'South'**
  String get mapHeadingS;

  /// No description provided for @mapHeadingSW.
  ///
  /// In en, this message translates to:
  /// **'Southwest'**
  String get mapHeadingSW;

  /// No description provided for @mapHeadingW.
  ///
  /// In en, this message translates to:
  /// **'West'**
  String get mapHeadingW;

  /// No description provided for @mapHeadingNW.
  ///
  /// In en, this message translates to:
  /// **'Northwest'**
  String get mapHeadingNW;

  /// No description provided for @gpsPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission denied'**
  String get gpsPermissionDenied;

  /// No description provided for @gpsPermissionDeniedForever.
  ///
  /// In en, this message translates to:
  /// **'Location permission permanently denied. Open settings to enable.'**
  String get gpsPermissionDeniedForever;

  /// No description provided for @gpsServiceDisabled.
  ///
  /// In en, this message translates to:
  /// **'Location services are disabled'**
  String get gpsServiceDisabled;

  /// No description provided for @gpsOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get gpsOpenSettings;

  /// No description provided for @gpsForegroundTracking.
  ///
  /// In en, this message translates to:
  /// **'Pokatuha is sharing your location'**
  String get gpsForegroundTracking;

  /// No description provided for @gpsForegroundTrackingBody.
  ///
  /// In en, this message translates to:
  /// **'Live position is being shared with activity participants.'**
  String get gpsForegroundTrackingBody;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
