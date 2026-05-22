// ABOUTME: Runs Eye Inspector across mobile camera and desktop picker modes.
// ABOUTME: Renders swatch saving and color set management workflows.
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'color_sampler.dart';
import 'color_store.dart';
import 'color_workspace.dart';
import 'desktop_color_picker.dart';

void main() {
  runApp(const EyeInspectorApp());
}

class EyeInspectorApp extends StatelessWidget {
  const EyeInspectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Eye Inspector',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF476C5E),
          brightness: Brightness.dark,
        ),
        fontFamily: 'Avenir Next',
        useMaterial3: true,
      ),
      home: Platform.isAndroid || Platform.isIOS
          ? const CameraInspectorScreen()
          : const DesktopPaletteScreen(),
    );
  }
}

class DesktopPaletteScreen extends StatefulWidget {
  const DesktopPaletteScreen({super.key});

  @override
  State<DesktopPaletteScreen> createState() => _DesktopPaletteScreenState();
}

class _DesktopPaletteScreenState extends State<DesktopPaletteScreen> {
  final _picker = DesktopColorPicker();
  final _store = ColorStore();
  final _setNameController = TextEditingController();

  SampledColor? _currentColor;
  List<SavedSwatch> _swatches = const [];
  List<ColorSet> _colorSets = const [];
  Timer? _cursorPreviewTimer;
  bool _isPicking = false;
  bool _isCursorPreviewPending = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSavedColors());
  }

  @override
  void dispose() {
    _cursorPreviewTimer?.cancel();
    _setNameController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedColors() async {
    final swatches = await _store.loadSwatches();
    final colorSets = await _store.loadColorSets();
    if (!mounted) {
      return;
    }

    setState(() {
      _swatches = swatches;
      _colorSets = colorSets;
      _currentColor = swatches.firstOrNull?.color;
    });
  }

  Future<void> _pickDesktopColor() async {
    if (_isPicking) {
      return;
    }

    setState(() {
      _isPicking = true;
    });

    _startCursorPreview();
    final color = await _picker.pickColor();
    _cursorPreviewTimer?.cancel();
    if (!mounted) {
      return;
    }

    setState(() {
      _isPicking = false;
      if (color != null) {
        _currentColor = color;
      }
    });
  }

  void _startCursorPreview() {
    _cursorPreviewTimer?.cancel();
    unawaited(_updateCursorPreview());
    _cursorPreviewTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      unawaited(_updateCursorPreview());
    });
  }

  Future<void> _updateCursorPreview() async {
    if (_isCursorPreviewPending) {
      return;
    }

    _isCursorPreviewPending = true;
    final color = await _picker.sampleCursorColor();
    _isCursorPreviewPending = false;
    if (!mounted || !_isPicking || color == null) {
      return;
    }

    setState(() {
      _currentColor = color;
    });
  }

  Future<void> _saveCurrentSwatch() async {
    final color = _currentColor;
    if (color == null) {
      return;
    }

    final swatches = [SavedSwatch.now(color), ..._swatches];
    setState(() {
      _swatches = swatches;
    });
    await _store.saveSwatches(swatches);
  }

  Future<void> _saveColorSet() async {
    if (_swatches.isEmpty) {
      return;
    }

    final name = _setNameController.text.trim().isEmpty
        ? 'Color Set ${_colorSets.length + 1}'
        : _setNameController.text.trim();
    final colorSet = ColorSet(
      name: name,
      swatches: List<SavedSwatch>.from(_swatches),
      createdAt: DateTime.now().toUtc(),
    );
    final colorSets = [colorSet, ..._colorSets];

    setState(() {
      _colorSets = colorSets;
      _setNameController.clear();
    });
    await _store.saveColorSets(colorSets);
  }

  @override
  Widget build(BuildContext context) {
    final color = _currentColor ?? SampledColor.black;

    return Scaffold(
      backgroundColor: const Color(0xFF111613),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 360,
                child: _DesktopControlPanel(
                  currentColor: color,
                  hasPickedColor: _currentColor != null,
                  hasSavedSwatches: _swatches.isNotEmpty,
                  isPicking: _isPicking,
                  setNameController: _setNameController,
                  onPickColor: _pickDesktopColor,
                  onSaveSwatch: _saveCurrentSwatch,
                  onSaveColorSet: _saveColorSet,
                ),
              ),
              const SizedBox(width: 22),
              Expanded(
                child: _DesktopSwatchWorkspace(
                  swatches: _swatches,
                  colorSets: _colorSets,
                  onSelectSwatch: (swatch) {
                    setState(() {
                      _currentColor = swatch.color;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopControlPanel extends StatelessWidget {
  const _DesktopControlPanel({
    required this.currentColor,
    required this.hasPickedColor,
    required this.hasSavedSwatches,
    required this.isPicking,
    required this.setNameController,
    required this.onPickColor,
    required this.onSaveSwatch,
    required this.onSaveColorSet,
  });

  final SampledColor currentColor;
  final bool hasPickedColor;
  final bool hasSavedSwatches;
  final bool isPicking;
  final TextEditingController setNameController;
  final VoidCallback onPickColor;
  final VoidCallback onSaveSwatch;
  final VoidCallback onSaveColorSet;

  @override
  Widget build(BuildContext context) {
    final foreground = currentColor.color.computeLuminance() > 0.42
        ? const Color(0xFF111613)
        : const Color(0xFFF5F0DF);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F0DF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final previewHeight = (constraints.maxHeight - 326).clamp(
            142.0,
            210.0,
          );

          return Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Eye Inspector',
                  style: TextStyle(
                    color: Color(0xFF18231E),
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Desktop color bench',
                  style: TextStyle(
                    color: Color(0xFF536056),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 18),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  height: previewHeight,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: currentColor.color,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFF18231E),
                      width: 2,
                    ),
                  ),
                  child: Text(
                    currentColor.hex,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'R ${currentColor.red}   G ${currentColor.green}   B ${currentColor.blue}',
                  style: const TextStyle(
                    color: Color(0xFF18231E),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: isPicking ? null : onPickColor,
                  icon: Icon(isPicking ? Icons.timer_outlined : Icons.colorize),
                  label: Text(
                    isPicking ? 'Move pointer' : 'Pick desktop color',
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: hasPickedColor ? onSaveSwatch : null,
                  icon: const Icon(Icons.add_box_outlined),
                  label: const Text('Save swatch'),
                ),
                const Spacer(),
                TextField(
                  controller: setNameController,
                  style: const TextStyle(color: Color(0xFF18231E)),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.only(bottom: 8),
                    labelText: 'Color set name',
                    labelStyle: TextStyle(color: Color(0xFF536056)),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF7A866D)),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: Color(0xFF476C5E),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  onPressed: hasSavedSwatches ? onSaveColorSet : null,
                  icon: const Icon(Icons.library_add_check_outlined),
                  label: const Text('Save color set'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DesktopSwatchWorkspace extends StatelessWidget {
  const _DesktopSwatchWorkspace({
    required this.swatches,
    required this.colorSets,
    required this.onSelectSwatch,
  });

  final List<SavedSwatch> swatches;
  final List<ColorSet> colorSets;
  final ValueChanged<SavedSwatch> onSelectSwatch;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 3,
          child: _Panel(
            title: 'Saved Swatches',
            child: swatches.isEmpty
                ? const _EmptyState(text: 'Pick a desktop color, then save it.')
                : GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 164,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.35,
                        ),
                    itemCount: swatches.length,
                    itemBuilder: (context, index) {
                      final swatch = swatches[index];
                      return _SwatchTile(
                        swatch: swatch,
                        onTap: () => onSelectSwatch(swatch),
                      );
                    },
                  ),
          ),
        ),
        const SizedBox(height: 18),
        Expanded(
          flex: 2,
          child: _Panel(
            title: 'Color Sets',
            child: colorSets.isEmpty
                ? const _EmptyState(text: 'Save swatches as a named set.')
                : ListView.separated(
                    itemCount: colorSets.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return _ColorSetTile(colorSet: colorSets[index]);
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF1B211D),
        border: Border.all(color: const Color(0xFF465044)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFFF5F0DF),
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 14),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _SwatchTile extends StatelessWidget {
  const _SwatchTile({required this.swatch, required this.onTap});

  final SavedSwatch swatch;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = swatch.color;
    final foreground = color.color.computeLuminance() > 0.42
        ? const Color(0xFF111613)
        : const Color(0xFFF5F0DF);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Ink(
        decoration: BoxDecoration(
          color: color.color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0x77F5F0DF)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Text(
              color.hex,
              style: TextStyle(
                color: foreground,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorSetTile extends StatelessWidget {
  const _ColorSetTile({required this.colorSet});

  final ColorSet colorSet;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF111613),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF465044)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              colorSet.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFF5F0DF),
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 34,
              child: Row(
                children: [
                  for (final swatch in colorSet.swatches.take(12))
                    Expanded(child: ColoredBox(color: swatch.color.color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF9FA891),
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class CameraInspectorScreen extends StatefulWidget {
  const CameraInspectorScreen({super.key});

  @override
  State<CameraInspectorScreen> createState() => _CameraInspectorScreenState();
}

class _CameraInspectorScreenState extends State<CameraInspectorScreen>
    with WidgetsBindingObserver {
  final ValueNotifier<SampledColor?> _colorNotifier =
      ValueNotifier<SampledColor?>(null);

  CameraController? _controller;
  Future<void>? _cameraSetup;
  String? _cameraError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cameraSetup = _startCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _colorNotifier.dispose();
    unawaited(_stopCamera());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(_stopCamera());
      return;
    }

    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {
        _cameraError = null;
        _cameraSetup = _startCamera();
      });
    }
  }

  Future<void> _startCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException('no_camera', 'No camera is available.');
      }

      final camera = cameras.firstWhere(
        (description) => description.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isIOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.yuv420,
      );

      _controller = controller;
      await controller.initialize();
      await _setCenterMetering(controller);
      await controller.startImageStream(_processFrame);
    } on CameraException catch (error) {
      _cameraError = error.description ?? error.code;
    } catch (error) {
      _cameraError = error.toString();
    }
  }

  Future<void> _setCenterMetering(CameraController controller) async {
    try {
      await controller.setFocusPoint(const Offset(0.5, 0.5));
      await controller.setExposurePoint(const Offset(0.5, 0.5));
    } on CameraException {
      // Some devices do not support explicit metering points.
    }
  }

  Future<void> _stopCamera() async {
    final controller = _controller;
    _controller = null;
    if (controller == null) {
      return;
    }

    if (controller.value.isStreamingImages) {
      await controller.stopImageStream();
    }
    await controller.dispose();
  }

  void _processFrame(CameraImage image) {
    final sample = ColorSampler.sampleCameraImage(image);
    if (sample == null) {
      return;
    }

    _colorNotifier.value = sample;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101413),
      body: FutureBuilder<void>(
        future: _cameraSetup,
        builder: (context, snapshot) {
          final controller = _controller;
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _LoadingView();
          }

          if (_cameraError != null ||
              controller == null ||
              !controller.value.isInitialized) {
            return _CameraErrorView(message: _cameraError);
          }

          return _InspectorView(
            controller: controller,
            colorNotifier: _colorNotifier,
          );
        },
      ),
    );
  }
}

class _InspectorView extends StatelessWidget {
  const _InspectorView({required this.controller, required this.colorNotifier});

  final CameraController controller;
  final ValueNotifier<SampledColor?> colorNotifier;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(child: CameraPreview(controller)),
        const _Viewfinder(),
        SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: ValueListenableBuilder<SampledColor?>(
                valueListenable: colorNotifier,
                builder: (context, sample, child) {
                  return _Readout(sample: sample);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Viewfinder extends StatelessWidget {
  const _Viewfinder();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(child: CustomPaint(painter: _ViewfinderPainter()));
  }
}

class _ViewfinderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.shortestSide * 0.12, 56.0);
    final outerPaint = Paint()
      ..color = const Color(0xDDF1F4E8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    final innerPaint = Paint()
      ..color = const Color(0x88476C5E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final shadePaint = Paint()..color = const Color(0x66000000);
    final clearPaint = Paint()
      ..blendMode = BlendMode.clear
      ..style = PaintingStyle.fill;

    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(Offset.zero & size, shadePaint);
    canvas.drawCircle(center, radius + 8, clearPaint);
    canvas.restore();

    canvas.drawCircle(center, radius, outerPaint);
    canvas.drawCircle(center, radius * 0.56, innerPaint);
    canvas.drawLine(
      center.translate(-radius - 18, 0),
      center.translate(-radius + 2, 0),
      outerPaint,
    );
    canvas.drawLine(
      center.translate(radius - 2, 0),
      center.translate(radius + 18, 0),
      outerPaint,
    );
    canvas.drawLine(
      center.translate(0, -radius - 18),
      center.translate(0, -radius + 2),
      outerPaint,
    );
    canvas.drawLine(
      center.translate(0, radius - 2),
      center.translate(0, radius + 18),
      outerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Readout extends StatelessWidget {
  const _Readout({required this.sample});

  final SampledColor? sample;

  @override
  Widget build(BuildContext context) {
    final value = sample ?? SampledColor.black;
    final textColor = value.color.computeLuminance() > 0.42
        ? const Color(0xFF101413)
        : const Color(0xFFF1F4E8);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xE6141917),
        border: Border.all(color: const Color(0x55F1F4E8)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              width: 86,
              height: 86,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: value.color,
                border: Border.all(color: const Color(0xAAF1F4E8), width: 1.4),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '9x9',
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.78),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value.hex,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFF1F4E8),
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'R ${value.red}   G ${value.green}   B ${value.blue}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFB8C3B2),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox.square(
        dimension: 44,
        child: CircularProgressIndicator(
          color: Color(0xFFF1F4E8),
          strokeWidth: 3,
        ),
      ),
    );
  }
}

class _CameraErrorView extends StatelessWidget {
  const _CameraErrorView({required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.photo_camera_back_outlined,
              size: 56,
              color: Color(0xFFF1F4E8),
            ),
            const SizedBox(height: 24),
            const Text(
              'Camera unavailable',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFF1F4E8),
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message ?? 'Allow camera access and reopen the app.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFB8C3B2),
                fontSize: 16,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
