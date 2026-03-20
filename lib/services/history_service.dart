import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/activity_record.dart';

class HistoryService {
  static const String _key = 'activity_history';

  Future<List<ActivityRecord>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);
    if (jsonString == null) return [];

    final List<dynamic> decoded = jsonDecode(jsonString) as List<dynamic>;
    return decoded
        .map((e) => ActivityRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveRecord(ActivityRecord record) async {
    final history = await loadHistory();
    history.insert(0, record);
    await _persist(history);
  }

  Future<void> deleteRecord(String id) async {
    final history = await loadHistory();
    history.removeWhere((r) => r.id == id);
    await _persist(history);
  }

  Future<void> updateRecord(ActivityRecord record) async {
    final history = await loadHistory();
    final index = history.indexWhere((r) => r.id == record.id);
    if (index != -1) {
      history[index] = record;
      await _persist(history);
    }
  }

  Future<void> _persist(List<ActivityRecord> history) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(history.map((r) => r.toJson()).toList());
    await prefs.setString(_key, jsonString);
  }
}
