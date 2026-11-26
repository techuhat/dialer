import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/models/contact.dart';
import '../core/models/contact_photo_settings.dart';
import '../core/services/caller_details.dart';
import 'call/call_widgets.dart';
import 'call/caller_backdrop.dart';

/// Full-screen preview page where the user can configure how their contact
/// photo will appear on the call screen. It draws the call screen's own
/// [CallerBackdrop] and [CallerHeader], so the preview is what a call shows.
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

  /// Null until measured: the style (poster or circle) depends on it.
  Size? _photoSize;
  bool _measured = false;

  @override
  void initState() {
    super.initState();
    final s = widget.initialSettings;
    _overlayOpacity = s?.overlayOpacity ?? CallerBackdrop.defaultOverlay;
    _rotation = s?.rotation ?? 0;
    _fitMode = s?.fitMode ?? PhotoFitMode.cover;
    PhotoStyle.measure(widget.photoBytes).then((Size? size) {
      if (mounted) {
        setState(() {
          _photoSize = size;
          _measured = true;
        });
      }
    });
  }

  ContactPhotoSettings get _settings => ContactPhotoSettings(
        contactId: widget.contactId,
        overlayOpacity: _overlayOpacity,
        rotation: _rotation,
        fitMode: _fitMode,
      );

  void _confirm() {
    Navigator.of(context).pop(_settings);
  }

  void _cancel() {
    Navigator.of(context).pop(null);
  }

  @override
  Widget build(BuildContext context) {
    final String name = widget.contactName ?? 'Contact name';
    final CallerDetails details = CallerDetails(
      contact: Contact(id: widget.contactId, name: name, phones: const <PhoneNumber>[], photoBytes: widget.photoBytes),
      photoSettings: _settings,
      photoSize: _photoSize,
    );
    final bool poster = details.photoStyle == PhotoStyle.poster;
    return Scaffold(
      backgroundColor: CallColors.top,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (_measured) ...<Widget>[
            CallerBackdrop(details: details),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                child: Align(
                  alignment: poster ? Alignment.topCenter : const Alignment(0, -0.55),
                  child: CallerHeader(
                    name: name,
                    details: details,
                    avatarSize: 104,
                    status: const Text(
                      '00:00',
                      style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ),
            ),
          ],
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
