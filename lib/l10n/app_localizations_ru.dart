// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appName => 'Покатуха';

  @override
  String get tabHome => 'Главная';

  @override
  String get tabActivities => 'Активности';

  @override
  String get tabMap => 'Карта';

  @override
  String get tabArchive => 'Архив';

  @override
  String get tabProfile => 'Профиль';

  @override
  String get createActivity => 'Создать активность';

  @override
  String get editActivity => 'Редактировать';

  @override
  String get title => 'Название';

  @override
  String get description => 'Описание';

  @override
  String get date => 'Дата';

  @override
  String get time => 'Время';

  @override
  String get meetingPoint => 'Точка сбора';

  @override
  String get activityType => 'Тип активности';

  @override
  String get visibility => 'Видимость';

  @override
  String get maxParticipants => 'Макс. участников';

  @override
  String get coverImage => 'Обложка';

  @override
  String get weatherPreview => 'Прогноз погоды';

  @override
  String get save => 'Сохранить';

  @override
  String get cancel => 'Отмена';

  @override
  String get delete => 'Удалить';

  @override
  String get archive => 'Архив';

  @override
  String get chat => 'Чат';

  @override
  String get polls => 'Опросы';

  @override
  String get route => 'Маршрут';

  @override
  String get participants => 'Участники';

  @override
  String get join => 'Присоединиться';

  @override
  String get decline => 'Отклонить';

  @override
  String get leave => 'Покинуть';

  @override
  String get startRide => 'Начать заезд';

  @override
  String get finishRide => 'Завершить заезд';

  @override
  String get settings => 'Настройки';

  @override
  String get themes => 'Темы';

  @override
  String get notifications => 'Уведомления';

  @override
  String get newMessage => 'Новое сообщение';

  @override
  String get participantArrived => 'Участник прибыл';

  @override
  String get silentMode => 'Беззвучный режим';

  @override
  String get profile => 'Профиль';

  @override
  String get organizer => 'Организатор';

  @override
  String get noActivities => 'Активностей пока нет';

  @override
  String get noActivitiesHint => 'Создайте первую активность, чтобы начать';

  @override
  String get noArchive => 'В архиве пусто';

  @override
  String get upcoming => 'Предстоящие';

  @override
  String get live => 'В эфире';

  @override
  String get finished => 'Завершено';

  @override
  String arrivalNear(String name) {
    return '$name в 500 м';
  }

  @override
  String arrivalClose(String name) {
    return '$name приближается';
  }

  @override
  String arrivalArrived(String name) {
    return '$name прибыл';
  }

  @override
  String get offlineMode => 'Автономный режим';

  @override
  String get syncing => 'Синхронизация…';

  @override
  String get allSynced => 'Все изменения синхронизированы';

  @override
  String get gpsSharingOff => 'GPS отключён до начала заезда';

  @override
  String get addPoll => 'Добавить опрос';

  @override
  String get singleChoice => 'Один вариант';

  @override
  String get multipleChoice => 'Несколько вариантов';

  @override
  String get vote => 'Голосовать';

  @override
  String get addRoute => 'Добавить маршрут';

  @override
  String get importGpx => 'Импорт GPX';

  @override
  String get exportGpx => 'Экспорт GPX';

  @override
  String get selectMapProvider => 'Провайдер карт';

  @override
  String get openStreetMap => 'OpenStreetMap';

  @override
  String get mapLibre => 'MapLibre';

  @override
  String get googleMaps => 'Google Maps';

  @override
  String get hereMaps => 'HERE';

  @override
  String get twoGis => '2ГИС';

  @override
  String get yandexMaps => 'Яндекс Карты';

  @override
  String get language => 'Язык';

  @override
  String get appearance => 'Оформление';

  @override
  String get lightTheme => 'Светлая';

  @override
  String get darkTheme => 'Тёмная';

  @override
  String get amoledTheme => 'AMOLED';

  @override
  String get accentColor => 'Акцентный цвет';

  @override
  String get english => 'English';

  @override
  String get russian => 'Русский';

  @override
  String get confirmExit => 'Отменить несохранённые изменения?';

  @override
  String get yes => 'Да';

  @override
  String get no => 'Нет';

  @override
  String get distance => 'Дистанция';

  @override
  String get duration => 'Длительность';

  @override
  String get elevation => 'Набор высоты';

  @override
  String get avgSpeed => 'Средняя скорость';

  @override
  String get welcome => 'Добро пожаловать в Покатуху';

  @override
  String get welcomeHint => 'Создайте локальный профиль, чтобы начать';

  @override
  String get yourName => 'Ваше имя';

  @override
  String get continueButton => 'Продолжить';

  @override
  String get search => 'Поиск';
}
