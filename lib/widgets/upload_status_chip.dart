import 'package:flutter/material.dart';
import '../theme.dart';

/// Sync state of a recorded activity, shown by [UploadStatusChip].
enum UploadStatus { local, uploading, uploaded, failed }

/// A pill chip showing an activity's upload state: a status dot + mono caps
/// label, tinted by the semantic colour for the state.
class UploadStatusChip extends StatelessWidget {
  const UploadStatusChip({super.key, required this.status});

  final UploadStatus status;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<TrackTheme>()!;

    final (String label, Color color) = switch (status) {
      UploadStatus.local => ('LOCAL', ext.txt2),
      UploadStatus.uploading => ('UPLOADING', ext.uploading),
      UploadStatus.uploaded => ('UPLOADED', ext.uploaded),
      UploadStatus.failed => ('FAILED', ext.failed),
    };
    // LOCAL is a neutral state — hollow dot, no coloured border.
    final bool neutral = status == UploadStatus.local;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: ext.s2,
        borderRadius: BorderRadius.circular(ext.radiusChip),
        border: Border.all(color: neutral ? ext.line : color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: neutral ? Colors.transparent : color,
              border: neutral ? Border.all(color: ext.txt3, width: 1.5) : null,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: kFontNum,
              fontWeight: FontWeight.w700,
              fontSize: 10,
              letterSpacing: 1,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
