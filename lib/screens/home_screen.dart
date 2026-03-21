import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/activity_record.dart';
import '../services/history_service.dart';
import '../services/upload_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final HistoryService _historyService = HistoryService();
  final UploadService _uploadService = UploadService();

  List<ActivityRecord> _history = [];
  bool _loading = true;
  final Set<String> _uploading = {};

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await _historyService.loadHistory();
    setState(() {
      _history = history;
      _loading = false;
    });
  }

  Future<void> _deleteRecord(ActivityRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: const Text('Delete activity?', style: TextStyle(color: Colors.white)),
        content: const Text('This cannot be undone.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _historyService.deleteRecord(record.id);
      await _loadHistory();
    }
  }

  Future<void> _uploadRecord(ActivityRecord record) async {
    if (_uploading.contains(record.id)) return;

    final prefs = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString('api_base_url') ?? '';
    final apiKey = prefs.getString('api_key') ?? '';

    if (baseUrl.isEmpty || apiKey.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Configure API URL and key in Settings first')),
      );
      return;
    }

    setState(() => _uploading.add(record.id));
    try {
      final file = File(record.gpxFilePath);
      final result = await _uploadService.uploadTrack(
          file, record.activityType, baseUrl, apiKey);

      if (result.success) {
        final updated = record.copyWith(uploaded: true);
        await _historyService.updateRecord(updated);
        await _loadHistory();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Uploaded successfully')),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: ${result.error}'),
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading.remove(record.id));
    }
  }

  IconData _activityIcon(String type) {
    switch (type) {
      case 'Ride':
        return Icons.directions_bike;
      case 'Walk':
        return Icons.directions_walk;
      case 'Football':
        return Icons.sports_soccer;
      default:
        return Icons.fitness_center;
    }
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes % 60}m';
    }
    return '${d.inMinutes}m ${d.inSeconds % 60}s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Track.',
          style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () async {
              await Navigator.pushNamed(context, '/settings');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await Navigator.pushNamed(context, '/record');
                  _loadHistory();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Start',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white))
                : _history.isEmpty
                    ? Center(
                        child: Text(
                          'No activities yet',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _history.length,
                        itemBuilder: (context, index) {
                          final record = _history[index];
                          return _ActivityCard(
                            record: record,
                            activityIcon: _activityIcon(record.activityType),
                            formattedDuration:
                                _formatDuration(record.movingDuration),
                            isUploading: _uploading.contains(record.id),
                            onUpload: () => _uploadRecord(record),
                            onDelete: () => _deleteRecord(record),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final ActivityRecord record;
  final IconData activityIcon;
  final String formattedDuration;
  final bool isUploading;
  final VoidCallback onUpload;
  final VoidCallback onDelete;

  const _ActivityCard({
    required this.record,
    required this.activityIcon,
    required this.formattedDuration,
    required this.isUploading,
    required this.onUpload,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onDelete,
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(activityIcon, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.activityType,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMM d, yyyy  HH:mm').format(record.startedAt),
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  '${record.distanceKm.toStringAsFixed(2)} km  •  $formattedDuration  •  ${record.avgSpeedKmh.toStringAsFixed(1)} km/h',
                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (record.uploaded)
            const Icon(Icons.check_circle, color: Colors.green, size: 24)
          else if (isUploading)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white54),
            )
          else
            IconButton(
              icon: const Icon(Icons.cloud_upload_outlined,
                  color: Colors.white54),
              onPressed: onUpload,
            ),
        ],
      ),
    ),
    );
  }
}
