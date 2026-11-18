import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

part 'messages_en.dart';
part 'messages_nb.dart';
part 'messages_fr.dart';
part 'messages_es.dart';
part 'messages_de.dart';

enum L {
  settings,
  theme,
  language,
  system,
  searchLanguages,
  noLanguages,
  themeSaveError,
  languageSaveError,
  chooseTheme,
  tonight,
  sounds,
  saved,
  alarms,
  cancel,
  delete,
  save,
  add,
  change,
  play,
  pause,
  stop,
  snooze,
  nightSounds,
  settleIn,
  soundscape,
  addLayer,
  seeAll,
  allSoundsAdded,
  playingSoftly,
  readyToPlay,
  layerCountOne,
  layerCountOther,
  stopReset,
  masterVolume,
  startOneSound,
  layerFavorites,
  browseSounds,
  all,
  nature,
  water,
  warmth,
  ambient,
  imported,
  birds,
  fire,
  ocean,
  findCalm,
  importSound,
  layerDescription,
  searchSounds,
  clearSearch,
  soundCountOne,
  soundCountOther,
  inYourMix,
  importEmpty,
  noMatchingSounds,
  addedToMix,
  removeNamed,
  savedForLater,
  savedDescription,
  mixRotation,
  savedLocal,
  firstMix,
  combineSave,
  noAvailableSounds,
  deleteNamed,
  playNamed,
  off,
  daily,
  weekly,
  today,
  week,
  noMixQueued,
  rotationOff,
  rotationDaily,
  rotationWeekly,
  rotationEmpty,
  addWeek,
  saveRotation,
  currentSlot,
  unassigned,
  monday,
  tuesday,
  wednesday,
  thursday,
  friday,
  saturday,
  sunday,
  mon,
  tue,
  wed,
  thu,
  fri,
  sat,
  sun,
  weekdays,
  sleepTimer,
  followAlarm,
  sleepTimerTonight,
  playFor,
  fadeOver,
  minutes,
  hours,
  shortDuration,
  percent,
  noFade,
  setSleepTimer,
  disableTimer,
  followingAlarm,
  stopsAtAlarm,
  playbackPlan,
  playbackTitle,
  setTimer,
  fadingNow,
  fadeStartsIn,
  silentIn,
  pausedWithAlarm,
  timerPaused,
  noTimerRunning,
  pastStop,
  stopOrSnooze,
  chooseEnd,
  timerShortened,
  endsAtAlarm,
  fadeWithPlayback,
  fadeAt,
  playsFor,
  silentBy,
  deleteAlarm,
  keepAlarm,
  addAlarm,
  alarmUnavailable,
  noAlarms,
  deleteAlarmAt,
  snoozed,
  once,
  everyDay,
  allowExact,
  allowExactDetails,
  allowNotifications,
  allowNotificationsDetails,
  allowFullScreen,
  allowFullScreenDetails,
  allowIosSettings,
  allowIosSettingsDetails,
  allowIos,
  allowIosDetails,
  alarmSaveError,
  editAlarm,
  repeatOnce,
  repeat,
  customFade,
  customFadeDetails,
  finishSounds,
  atAlarm,
  beforeAlarm,
  saving,
  saveAlarm,
  alarmRinging,
  alarmReadError,
  alarmUpdateError,
  alarmRefreshError,
  alarmCheckError,
  beforePlayPastStop,
  rotationSaveError,
  importTitle,
  importNotice,
  chooseAudioFormat,
  chooseFile,
  soundImported,
  emptyAudio,
  unreadableAudio,
  invalidImport,
  loadedSoundError,
  volumeError,
  addSoundFirst,
  playError,
  stopError,
  addBeforeSave,
  mixSaved,
  mixSaveError,
  nightMix,
  nameMix,
  nameHint,
  saveMix,
  mixNoSounds,
  playingMix,
  mixLoadError,
  deleteMix,
  deleteMixDetail,
  keepMix,
  mixDeleteError,
  startupError,
  startingUp,
  alarmTitle,
  snoozeMinutes,
  alarmAlertDetail,
  alarmChannel,
  snoozeError,
  exactRequired,
  notificationsRequired,
  alarmDeleteError,
  alarmInvalid,
  alarmBusy,
  audioFiles,
}

class RestStrings {
  const RestStrings(this.locale);

  static const delegate = _RestStringsDelegate();
  static const supportedLocales = [
    Locale('en'),
    Locale('nb'),
    Locale('fr'),
    Locale('es'),
    Locale('de'),
  ];
  final Locale locale;

  static RestStrings of(BuildContext context) =>
      Localizations.of<RestStrings>(context, RestStrings) ??
      const RestStrings(Locale('en'));

  static Locale resolve(List<Locale>? locales, Iterable<Locale> supported) {
    final normalized = locales
        ?.map(
          (locale) => locale.languageCode == 'no' ? const Locale('nb') : locale,
        )
        .toList();
    return basicLocaleListResolution(normalized, supported);
  }

  String text(L key, [List<Object> values = const []]) {
    final messages = switch (locale.languageCode) {
      'nb' => _nb,
      'fr' => _fr,
      'es' => _es,
      'de' => _de,
      _ => _en,
    };
    final template = messages[key] ?? _en[key]!;
    if (values.isEmpty) return template;
    return template.replaceAllMapped(RegExp(r'\{(\d+)\}'), (match) {
      return values[int.parse(match.group(1)!)].toString();
    });
  }

  String count(int value, L one, L other) => text(
    value == 1 || (locale.languageCode == 'fr' && value == 0) ? one : other,
    [value],
  );
}

class _RestStringsDelegate extends LocalizationsDelegate<RestStrings> {
  const _RestStringsDelegate();

  @override
  bool isSupported(Locale locale) =>
      RestStrings.supportedLocales.contains(Locale(locale.languageCode));

  @override
  Future<RestStrings> load(Locale locale) =>
      SynchronousFuture(RestStrings(locale));

  @override
  bool shouldReload(_RestStringsDelegate old) => false;
}

extension RestTranslation on BuildContext {
  String t(L key, [List<Object> values = const []]) =>
      RestStrings.of(this).text(key, values);
}
