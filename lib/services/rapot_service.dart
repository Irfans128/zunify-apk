import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/song_model.dart';
import '../models/weekly_rapot_model.dart';

/// Zunify Weekly Rapot & Sunday 18:00 WIB Notification Service
/// 1. Logs every song played >= 30 seconds in local SQLite DB.
/// 2. Computes weekly statistics, top 5 songs, top 5 artists, and Vibe Persona.
/// 3. Schedules automatic push notification every Sunday at 18:00 WIB (Asia/Jakarta).
class RapotService {
  Database? _db;
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  Future<void> init({String username = 'Fannz'}) async {
    await _initDatabase();
    await _initNotificationsAndScheduleSunday18WIB(username);
  }

  Future<void> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'zunify_rapot_stats.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE listening_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            videoId TEXT NOT NULL,
            title TEXT NOT NULL,
            artist TEXT NOT NULL,
            thumbnailUrl TEXT NOT NULL,
            highResArtUrl TEXT NOT NULL,
            durationListenedSec INTEGER NOT NULL,
            playedAtMs INTEGER NOT NULL,
            hourOfDay INTEGER NOT NULL,
            weekday INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  /// Configures local notifications and schedules weekly Sunday 18:00 WIB trigger
  Future<void> _initNotificationsAndScheduleSunday18WIB(String username) async {
    try {
      tz.initializeTimeZones();
      final jakarta = tz.getLocation('Asia/Jakarta');
      tz.setLocalLocation(jakarta);

      const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
      const initSettings = InitializationSettings(android: androidSettings);
      await _notifications.initialize(initSettings);

      const androidDetails = AndroidNotificationDetails(
        'zunify_weekly_rapot',
        'Rapot Mingguan Zunify',
        channelDescription: 'Notifikasi rekap musik mingguan setiap Minggu jam 18:00 WIB',
        importance: Importance.max,
        priority: Priority.high,
      );
      const notificationDetails = NotificationDetails(android: androidDetails);

      final nextSunday18 = _nextInstanceOfSunday18WIB(jakarta);

      await _notifications.zonedSchedule(
        777,
        'Rapot Musik Minggu Ini Siap, $username! 📊🎧',
        'Yuk intip Top Lagu, Artis Favorit, dan Vibe Persona lu minggu ini di Zunify!',
        nextSunday18,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    } catch (_) {}
  }

  tz.TZDateTime _nextInstanceOfSunday18WIB(tz.Location jakarta) {
    final now = tz.TZDateTime.now(jakarta);
    tz.TZDateTime scheduled = tz.TZDateTime(
      jakarta,
      now.year,
      now.month,
      now.day,
      18, // 18:00 WIB
      0,
    );

    while (scheduled.weekday != DateTime.sunday || scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// Logs a song listen event (called when song plays >= 30 seconds)
  Future<void> recordSongListen(ZunifySong song, int secondsListened) async {
    if (_db == null || secondsListened < 15) return;
    final now = DateTime.now();
    await _db!.insert('listening_logs', {
      'videoId': song.videoId,
      'title': song.title,
      'artist': song.artist,
      'thumbnailUrl': song.thumbnailUrl,
      'highResArtUrl': song.highResArtUrl,
      'durationListenedSec': secondsListened,
      'playedAtMs': now.millisecondsSinceEpoch,
      'hourOfDay': now.hour,
      'weekday': now.weekday,
    });
  }

  /// Generates the current week's Rapot Mingguan
  Future<WeeklyRapot> generateCurrentWeeklyRapot() async {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    if (_db == null) {
      return _emptyDemoRapot(sevenDaysAgo, now);
    }

    final rows = await _db!.query(
      'listening_logs',
      where: 'playedAtMs >= ?',
      whereArgs: [sevenDaysAgo.millisecondsSinceEpoch],
    );

    if (rows.isEmpty) {
      return _emptyDemoRapot(sevenDaysAgo, now);
    }

    int totalSeconds = 0;
    int nightListenCount = 0;
    final minutesByDay = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0};
    final songGroup = <String, Map<String, dynamic>>{};
    final artistGroup = <String, Map<String, dynamic>>{};

    for (final row in rows) {
      final sec = (row['durationListenedSec'] as num).toInt();
      final weekday = (row['weekday'] as num).toInt();
      final hour = (row['hourOfDay'] as num).toInt();
      final videoId = row['videoId'] as String;
      final artist = row['artist'] as String;

      totalSeconds += sec;
      minutesByDay[weekday] = (minutesByDay[weekday] ?? 0) + (sec ~/ 60);
      if (hour >= 21 || hour <= 3) nightListenCount++;

      // Aggregate by Song
      if (!songGroup.containsKey(videoId)) {
        songGroup[videoId] = {
          'song': ZunifySong(
            videoId: videoId,
            title: row['title'] as String,
            artist: artist,
            durationSeconds: sec,
            thumbnailUrl: row['thumbnailUrl'] as String,
            highResArtUrl: row['highResArtUrl'] as String,
            addedAt: now,
          ),
          'count': 0,
          'seconds': 0,
        };
      }
      songGroup[videoId]!['count'] = (songGroup[videoId]!['count'] as int) + 1;
      songGroup[videoId]!['seconds'] = (songGroup[videoId]!['seconds'] as int) + sec;

      // Aggregate by Artist
      if (!artistGroup.containsKey(artist)) {
        artistGroup[artist] = {
          'artist': artist,
          'count': 0,
          'seconds': 0,
          'thumb': row['thumbnailUrl'] as String,
        };
      }
      artistGroup[artist]!['count'] = (artistGroup[artist]!['count'] as int) + 1;
      artistGroup[artist]!['seconds'] = (artistGroup[artist]!['seconds'] as int) + sec;
    }

    final topSongs = songGroup.values
        .map(
          (e) => TopSongStat(
            song: e['song'] as ZunifySong,
            playCount: e['count'] as int,
            totalSeconds: e['seconds'] as int,
          ),
        )
        .toList()
      ..sort((a, b) => b.playCount.compareTo(a.playCount));

    final topArtists = artistGroup.values
        .map(
          (e) => TopArtistStat(
            artistName: e['artist'] as String,
            playCount: e['count'] as int,
            totalSeconds: e['seconds'] as int,
            sampleThumbnailUrl: e['thumb'] as String,
          ),
        )
        .toList()
      ..sort((a, b) => b.playCount.compareTo(a.playCount));

    // Determine Vibe Persona
    String personaTitle = 'Aesthetic Vibe Explorer ✨';
    String personaSub = 'Selera musik lu minggu ini bener-bener berkelas dan bervariasi!';
    if (nightListenCount > rows.length * 0.45) {
      personaTitle = 'Night Owl Listener 🌙';
      personaSub = 'Telinga lu paling aktif menjelajahi musik pas dunia lagi tidur.';
    } else if (totalSeconds > 7200) {
      personaTitle = 'Audiophile Sejati 🔥';
      personaSub = 'Musik udah jadi bahan bakar utama aktivitas lu sepanjang minggu ini!';
    }

    return WeeklyRapot(
      weekId: '${now.year}-W${((now.dayOfYear) / 7).ceil()}',
      weekStart: sevenDaysAgo,
      weekEnd: now,
      totalSecondsListened: totalSeconds,
      totalTracksPlayed: rows.length,
      topSongs: topSongs.take(5).toList(),
      topArtists: topArtists.take(5).toList(),
      vibePersonaTitle: personaTitle,
      vibePersonaSubtitle: personaSub,
      minutesPerWeekday: minutesByDay,
    );
  }

  WeeklyRapot _emptyDemoRapot(DateTime start, DateTime end) {
    return WeeklyRapot(
      weekId: '${end.year}-W45',
      weekStart: start,
      weekEnd: end,
      totalSecondsListened: 0,
      totalTracksPlayed: 0,
      topSongs: const [],
      topArtists: const [],
      vibePersonaTitle: 'Siap Mengukir Vibe Baru 🎧',
      vibePersonaSubtitle:
          'Putar lagu favoritmu minggu ini! Rekap otomatis rilis setiap Minggu jam 18:00 WIB.',
      minutesPerWeekday: const {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0},
    );
  }
}

extension _DateDayOfYear on DateTime {
  int get dayOfYear => difference(DateTime(year, 1, 1)).inDays + 1;
}
