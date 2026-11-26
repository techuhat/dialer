import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/models/contact_photo_settings.dart';
import '../core/widgets/photo_backdrop.dart';

/// Full-screen preview page where the user can configure how their contact
/// photo will appear on the call screen.
///
/// Returns [ContactPhotoSettings] via `Navigator.pop(context, settings)` on
/// confirm, or `null` on cancel.
class ContactPhotoPreviewPage extends StatefulWidget {
  const ContactPhotoPreviewPage({
    required this.photoBytes,
    required this.contactId,
    this.initialSettings,
    this.contactName,
    super.key,
  });

  final Uint8List photoBytes;
  final String contactId;
  final ContactPhotoSettings? initialSettings;
  final String? contactName;

  @override
  State<ContactPhotoPreviewPage> createState() =>
      _ContactPhotoPreviewPageState();
}

class _ContactPhotoPreviewPageState extends State<ContactPhotoPreviewPage> {
  late double _overlayOpacity;
  late double _rotation;
  late String _fitMode;

  @override
  void initState() {
    super.initState();
    final s = widget.initialSettings;
    _overlayOpacity = s?.overlayOpacity ?? 0.35;
    _rotation = s?.rotation ?? 0;
    _fitMode = s?.fitMode ?? PhotoFitMode.cover;
  }

  BoxFit _boxFit(String mode) => PhotoBackdrop.boxFit(mode);

  void _confirm() {
    Navigator.of(context).pop(
      ContactPhotoSettings(
        contactId: widget.contactId,
        overlayOpacity: _overlayOpacity,
        rotation: _rotation,
        fitMode: _fitMode,
      ),
    );
  }

  void _cancel() {
    Navigator.of(context).pop(null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1929),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Transform.rotate(
            angle: _rotation * math.pi / 180,
            child: Image.memory(
              widget.photoBytes,
              fit: _boxFit(_fitMode),
              width: double.infinity,
              height: double.infinity,
              filterQuality: FilterQuality.high,
              gaplessPlayback: true,
            ),
          ),

          Container(color: Colors.black.withValues(alpha: _overlayOpacity)),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: <Widget>[
                  const Spacer(),
                  _buildCallerInfo(),
                  const Spacer(flex: 2),
                ],
              ),
            ),
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildControlsPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildCallerInfo() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24, width: 2),
            image: DecorationImage(
              image: MemoryImage(widget.photoBytes),
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          widget.contactName ?? 'Contact Name',
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          '00:00',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white60,
          ),
        ),
      ],
    );
  }

  Widget _buildControlsPanel() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          color: Colors.black.withValues(alpha: 0.55),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _buildSliderRow(
                label: 'Overlay',
                value: _overlayOpacity,
                min: 0.0,
                max: 0.85,
                onChanged: (v) => setState(() => _overlayOpacity = v),
              ),
              const SizedBox(height: 16),

              _buildSegmentRow(
                label: 'Rotation',
                options: const <double>[0, 90, 180, 270],
                selected: _rotation,
                labelBuilder: (v) => '${v.toInt()}°',
                onSelect: (v) => setState(() => _rotation = v),
              ),
              const SizedBox(height: 16),

              _buildSegmentRowString(
                label: 'Fit',
                options: PhotoFitMode.all,
                selected: _fitMode,
                labelBuilder: PhotoFitMode.label,
                onSelect: (v) => setState(() => _fitMode = v),
              ),
              const SizedBox(height: 24),

              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _cancel,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white30),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _confirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Confirm'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            activeColor: const Color(0xFF42A5F5),
            inactiveColor: Colors.white24,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 42,
          child: Text(
            '${(value * 100).toInt()}%',
            textAlign: TextAlign.end,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildSegmentRow<T>({
    required String label,
    required List<T> options,
    required T selected,
    required String Function(T) labelBuilder,
    required ValueChanged<T> onSelect,
  }) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: options.map((opt) {
                final bool isSelected = opt == selected;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(labelBuilder(opt)),
                    selected: isSelected,
                    onSelected: (_) => onSelect(opt),
                    selectedColor: const Color(0xFF42A5F5),
                    backgroundColor: Colors.white12,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 12,
                    ),
                    side: BorderSide.none,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSegmentRowString({
    required String label,
    required List<String> options,
    required String selected,
    required String Function(String) labelBuilder,
    required ValueChanged<String> onSelect,
  }) {
    return _buildSegmentRow<String>(
      label: label,
      options: options,
      selected: selected,
      labelBuilder: labelBuilder,
      onSelect: onSelect,
    );
  }
}
