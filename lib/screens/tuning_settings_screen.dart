import 'package:flutter/material.dart';

import '../models/tuning_settings.dart';
import '../services/playback_controller.dart';

class TuningSettingsScreen extends StatefulWidget {
  const TuningSettingsScreen({super.key, required this.playbackController});

  final PlaybackController playbackController;

  @override
  State<TuningSettingsScreen> createState() => _TuningSettingsScreenState();
}

class _TuningSettingsScreenState extends State<TuningSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _loadTimeout;
  late final TextEditingController _seekSeconds;
  late final TextEditingController _defaultSpeed;
  late final TextEditingController _speedPresets;
  late final TextEditingController _flingDistance;
  late final TextEditingController _flingVelocity;
  late bool _nightMode;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _setControllerValues(
      widget.playbackController.tuningSettings,
      create: true,
    );
  }

  void _setControllerValues(TuningSettings settings, {bool create = false}) {
    _nightMode = settings.nightMode;
    final values = [
      settings.loadTimeoutSeconds.toString(),
      settings.seekSeconds.toString(),
      _formatNumber(settings.defaultPlaybackSpeed),
      settings.playbackSpeeds.map(_formatNumber).join(', '),
      _formatNumber(settings.carouselMinFlingDistance),
      _formatNumber(settings.carouselMinFlingVelocity),
    ];
    if (create) {
      _loadTimeout = TextEditingController(text: values[0]);
      _seekSeconds = TextEditingController(text: values[1]);
      _defaultSpeed = TextEditingController(text: values[2]);
      _speedPresets = TextEditingController(text: values[3]);
      _flingDistance = TextEditingController(text: values[4]);
      _flingVelocity = TextEditingController(text: values[5]);
    } else {
      final controllers = [
        _loadTimeout,
        _seekSeconds,
        _defaultSpeed,
        _speedPresets,
        _flingDistance,
        _flingVelocity,
      ];
      for (var index = 0; index < controllers.length; index++) {
        controllers[index].text = values[index];
      }
    }
  }

  String _formatNumber(num value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();

  String? _validateInt(String? text, int min, int max) {
    final value = int.tryParse(text?.trim() ?? '');
    return value == null || value < min || value > max
        ? 'Enter a whole number from $min to $max.'
        : null;
  }

  String? _validateDouble(String? text, double min, double max) {
    final value = double.tryParse(text?.trim() ?? '');
    return value == null || value < min || value > max
        ? 'Enter a number from ${_formatNumber(min)} to ${_formatNumber(max)}.'
        : null;
  }

  List<double>? _parseSpeeds() {
    final values = _speedPresets.text
        .split(',')
        .map((part) => double.tryParse(part.trim()))
        .toList();
    if (values.isEmpty ||
        values.any((value) => value == null || value < 0.25 || value > 4)) {
      return null;
    }
    return values.cast<double>().toSet().toList()..sort();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final speeds = _parseSpeeds()!;
    final defaultSpeed = double.parse(_defaultSpeed.text.trim());
    if (!speeds.contains(defaultSpeed)) speeds.add(defaultSpeed);
    speeds.sort();

    setState(() => _saving = true);
    await widget.playbackController.updateTuningSettings(
      TuningSettings(
        nightMode: _nightMode,
        loadTimeoutSeconds: int.parse(_loadTimeout.text.trim()),
        seekSeconds: int.parse(_seekSeconds.text.trim()),
        defaultPlaybackSpeed: defaultSpeed,
        playbackSpeeds: speeds,
        carouselMinFlingDistance: double.parse(_flingDistance.text.trim()),
        carouselMinFlingVelocity: double.parse(_flingVelocity.text.trim()),
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Settings saved.')));
  }

  Future<void> _reset() async {
    _setControllerValues(TuningSettings.defaults);
    await _save();
  }

  @override
  void dispose() {
    _loadTimeout.dispose();
    _seekSeconds.dispose();
    _defaultSpeed.dispose();
    _speedPresets.dispose();
    _flingDistance.dispose();
    _flingVelocity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 160),
            children: [
              Text('Appearance', style: Theme.of(context).textTheme.titleLarge),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Night mode'),
                subtitle: const Text('Use a mostly dark color scheme.'),
                secondary: const Icon(Icons.dark_mode_outlined),
                value: _nightMode,
                onChanged: _saving
                    ? null
                    : (value) async {
                        setState(() => _nightMode = value);
                        final current = widget.playbackController.tuningSettings;
                        await widget.playbackController.updateTuningSettings(
                          TuningSettings(
                            nightMode: value,
                            loadTimeoutSeconds: current.loadTimeoutSeconds,
                            seekSeconds: current.seekSeconds,
                            defaultPlaybackSpeed: current.defaultPlaybackSpeed,
                            playbackSpeeds: current.playbackSpeeds,
                            carouselMinFlingDistance:
                                current.carouselMinFlingDistance,
                            carouselMinFlingVelocity:
                                current.carouselMinFlingVelocity,
                          ),
                        );
                      },
              ),
              const SizedBox(height: 24),
              Text('Playback', style: Theme.of(context).textTheme.titleLarge),
              _field(
                controller: _loadTimeout,
                label: 'Load timeout (seconds)',
                help: 'A track that takes longer is logged and skipped.',
                validator: (value) => _validateInt(value, 1, 300),
              ),
              _field(
                controller: _seekSeconds,
                label: 'Back/forward interval (seconds)',
                validator: (value) => _validateInt(value, 1, 300),
              ),
              _field(
                controller: _defaultSpeed,
                label: 'Default playback speed',
                validator: (value) => _validateDouble(value, 0.25, 4),
              ),
              _field(
                controller: _speedPresets,
                label: 'Playback speed choices',
                help: 'Comma-separated values; the default is added if absent.',
                keyboardType: TextInputType.text,
                validator: (_) => _parseSpeeds() == null
                    ? 'Enter comma-separated speeds from 0.25 to 4.'
                    : null,
              ),
              const SizedBox(height: 24),
              Text(
                'Carousel page switching',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              _field(
                controller: _flingDistance,
                label: 'Minimum fling distance (pixels)',
                validator: (value) => _validateDouble(value, 0, 1000),
              ),
              _field(
                controller: _flingVelocity,
                label: 'Minimum fling velocity (pixels/second)',
                validator: (value) => _validateDouble(value, 0, 10000),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save),
                label: Text(_saving ? 'Saving…' : 'Save settings'),
              ),
              TextButton(
                onPressed: _saving ? null : _reset,
                child: const Text('Restore defaults'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? help,
    String? Function(String?)? validator,
    TextInputType keyboardType = const TextInputType.numberWithOptions(
      decimal: true,
    ),
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          helperText: help,
          border: const OutlineInputBorder(),
        ),
        keyboardType: keyboardType,
        validator: validator,
      ),
    );
  }
}
