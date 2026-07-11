import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme.dart';
import '../widgets/settings_row.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const String _keyBaseUrl = 'api_base_url';
  static const String _keyApiKey = 'api_key';
  static const String _keyUploadToStrava = 'upload_to_strava';

  final TextEditingController _baseUrlController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  bool _uploadToStrava = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _baseUrlController.text = prefs.getString(_keyBaseUrl) ?? '';
      _apiKeyController.text = prefs.getString(_keyApiKey) ?? '';
      _uploadToStrava = prefs.getBool(_keyUploadToStrava) ?? false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBaseUrl, _baseUrlController.text.trim());
    await prefs.setString(_keyApiKey, _apiKeyController.text.trim());
    await prefs.setBool(_keyUploadToStrava, _uploadToStrava);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved')),
    );
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<TrackTheme>()!;

    return Scaffold(
      backgroundColor: ext.bg,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          TrackSpacing.lg,
          TrackSpacing.sm,
          TrackSpacing.lg,
          TrackSpacing.xxl,
        ),
        children: [
          _SectionHeader('SERVER'),
          _LabeledField(
            label: 'Server URL',
            child: TextField(
              controller: _baseUrlController,
              style: _fieldStyle(ext),
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: _fieldDecoration(
                ext,
                hint: 'https://myactivitiesjournal.azurewebsites.net',
              ),
            ),
          ),
          const SizedBox(height: TrackSpacing.md),
          _LabeledField(
            label: 'API key',
            child: TextField(
              controller: _apiKeyController,
              style: _fieldStyle(ext),
              obscureText: true,
              autocorrect: false,
              decoration: _fieldDecoration(ext, hint: 'Enter your API key'),
            ),
          ),
          const SizedBox(height: TrackSpacing.xl),
          _SectionHeader('GENERAL'),
          SettingsRow(
            title: 'Also upload to Strava',
            trailing: Switch(
              value: _uploadToStrava,
              onChanged: (value) => setState(() => _uploadToStrava = value),
            ),
          ),
          const SizedBox(height: TrackSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              'Uploads go to ActivitiesJournal, which forwards them to Strava.',
              style: TextStyle(
                fontFamily: kFontUi,
                fontSize: 12,
                height: 1.4,
                color: ext.txt3,
              ),
            ),
          ),
          const SizedBox(height: TrackSpacing.xxl),
          FilledButton(
            onPressed: _saveSettings,
            style: FilledButton.styleFrom(
              backgroundColor: ext.record,
              foregroundColor: ext.bg,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ext.radiusSm),
              ),
              textStyle: const TextStyle(
                fontFamily: kFontUi,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  TextStyle _fieldStyle(TrackTheme ext) => TextStyle(
        fontFamily: kFontNum,
        fontSize: 13,
        color: ext.txt,
      );

  InputDecoration _fieldDecoration(TrackTheme ext, {required String hint}) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(ext.radiusSm),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        fontFamily: kFontNum,
        fontSize: 13,
        color: ext.txt3,
      ),
      filled: true,
      fillColor: ext.s2,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      enabledBorder: border(ext.line),
      border: border(ext.line),
      focusedBorder: border(ext.record, 1.5),
    );
  }
}

/// Uppercase mono section header (Lume "SERVER" / "GENERAL" groups).
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<TrackTheme>()!;
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: TrackSpacing.md),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: kFontNum,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 2,
          color: ext.txt3,
        ),
      ),
    );
  }
}

/// A small label above a form field, matching the Lume settings mock.
class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<TrackTheme>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 7),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: kFontUi,
              fontWeight: FontWeight.w600,
              fontSize: 11,
              color: ext.txt2,
            ),
          ),
        ),
        child,
      ],
    );
  }
}
