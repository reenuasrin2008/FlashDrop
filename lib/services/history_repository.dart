import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flashdrop/models/transfer_session.dart';

class HistoryRepository {
  static const _historyKey = 'flashdrop_transfer_history_v1';
  static const _benchmarkKey = 'flashdrop_benchmarks_v1';
  static const _deviceNameKey = 'flashdrop_device_name_v1';

  Future<List<TransferHistoryEntry>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw == null || raw.isEmpty) return const [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => TransferHistoryEntry.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> addHistoryEntry(TransferHistoryEntry entry) async {
    final existing = await loadHistory();
    final updated = [entry, ...existing].take(100).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_historyKey, jsonEncode(updated.map((e) => e.toJson()).toList()));
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }

  Future<List<BenchmarkRecord>> loadBenchmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_benchmarkKey);
    if (raw == null || raw.isEmpty) return const [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => BenchmarkRecord.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> addBenchmark(BenchmarkRecord record) async {
    final existing = await loadBenchmarks();
    final updated = [record, ...existing].take(50).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_benchmarkKey, jsonEncode(updated.map((e) => e.toJson()).toList()));
  }

  Future<void> clearBenchmarks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_benchmarkKey);
  }

  Future<String?> loadDeviceName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_deviceNameKey);
  }

  Future<void> saveDeviceName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_deviceNameKey, name.trim());
  }
}
