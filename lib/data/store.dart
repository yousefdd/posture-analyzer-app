import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../analysis/analyzer.dart';

/// A finished session, kept for the history list.
class Session {
  Session({
    required this.at,
    required this.exercise,
    required this.source,
    required this.report,
    this.video,
  });

  final DateTime at;
  final Exercise exercise;
  final String source; // 'camera' or 'video'
  final Report report;
  final String? video;

  Map<String, dynamic> toJson() => {
        'at': at.toIso8601String(),
        'exercise': exercise.name,
        'source': source,
        'title': report.title,
        'score': report.score,
        'evaluation': report.evaluation,
        'lines': report.lines,
        'video': video,
      };

  static Session? fromJson(Map<String, dynamic> j) {
    try {
      return Session(
        at: DateTime.parse(j['at'] as String),
        exercise: Exercise.values.byName(j['exercise'] as String),
        source: j['source'] as String? ?? 'camera',
        report: Report(
          title: j['title'] as String,
          score: (j['score'] as num).toInt(),
          evaluation: j['evaluation'] as String,
          lines: [...(j['lines'] as List).map((e) => '$e')],
        ),
        video: j['video'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Settings, the chosen exercise and camera, and the session history, on the phone.
class Store {
  static const _settings = 'fa.settings';
  static const _exercise = 'fa.exercise';
  static const _front = 'fa.front';
  static const _history = 'fa.history';
  static const maxHistory = 100;

  static Future<SharedPreferences> get _p => SharedPreferences.getInstance();

  static Future<Settings> settings() async {
    final s = (await _p).getString(_settings);
    if (s == null) return const Settings();
    try {
      return Settings.fromJson(Map<String, dynamic>.from(jsonDecode(s) as Map));
    } catch (_) {
      return const Settings();
    }
  }

  static Future<void> saveSettings(Settings s) async => (await _p).setString(_settings, jsonEncode(s.toJson()));

  static Future<Exercise> exercise() async {
    final n = (await _p).getString(_exercise);
    return Exercise.values.where((e) => e.name == n).firstOrNull ?? Exercise.stance;
  }

  static Future<void> saveExercise(Exercise e) async => (await _p).setString(_exercise, e.name);

  static Future<bool> frontCamera() async => (await _p).getBool(_front) ?? true;
  static Future<void> saveFrontCamera(bool v) async => (await _p).setBool(_front, v);

  static Future<List<Session>> history() async {
    final list = (await _p).getStringList(_history) ?? const [];
    return [
      for (final s in list)
        if (Session.fromJson(Map<String, dynamic>.from(jsonDecode(s) as Map)) case final x?) x,
    ];
  }

  static Future<void> add(Session s) async {
    final p = await _p;
    final list = [jsonEncode(s.toJson()), ...(p.getStringList(_history) ?? const <String>[])];
    await p.setStringList(_history, list.take(maxHistory).toList());
  }

  static Future<void> remove(int index) async {
    final p = await _p;
    final list = [...(p.getStringList(_history) ?? const <String>[])];
    if (index >= 0 && index < list.length) list.removeAt(index);
    await p.setStringList(_history, list);
  }
}
