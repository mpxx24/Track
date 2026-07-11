import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track/theme.dart';
import 'package:track/widgets/upload_status_chip.dart';
import '_harness.dart';

void main() {
  testWidgets('renders a label for each of the four states', (tester) async {
    for (final entry in {
      UploadStatus.local: 'LOCAL',
      UploadStatus.uploading: 'UPLOADING',
      UploadStatus.uploaded: 'UPLOADED',
      UploadStatus.failed: 'FAILED',
    }.entries) {
      await tester.pumpWidget(wrapThemed(UploadStatusChip(status: entry.key)));
      expect(find.text(entry.value), findsOneWidget,
          reason: 'missing label for ${entry.key}');
    }
  });

  testWidgets('uploaded chip uses the uploaded semantic color', (tester) async {
    await tester.pumpWidget(
        wrapThemed(const UploadStatusChip(status: UploadStatus.uploaded)));
    final ctx = tester.element(find.byType(UploadStatusChip));
    final ext = Theme.of(ctx).extension<TrackTheme>()!;
    final label = tester.widget<Text>(find.text('UPLOADED'));
    expect(label.style!.color, ext.uploaded);
  });

  testWidgets('failed chip uses the failed semantic color', (tester) async {
    await tester.pumpWidget(
        wrapThemed(const UploadStatusChip(status: UploadStatus.failed)));
    final ctx = tester.element(find.byType(UploadStatusChip));
    final ext = Theme.of(ctx).extension<TrackTheme>()!;
    final label = tester.widget<Text>(find.text('FAILED'));
    expect(label.style!.color, ext.failed);
  });
}
