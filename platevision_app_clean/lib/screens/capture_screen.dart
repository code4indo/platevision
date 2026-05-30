import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:platevision_ai/config/app_config.dart';
import 'package:platevision_ai/theme/app_colors.dart';
import 'package:platevision_ai/theme/app_spacing.dart';
import 'package:platevision_ai/theme/app_theme.dart';
import 'package:platevision_ai/theme/app_typography.dart';
import 'package:platevision_ai/theme/app_responsive.dart';
import 'package:platevision_ai/widgets/common/lab_button.dart';
import 'package:platevision_ai/widgets/common/lab_input.dart';
import 'package:platevision_ai/models/detection_result.dart';
import 'package:platevision_ai/providers/analysis_provider.dart';
import 'package:platevision_ai/providers/auth_provider.dart';
import 'package:platevision_ai/services/storage_service.dart';
import 'package:provider/provider.dart';
import 'package:platevision_ai/widgets/common/app_scaffold.dart';

/// Sample image data model for the built-in test images.
class SampleImage {
  final String key;
  final String assetPath;
  final String label;
  final String category;
  final Color color;
  final IconData icon;

  const SampleImage({
    required this.key,
    required this.assetPath,
    required this.label,
    required this.category,
    required this.color,
    required this.icon,
  });
}

/// All available sample images (same images used in the Gradio demo).
const List<SampleImage> kSampleImages = [
  SampleImage(
    key: 'colony',
    assetPath: 'assets/images/samples/sample_colony.png',
    label: 'Colony',
    category: 'Per-Class',
    color: AppColors.colonyColor,
    icon: Icons.bubble_chart_rounded,
  ),
  SampleImage(
    key: 'bubble',
    assetPath: 'assets/images/samples/sample_bubble.jpg',
    label: 'Bubble',
    category: 'Per-Class',
    color: AppColors.bubbleColor,
    icon: Icons.water_drop_rounded,
  ),
  SampleImage(
    key: 'dust',
    assetPath: 'assets/images/samples/sample_dust.jpg',
    label: 'Dust',
    category: 'Per-Class',
    color: AppColors.dustColor,
    icon: Icons.grain_rounded,
  ),
  SampleImage(
    key: 'crack',
    assetPath: 'assets/images/samples/sample_crack.jpg',
    label: 'Crack',
    category: 'Per-Class',
    color: AppColors.crackColor,
    icon: Icons.show_chart_rounded,
  ),
  SampleImage(
    key: 'colony_bubble',
    assetPath: 'assets/images/samples/sample_colony_bubble.jpg',
    label: 'Colony + Bubble',
    category: 'Multi-Class',
    color: AppColors.accentPrimary,
    icon: Icons.layers_rounded,
  ),
  SampleImage(
    key: 'real_colony',
    assetPath: 'assets/images/samples/sample_real_colony.png',
    label: 'Real Agar Plate',
    category: 'Real',
    color: AppColors.success,
    icon: Icons.science_rounded,
  ),
  SampleImage(
    key: 'agar_saureus',
    assetPath: 'assets/images/samples/sample_agar_saureus.png',
    label: 'S. aureus',
    category: 'Real',
    color: AppColors.info,
    icon: Icons.biotech_rounded,
  ),
  SampleImage(
    key: 'agar_shigella',
    assetPath: 'assets/images/samples/sample_agar_shigella.png',
    label: 'Shigella',
    category: 'Real',
    color: AppColors.warning,
    icon: Icons.biotech_rounded,
  ),
];

// ── Dropdown option constants ──

const kMediaOptions = ['PCA', 'TSA', 'VRBA', 'EMB', 'PDA', 'MacConkey', 'Blood Agar', 'SDA', 'MRS Agar', 'Other'];
const kDilutionOptions = ['10^-1', '10^-2', '10^-3', '10^-4', '10^-5', '10^-6'];
const kCalcMethodOptions = ['Average replicate', 'Multiplier factor', 'SP plate', 'Pour plate', 'Spread plate'];
const kInoculumVolumeOptions = ['0.01 mL', '0.1 mL', '0.5 mL', '1 mL'];
const kIncubatorTempOptions = ['25°C', '30°C', '35°C', '37°C', '44°C'];
const kIncubationTimeOptions = ['24 hours', '48 hours', '72 hours', '5 days', '7 days'];
const kControlResultOptions = ['Negative', 'Positive', 'None'];
const kContaminationOptions = ['No', 'Yes - Mild', 'Yes - Severe'];
const kColonySizeOptions = ['<1 mm (Pinpoint)', '1-2 mm (Small)', '2-3 mm (Medium)', '3-5 mm (Large)', '>5 mm (Very large)'];
const kColonyColorOptions = ['White', 'Yellow', 'Cream', 'Red', 'Pink', 'Green', 'Brown', 'Black', 'Other'];
const kColonyShapeOptions = ['Circular', 'Irregular', 'Filamentous', 'Rhizoid', 'Spindle'];
const kHemolysisOptions = ['None (\u03B3)', 'Alpha (\u03B1)', 'Beta (\u03B2)'];
const kSpreadingOptions = ['No', 'Swarming', 'Spreading', 'Uncountable (>300)'];


const kSampleTypeOptions = ['Water', 'Milk', 'Solid Food', 'Surface Swab', 'Soil', 'Air', 'Wastewater', 'Cosmetics', 'Pharmaceutical', 'Other'];
const kPlateReplicateOptions = ['Plate 1', 'Plate 2', 'Plate 3', 'Plate 4', 'Plate 5', 'Plate 6'];
const kInoculationMethodOptions = ['Spread Plate', 'Pour Plate', 'Drop Plate', 'Membrane Filtration'];
const kDiluentOptions = ['Peptone Water', 'Buffered Peptone Water (BPW)', 'Physiological NaCl (0.85%)', 'Ringer Solution', 'Phosphate Buffer', 'Other'];
const kIncubationConditionOptions = ['Aerobic', 'Anaerobic', 'Microaerophilic', 'Capnophilic'];

class CaptureScreen extends StatefulWidget {
  /// When true, the header with back button is hidden (embedded mode inside a tab).
  final bool embedInTab;

  const CaptureScreen({super.key, this.embedInTab = false});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  // ── Free-text controllers ──
  // Category 1: Sample Information
  final _sampleIdController = TextEditingController();
  final _samplingLocationController = TextEditingController();
  final _samplingOfficerController = TextEditingController();
  // Category 1: Sample Information - datetime
  final _samplingTimeController = TextEditingController();
  // Category 3: Incubation Parameters
  final _incubatorEntryTimeController = TextEditingController();
  final _incubatorIdController = TextEditingController();
  // Category 4: Additional Information
  final _mediaLotController = TextEditingController();
  final _morphologyNotesController = TextEditingController();
  final _analystNameController = TextEditingController();

  // ── Dropdown state variables ──
  // Category 1: Sample Information
  String? _selectedSampleType;
  String? _selectedPlateReplicate;
  // Category 2: Method & Dilution
  String? _selectedMedia;
  String? _selectedInoculationMethod;
  String? _selectedDilution;
  String? _selectedInoculumVolume;
  String? _selectedDiluent;
  // Category 3: Incubation Parameters
  String? _selectedIncubatorTemp;
  String? _selectedIncubationTime;
  String? _selectedIncubationCondition;
  // Category 4: Additional Information (no dropdowns - results are auto)



  Uint8List? _pickedImageBytes;
  String? _pickedImageName;
  bool _isPicking = false;
  String _imageQualityLabel = '--';
  SampleImage? _selectedSample;
  Uint8List? _sampleBytes;
  bool _metadataGroup1Expanded = false;
  bool _metadataGroup2Expanded = false;
  bool _metadataGroup3Expanded = false;
  bool _metadataGroup4Expanded = false;

  // ── Zoom state ──
  final TransformationController _zoomController = TransformationController();
  double _currentZoom = 1.0;
  static const double _minZoom = 1.0;
  static const double _maxZoom = 5.0;
  static const double _zoomStep = 0.5;

  // ── Panel resize state ──
  double _leftPanelRatio = 0.50; // ratio of total width for left panel
  static const double _minLeftRatio = 0.25;
  static const double _maxLeftRatio = 0.75;
  bool _isDraggingDivider = false;

  // ── Vertical resize state (image vs samples) ──
  double _imagePanelRatio = 0.78; // ratio of left panel height for image preview
  static const double _minImageRatio = 0.40;
  static const double _maxImageRatio = 0.92;
  bool _isDraggingVDivider = false;

  @override
  void initState() {
    super.initState();
    _loadDefaults();
  }

  void _loadDefaults() {
    final prefs = StorageService.instance.loadPreferences();
    _selectedMedia = prefs.defaultMediaType;
    _selectedDilution = prefs.defaultDilution;

    // Auto-generate Sample ID
    _sampleIdController.text = _generateSampleId();

    final authProvider = context.read<AuthProvider>();
    _analystNameController.text = authProvider.currentUser?.fullName ?? '';
  }

  /// Auto-generate Sample ID with format: SPL-YYYYMMDD-HHMMSS
  String _generateSampleId() {
    final now = DateTime.now();
    return 'SPL-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _sampleIdController.dispose();
    _samplingTimeController.dispose();
    _samplingLocationController.dispose();
    _samplingOfficerController.dispose();
    _incubatorEntryTimeController.dispose();
    _incubatorIdController.dispose();
    _mediaLotController.dispose();
    _morphologyNotesController.dispose();
    _analystNameController.dispose();
    _zoomController.dispose();
    super.dispose();
  }

  Future<void> _pickFromGallery() async {
    if (_isPicking) return;
    setState(() => _isPicking = true);
    try {
      final picker = ImagePicker();
      final xFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 4096,
        maxHeight: 4096,
        imageQuality: 95,
      );
      if (xFile != null) {
        final bytes = await xFile.readAsBytes();
        final name = xFile.name;
        setState(() {
          _pickedImageBytes = bytes;
          _pickedImageName = name;
          _selectedSample = null;
          _sampleBytes = null;
          _imageQualityLabel = _assessQuality(bytes.length);
          _resetZoom();
        });
      }
    } catch (e) {
      _showError('Failed to select image: $e');
    } finally {
      setState(() => _isPicking = false);
    }
  }

  Future<void> _pickFromCamera() async {
    if (_isPicking) return;
    setState(() => _isPicking = true);
    try {
      final picker = ImagePicker();
      final xFile = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 4096,
        maxHeight: 4096,
        imageQuality: 95,
      );
      if (xFile != null) {
        final bytes = await xFile.readAsBytes();
        final name = xFile.name;
        setState(() {
          _pickedImageBytes = bytes;
          _pickedImageName = name;
          _selectedSample = null;
          _sampleBytes = null;
          _imageQualityLabel = _assessQuality(bytes.length);
          _resetZoom();
        });
      }
    } catch (e) {
      _showError('Failed to capture image: $e');
    } finally {
      setState(() => _isPicking = false);
    }
  }

  String _assessQuality(int sizeBytes) {
    final sizeMB = sizeBytes / (1024 * 1024);
    if (sizeMB > 5) return 'HIGH (${sizeMB.toStringAsFixed(1)} MB)';
    if (sizeMB > 1) return 'MEDIUM (${sizeMB.toStringAsFixed(1)} MB)';
    if (sizeMB > 0.3) return 'LOW (${sizeMB.toStringAsFixed(1)} MB)';
    return 'VERY LOW (${sizeMB.toStringAsFixed(2)} MB)';
  }

  Future<void> _selectSampleImage(SampleImage sample) async {
    try {
      final bytes = await rootBundle.load(sample.assetPath);
      final data = bytes.buffer.asUint8List();
      setState(() {
        _selectedSample = sample;
        _sampleBytes = data;
        _pickedImageBytes = null;
        _pickedImageName = null;
        _imageQualityLabel = _assessQuality(data.length);
        _resetZoom();
      });
    } catch (e) {
      _showError('Failed to load sample: $e');
    }
  }

  /// Get the current sample ID
  String get _currentSampleId => _sampleIdController.text;

  /// Build metadata map from current form state
  Map<String, String> _buildMetadata() {
    return {
      'media_type': _selectedMedia ?? '',
      'dilution': _selectedDilution ?? '',
      'inoculation_method': _selectedInoculationMethod ?? '',
      'inoculum_volume': _selectedInoculumVolume ?? '',
      'sample_type': _selectedSampleType ?? '',
      'plate_replicate': _selectedPlateReplicate ?? '',
      'sampling_time': _samplingTimeController.text,
      'sampling_location': _samplingLocationController.text,
      'sampling_officer': _samplingOfficerController.text,
      'incubator_entry_time': _incubatorEntryTimeController.text,
      'incubator_temp': _selectedIncubatorTemp ?? '',
      'incubation_time': _selectedIncubationTime ?? '',
      'incubation_condition': _selectedIncubationCondition ?? '',
      'incubator_id': _incubatorIdController.text,
      'diluent': _selectedDiluent ?? '',
      'media_lot': _mediaLotController.text,
      'analyst_name': _analystNameController.text,
      'morphology_notes': _morphologyNotesController.text,
    };
  }

  Future<void> _runAnalysis() async {
    final analysisProvider = context.read<AnalysisProvider>();
    final sampleId = _currentSampleId;
    final metadata = _buildMetadata();
    if (_sampleBytes != null && _selectedSample != null) {
      await analysisProvider.runAnalysisFromBytes(imageBytes: _sampleBytes!, fileName: '${_selectedSample!.key}.png', sampleId: sampleId, metadata: metadata);
    } else if (_pickedImageBytes != null) {
      await analysisProvider.runAnalysisFromBytes(imageBytes: _pickedImageBytes!, fileName: _pickedImageName ?? 'uploaded_image.png', sampleId: sampleId, metadata: metadata);
    } else {
      _showError('Please select an image first');
      return;
    }
    if (!mounted) return;
    if (analysisProvider.hasResult) {
      // Navigate to analysis result page to show marked image
      Navigator.of(context).pushNamed('/analysis_result');
    } else if (analysisProvider.hasError) {
      _showError(analysisProvider.errorMessage ?? 'Analysis failed');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating));
  }

  void _clearImage() {
    setState(() { _pickedImageBytes = null; _pickedImageName = null; _imageQualityLabel = '--'; _selectedSample = null; _sampleBytes = null; _resetZoom(); });
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final analysisProvider = context.watch<AnalysisProvider>();
    final hasImage = _pickedImageBytes != null || _sampleBytes != null;

    final content = Container(
      color: AppColors.bgScaffold,
      child: SafeArea(
        child: Column(
          children: [
            _buildActionBar(analysisProvider, hasImage),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final totalWidth = constraints.maxWidth;
                    final dividerWidth = 10.0;
                    final leftWidth = (totalWidth - dividerWidth) * _leftPanelRatio;
                    final rightWidth = (totalWidth - dividerWidth) * (1 - _leftPanelRatio);

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Left panel: Image Preview + Samples (vertically resizable) ──
                        SizedBox(
                          width: leftWidth,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                flex: (_imagePanelRatio * 1000).round(),
                                child: _buildImagePreview(hasImage),
                              ),
                              _buildVerticalResizeDivider(),
                              Expanded(
                                flex: ((1 - _imagePanelRatio) * 1000).round(),
                                child: _buildCompactSamples(),
                              ),
                            ],
                          ),
                        ),

                        // ── Resizable divider ──
                        _buildResizeDivider(),

                        // ── Right panel: Metadata + History ──
                        SizedBox(
                          width: rightWidth,
                          child: SingleChildScrollView(
                            padding: EdgeInsets.zero,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildCompactModeSelector(),
                                const SizedBox(height: AppSpacing.sm),

                                _buildCompactMetadata(),
                                const SizedBox(height: AppSpacing.sm),
                                SizedBox(
                                  height: 160,
                                  child: _buildHistorySection(analysisProvider),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.embedInTab) return AppScaffold(currentIndex: 1, body: content);
    return AppScaffold(currentIndex: 1, body: content);
  }

  // ============================================================
  // ACTION BAR
  // ============================================================

  Widget _buildActionBar(AnalysisProvider ap, bool hasImage) {
    final canRun = hasImage && !ap.isAnalyzing;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        border: Border(bottom: BorderSide(color: AppColors.borderSubtle, width: 1)),
      ),
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: hasImage ? AppColors.statusOnline : AppColors.statusIdle,
              boxShadow: hasImage ? [BoxShadow(color: AppColors.statusOnline.withOpacity(0.5), blurRadius: 6)] : null,
            ),
          ),
          const SizedBox(width: 8),
          Text(hasImage ? 'READY' : 'NO IMAGE',
            style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w600,
              color: hasImage ? AppColors.statusOnline : AppColors.textTertiary, letterSpacing: 1)),
          if (hasImage) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: AppColors.accentPrimary.withOpacity(0.1), borderRadius: BorderRadius.circular(3)),
              child: Text(_imageQualityLabel, style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppColors.accentPrimary)),
            ),
          ],
          const Spacer(),
          SizedBox(
            height: 36,
            child: LabButton(
              label: ap.isAnalyzing ? 'ANALYZING...' : 'RUN ANALYSIS',
              variant: LabButtonVariant.primary,
              size: LabButtonSize.md,
              icon: ap.isAnalyzing ? Icons.hourglass_top_rounded : Icons.play_arrow_rounded,
              isLoading: ap.isAnalyzing,
              onPressed: canRun ? _runAnalysis : null,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // IMAGE PREVIEW — With zoom support (scroll + buttons)
  // ============================================================

  void _resetZoom() {
    _zoomController.value = Matrix4.identity();
    setState(() => _currentZoom = 1.0);
  }

  void _zoomIn() {
    final newZoom = (_currentZoom + _zoomStep).clamp(_minZoom, _maxZoom);
    if (newZoom != _currentZoom) {
      _zoomController.value = Matrix4.identity()..scale(newZoom);
      setState(() => _currentZoom = newZoom);
    }
  }

  void _zoomOut() {
    final newZoom = (_currentZoom - _zoomStep).clamp(_minZoom, _maxZoom);
    if (newZoom != _currentZoom) {
      _zoomController.value = Matrix4.identity()..scale(newZoom);
      setState(() => _currentZoom = newZoom);
    }
  }

  void _onZoomChanged(Matrix4 matrix) {
    final scale = matrix.getMaxScaleOnAxis();
    final clamped = scale.clamp(_minZoom, _maxZoom);
    if (clamped != _currentZoom) {
      setState(() => _currentZoom = clamped);
    }
  }

  Widget _buildImagePreview(bool hasImage) {
    final isZoomed = _currentZoom > 1.0;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: isZoomed ? AppColors.accentPrimary.withOpacity(0.5) : AppColors.borderSubtle,
          width: isZoomed ? 2 : 1,
        ),
        boxShadow: isZoomed
          ? [BoxShadow(color: AppColors.accentPrimary.withOpacity(0.08), blurRadius: 8)]
          : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.bgSecondary,
              borderRadius: BorderRadius.only(topLeft: Radius.circular(AppSpacing.radiusMd), topRight: Radius.circular(AppSpacing.radiusMd)),
              border: Border(bottom: BorderSide(color: AppColors.borderSubtle, width: 1)),
            ),
            child: Row(children: [
              Icon(isZoomed ? Icons.zoom_in_rounded : Icons.image_outlined, size: 14,
                color: isZoomed ? AppColors.accentPrimary : AppColors.textTertiary),
              const SizedBox(width: 6),
              Text(isZoomed ? 'ZOOM ${_currentZoom.toStringAsFixed(1)}x' : 'IMAGE PREVIEW',
                style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w600,
                  color: isZoomed ? AppColors.accentPrimary : AppColors.textTertiary, letterSpacing: 1)),
              const Spacer(),
              // ── Zoom controls ──
              if (hasImage) ...[
                _buildZoomButton(Icons.remove_rounded, _zoomOut, _currentZoom <= _minZoom),
                const SizedBox(width: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.bgInput,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Text('${_currentZoom.toStringAsFixed(1)}x',
                    style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                ),
                const SizedBox(width: 3),
                _buildZoomButton(Icons.add_rounded, _zoomIn, _currentZoom >= _maxZoom),
                const SizedBox(width: 6),
                if (isZoomed)
                  _buildZoomButton(Icons.refresh_rounded, _resetZoom, false),
                if (isZoomed) const SizedBox(width: 6),
                GestureDetector(onTap: _clearImage, child: Icon(Icons.close_rounded, size: 14, color: AppColors.textTertiary)),
              ],
            ]),
          ),
          Expanded(
            child: hasImage
              ? ClipRRect(
                  borderRadius: BorderRadius.only(bottomLeft: Radius.circular(AppSpacing.radiusMd), bottomRight: Radius.circular(AppSpacing.radiusMd)),
                  child: Stack(fit: StackFit.expand, children: [
                    // Zoomable image with InteractiveViewer
                    InteractiveViewer(
                      transformationController: _zoomController,
                      minScale: _minZoom,
                      maxScale: _maxZoom,
                      onInteractionUpdate: (details) => _onZoomChanged(_zoomController.value),
                      child: SizedBox.expand(
                        child: _pickedImageBytes != null
                          ? Image.memory(_pickedImageBytes!, fit: BoxFit.contain)
                          : Image.memory(_sampleBytes!, fit: BoxFit.contain),
                      ),
                    ),
                    // Sample label badge
                    if (_selectedSample != null)
                      Positioned(top: 6, left: 6, child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(color: _selectedSample!.color.withOpacity(0.9), borderRadius: BorderRadius.circular(3)),
                        child: Text(_selectedSample!.label.toUpperCase(), style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 1)),
                      )),
                    // Zoom hint (bottom-left)
                    if (!isZoomed)
                      Positioned(bottom: 6, left: 6, child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xCC1A1F2E),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.borderSubtle.withOpacity(0.5)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.pinch_rounded, size: 12, color: AppColors.textTertiary),
                          const SizedBox(width: 4),
                          Text('Scroll to zoom', style: GoogleFonts.inter(fontSize: 9, color: AppColors.textTertiary)),
                        ]),
                      )),
                  ]),
                )
              : Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.add_photo_alternate_outlined, size: 40, color: AppColors.textMuted),
                  const SizedBox(height: 8),
                  Text('SELECT AN IMAGE', style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textTertiary, letterSpacing: 2)),
                ])),
          ),
        ],
      ),
    );
  }

  Widget _buildZoomButton(IconData icon, VoidCallback onTap, bool disabled) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        width: 24, height: 24,
        decoration: BoxDecoration(
          color: disabled ? AppColors.bgInput : AppColors.accentPrimary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: disabled ? AppColors.borderSubtle : AppColors.accentPrimary.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Icon(icon, size: 14,
          color: disabled ? AppColors.textMuted : AppColors.accentPrimary),
      ),
    );
  }

  // ============================================================
  // RESIZABLE DIVIDER — Drag to resize panels
  // ============================================================

  Widget _buildResizeDivider() {
    final isActive = _isDraggingDivider;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        onHorizontalDragStart: (_) => setState(() => _isDraggingDivider = true),
        onHorizontalDragEnd: (_) => setState(() => _isDraggingDivider = false),
        onHorizontalDragCancel: () => setState(() => _isDraggingDivider = false),
        onHorizontalDragUpdate: (details) {
          // Find the Row's width to calculate ratio
          final box = context.findRenderObject() as RenderBox?;
          if (box == null) return;
          final totalWidth = box.size.width - 10; // minus divider
          final currentLeft = totalWidth * _leftPanelRatio;
          final newLeft = (currentLeft + details.delta.dx).clamp(totalWidth * _minLeftRatio, totalWidth * _maxLeftRatio);
          final newRatio = newLeft / totalWidth;
          if ((newRatio - _leftPanelRatio).abs() > 0.001) {
            setState(() => _leftPanelRatio = newRatio);
          }
        },
        child: Container(
          width: 10,
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? AppColors.accentPrimary.withOpacity(0.3) : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Center(
            child: Container(
              width: 3,
              height: 40,
              decoration: BoxDecoration(
                color: isActive ? AppColors.accentPrimary : AppColors.borderMedium,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // VERTICAL RESIZE DIVIDER — Drag to resize image/samples height
  // ============================================================

  Widget _buildVerticalResizeDivider() {
    final isActive = _isDraggingVDivider;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeRow,
      child: GestureDetector(
        onVerticalDragStart: (_) => setState(() => _isDraggingVDivider = true),
        onVerticalDragEnd: (_) => setState(() => _isDraggingVDivider = false),
        onVerticalDragCancel: () => setState(() => _isDraggingVDivider = false),
        onVerticalDragUpdate: (details) {
          // Find the left panel Column height
          final leftColumn = context.findRenderObject() as RenderBox?;
          if (leftColumn == null) return;
          // Use the left panel's actual height
          // We calculate from the overall available height minus padding
          final totalHeight = leftColumn.size.height;
          final dividerH = 8.0;
          final usable = totalHeight - dividerH;
          final currentImg = usable * _imagePanelRatio;
          final newImg = (currentImg + details.delta.dy).clamp(usable * _minImageRatio, usable * _maxImageRatio);
          final newRatio = newImg / usable;
          if ((newRatio - _imagePanelRatio).abs() > 0.001) {
            setState(() => _imagePanelRatio = newRatio);
          }
        },
        child: Container(
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 30),
          decoration: BoxDecoration(
            color: isActive ? AppColors.accentPrimary.withOpacity(0.3) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: Container(
              width: 40,
              height: 3,
              decoration: BoxDecoration(
                color: isActive ? AppColors.accentPrimary : AppColors.borderMedium,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SAMPLE IMAGES
  // ============================================================

  Widget _buildCompactSamples() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.borderSubtle, width: 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.science_rounded, size: 13, color: AppColors.accentSecondary),
          const SizedBox(width: 4),
          Text('SAMPLES', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textTertiary, letterSpacing: 1.5)),
          const Spacer(),
          Text('tap to preview', style: GoogleFonts.jetBrainsMono(fontSize: 9, color: AppColors.textMuted)),
        ]),
        const SizedBox(height: 4),
        LayoutBuilder(builder: (context, constraints) {
          final gridWidth = constraints.maxWidth;
          final colCount = 8;
          final gap = 3.0;
          final cellSize = (gridWidth - (gap * (colCount - 1))) / colCount;

          return Row(
            children: kSampleImages.map((s) {
              final isSelected = _selectedSample?.key == s.key;
              return Padding(
                padding: EdgeInsets.only(right: gap),
                child: GestureDetector(
                  onTap: () => _selectSampleImage(s),
                  child: Container(
                    width: cellSize - gap,
                    height: cellSize - gap,
                    decoration: BoxDecoration(
                      color: isSelected ? s.color.withOpacity(0.15) : AppColors.bgInput,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isSelected ? s.color.withOpacity(0.9) : AppColors.borderSubtle,
                        width: isSelected ? 2.0 : 0.5,
                      ),
                      boxShadow: isSelected
                          ? [BoxShadow(color: s.color.withOpacity(0.3), blurRadius: 4)]
                          : null,
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3.5),
                          child: Image.asset(
                            s.assetPath,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, _) => Container(
                              color: s.color.withOpacity(0.1),
                              child: Center(child: Icon(s.icon, size: 12, color: s.color.withOpacity(0.5))),
                            ),
                          ),
                        ),
                        if (isSelected)
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(3.5),
                              color: s.color.withOpacity(0.2),
                            ),
                            child: Center(
                              child: Container(
                                width: 14, height: 14,
                                decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
                                child: Icon(Icons.check_rounded, size: 9, color: Colors.white),
                              ),
                            ),
                          ),
                        Positioned(
                          left: 0, right: 0, bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 1.5),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.55),
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(3.5),
                                bottomRight: Radius.circular(3.5),
                              ),
                            ),
                            child: Text(
                              s.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 5.5,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: Colors.white,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        }),
      ]),
    );
  }

  // ============================================================
  // INPUT MODE
  // ============================================================

  Widget _buildCompactModeSelector() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.borderSubtle, width: 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.input_rounded, size: 13, color: AppColors.accentSecondary),
          const SizedBox(width: 4),
          Text('INPUT', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textTertiary, letterSpacing: 1.5)),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: _buildCompactModeBtn(Icons.camera_alt_rounded, 'CAMERA', _pickFromCamera, false)),
          const SizedBox(width: 6),
          Expanded(child: _buildCompactModeBtn(Icons.photo_library_rounded, 'GALLERY', _pickFromGallery, _pickedImageBytes != null)),
        ]),
      ]),
    );
  }

  Widget _buildCompactModeBtn(IconData icon, String label, VoidCallback onTap, bool isActive) {
    final color = isActive ? AppColors.accentPrimary : AppColors.textTertiary;
    return InkWell(
      onTap: _isPicking ? null : onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.08) : AppColors.bgInput,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          border: Border.all(color: isActive ? color.withOpacity(0.4) : AppColors.borderSubtle, width: 1),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w600, color: color, letterSpacing: 1)),
        ]),
      ),
    );
  }

  // ============================================================
  // METADATA — Reorganized with Dropdown + Free Text
  // ============================================================

  Widget _buildCompactMetadata() {
    final analysisProvider = context.watch<AnalysisProvider>();
    final hasResult = analysisProvider.hasResult;
    final result = analysisProvider.currentResult;

    return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          border: Border.all(color: AppColors.borderSubtle, width: 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Row(children: [
            Icon(Icons.assignment_outlined, size: 15, color: AppColors.info),
            const SizedBox(width: 4),
            Text('METADATA', style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textTertiary, letterSpacing: 1.5)),
          ]),
          const SizedBox(height: 8),

          // ── GROUP 1: Sample Information ──
          _buildMetadataCategoryHeader('SAMPLE INFORMATION', Icons.inventory_2_outlined, AppColors.info, _metadataGroup1Expanded, () => setState(() => _metadataGroup1Expanded = !_metadataGroup1Expanded)),
          if (_metadataGroup1Expanded) ...[
            const SizedBox(height: 5),
            Row(children: [
              Expanded(child: _buildReadOnlyField('Sample ID', _sampleIdController.text, Icons.qr_code_rounded, AppColors.accentPrimary)),
              const SizedBox(width: 4),
              // New Sample button - regenerates Sample ID
              GestureDetector(
                onTap: () => setState(() => _sampleIdController.text = _generateSampleId()),
                child: Container(
                  height: 34,
                  width: 34,
                  decoration: BoxDecoration(
                    color: AppColors.accentPrimary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                    border: Border.all(color: AppColors.accentPrimary.withOpacity(0.3), width: 1),
                  ),
                  child: Tooltip(
                    message: 'Generate new Sample ID',
                    child: Icon(Icons.refresh_rounded, size: 16, color: AppColors.accentPrimary),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(child: _buildDropdownField('Sample Type *', _selectedSampleType, kSampleTypeOptions, Icons.science_outlined, (v) => setState(() => _selectedSampleType = v))),
            ]),
            const SizedBox(height: 5),
            Row(children: [
              Expanded(child: _buildDropdownField('No. Plate *', _selectedPlateReplicate, kPlateReplicateOptions, Icons.layers_outlined, (v) => setState(() => _selectedPlateReplicate = v))),
              const SizedBox(width: 6),
              Expanded(child: _buildDateTimeField('Sampling Time', _samplingTimeController, Icons.schedule_rounded)),
            ]),
            const SizedBox(height: 5),
            Row(children: [
              Expanded(child: _buildFreeTextField('Sampling Point', 'Location...', _samplingLocationController, Icons.location_on_outlined)),
              const SizedBox(width: 6),
              Expanded(child: _buildFreeTextField('Sampling Officer', 'Name...', _samplingOfficerController, Icons.person_outline_rounded)),
            ]),
          ],

          const SizedBox(height: 4),

          // ── GROUP 2: Method & Dilution ──
          _buildMetadataCategoryHeader('METHOD & DILUTION', Icons.science_rounded, AppColors.accentSecondary, _metadataGroup2Expanded, () => setState(() => _metadataGroup2Expanded = !_metadataGroup2Expanded)),
          if (_metadataGroup2Expanded) ...[
            const SizedBox(height: 5),
            Row(children: [
              Expanded(child: _buildDropdownField('Media Type *', _selectedMedia, kMediaOptions, Icons.biotech_rounded, (v) => setState(() => _selectedMedia = v))),
              const SizedBox(width: 6),
              Expanded(child: _buildDropdownField('Inoculation Method *', _selectedInoculationMethod, kInoculationMethodOptions, Icons.call_split_rounded, (v) => setState(() => _selectedInoculationMethod = v))),
            ]),
            const SizedBox(height: 5),
            Row(children: [
              Expanded(child: _buildDropdownField('Dilution Factor *', _selectedDilution, kDilutionOptions, Icons.water_drop_outlined, (v) => setState(() => _selectedDilution = v))),
              const SizedBox(width: 6),
              Expanded(child: _buildDropdownField('Inoculum Volume *', _selectedInoculumVolume, kInoculumVolumeOptions, Icons.precision_manufacturing_rounded, (v) => setState(() => _selectedInoculumVolume = v))),
            ]),
            const SizedBox(height: 5),
            Row(children: [
              Expanded(child: _buildDropdownField('Diluent Solution', _selectedDiluent, kDiluentOptions, Icons.opacity_rounded, (v) => setState(() => _selectedDiluent = v))),
              const Expanded(child: SizedBox()),
            ]),
          ],

          const SizedBox(height: 4),

          // ── GROUP 3: Incubation Parameters ──
          _buildMetadataCategoryHeader('INCUBATION PARAMETERS', Icons.thermostat_rounded, AppColors.warning, _metadataGroup3Expanded, () => setState(() => _metadataGroup3Expanded = !_metadataGroup3Expanded)),
          if (_metadataGroup3Expanded) ...[
            const SizedBox(height: 5),
            Row(children: [
              Expanded(child: _buildDateTimeField('Incubator Entry Time *', _incubatorEntryTimeController, Icons.event_outlined)),
              const SizedBox(width: 6),
              Expanded(child: _buildDropdownField('Incubation Temp *', _selectedIncubatorTemp, kIncubatorTempOptions, Icons.thermostat_rounded, (v) => setState(() => _selectedIncubatorTemp = v))),
            ]),
            const SizedBox(height: 5),
            Row(children: [
              Expanded(child: _buildDropdownField('Incubation Duration *', _selectedIncubationTime, kIncubationTimeOptions, Icons.timer_outlined, (v) => setState(() => _selectedIncubationTime = v))),
              const SizedBox(width: 6),
              Expanded(child: _buildFreeTextField('Incubator ID', 'INK-01', _incubatorIdController, Icons.dns_rounded)),
            ]),
            const SizedBox(height: 5),
            Row(children: [
              Expanded(child: _buildDropdownField('Incubation Condition', _selectedIncubationCondition, kIncubationConditionOptions, Icons.air_rounded, (v) => setState(() => _selectedIncubationCondition = v))),
              const Expanded(child: SizedBox()),
            ]),
          ],

          const SizedBox(height: 4),

          // ── GROUP 4: Additional Info & Results ──
          _buildMetadataCategoryHeader('ADDITIONAL INFO & RESULTS', Icons.summarize_outlined, AppColors.success, _metadataGroup4Expanded, () => setState(() => _metadataGroup4Expanded = !_metadataGroup4Expanded)),
          if (_metadataGroup4Expanded) ...[
            const SizedBox(height: 5),
            Row(children: [
              Expanded(child: _buildFreeTextField('Batch Media / Lot No. *', 'LOT-2024-001', _mediaLotController, Icons.tag_rounded)),
              const SizedBox(width: 6),
              Expanded(child: _buildFreeTextField('Analyst Name *', 'Analyst name...', _analystNameController, Icons.badge_outlined)),
            ]),
            const SizedBox(height: 5),
            Row(children: [
              Expanded(child: _buildFreeTextField('Special Notes', 'Morphology observations...', _morphologyNotesController, Icons.note_alt_outlined)),
              const Expanded(child: SizedBox()),
            ]),
            const SizedBox(height: 8),
            // ── AI-generated results (read-only) ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.accentPrimary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                border: Border.all(color: AppColors.accentPrimary.withOpacity(0.2), width: 1),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.smart_toy_rounded, size: 12, color: AppColors.accentPrimary.withOpacity(0.8)),
                  const SizedBox(width: 4),
                  Text('RESULTS (AI/System Generated)', style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.accentPrimary.withOpacity(0.9), letterSpacing: 1)),
                ]),
                const SizedBox(height: 6),
                _buildResultRow('Colony Count', hasResult ? '${result!.colonyCount} CFU' : '--', AppColors.colonyColor),
                const SizedBox(height: 4),
                _buildResultRow('Validity Status (SNI/ISO)', hasResult ? _getValidityStatus(result!.colonyCount) : '--', _getValidityColor(hasResult ? result!.colonyCount : 0)),
                const SizedBox(height: 4),
                _buildResultRow('Total Concentration', hasResult ? _calculateCFU(result!.colonyCount) : '--', AppColors.success),
              ]),
            ),
          ],
        ]),
    );
  }

  /// Build a read-only result row for AI-generated values
  Widget _buildResultRow(String label, String value, Color valueColor) {
    return Row(children: [
      Expanded(child: Text(label, style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.textMuted, letterSpacing: 0.3))),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: valueColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: valueColor.withOpacity(0.3), width: 0.5),
        ),
        child: Text(value, style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w700, color: valueColor)),
      ),
    ]);
  }

  /// Get validity status based on colony count (SNI/ISO standard)
  String _getValidityStatus(int count) {
    if (count < 30) return 'Too Few (<30)';
    if (count > 300) return 'TNTC (>300)';
    return 'Valid (30-300)';
  }

  /// Get color for validity status
  Color _getValidityColor(int count) {
    if (count < 30) return AppColors.info;
    if (count > 300) return AppColors.error;
    return AppColors.success;
  }

  /// Calculate CFU concentration based on count, dilution, and volume
  String _calculateCFU(int count) {
    if (count < 1) return '0 CFU/mL';
    
    // Parse dilution factor
    double dilutionFactor = 1.0;
    if (_selectedDilution != null) {
      final dilutionStr = _selectedDilution!.replaceAll('10⁰ (tanpa pengenceran)', '1');
      // Parse exponents like 10^-1, 10^-2 etc
      final expMatch = RegExp(r'10[^\d]*(\d+)').firstMatch(dilutionStr);
      if (expMatch != null) {
        final exp = int.tryParse(expMatch.group(1) ?? '0') ?? 0;
        dilutionFactor = pow(10, exp).toDouble();
      }
    }
    
    // Parse volume
    double volume = 0.1; // default 0.1 mL
    if (_selectedInoculumVolume != null) {
      final volMatch = RegExp(r'([\d.]+)').firstMatch(_selectedInoculumVolume!);
      if (volMatch != null) {
        volume = double.tryParse(volMatch.group(1) ?? '0.1') ?? 0.1;
      }
    }
    
    if (volume == 0) return '-- CFU/mL';
    
    final cfu = (count * dilutionFactor / volume);
    if (cfu >= 1000000) return '${(cfu / 1000000).toStringAsFixed(1)} x 10^6 CFU/mL';
    if (cfu >= 1000) return '${(cfu / 1000).toStringAsFixed(1)} x 10^3 CFU/mL';
    return '${cfu.toStringAsFixed(0)} CFU/mL';
  }

    /// Clickable category header — tap to expand/collapse fields
  Widget _buildMetadataCategoryHeader(String label, IconData icon, Color accentColor, bool isExpanded, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: accentColor.withOpacity(0.06),
          borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
          border: Border.all(
            color: isExpanded ? accentColor.withOpacity(0.5) : accentColor.withOpacity(0.15),
            width: isExpanded ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          Icon(icon, size: 13, color: accentColor),
          const SizedBox(width: 6),
          Expanded(child: Text(label, style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.w700, color: accentColor.withOpacity(0.9), letterSpacing: 1.2))),
          Icon(isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 16, color: accentColor.withOpacity(0.6)),
        ]),
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value, IconData icon, Color accentColor) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 11, color: accentColor),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.w500, color: AppColors.textMuted)),
      ]),
      const SizedBox(height: 3),
      Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: accentColor.withOpacity(0.05),
          borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
          border: Border.all(color: accentColor.withOpacity(0.25), width: 1),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(value, style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w600, color: accentColor)),
        ),
      ),
    ]);
  }

  Widget _buildFreeTextField(String label, String hint, TextEditingController? controller, IconData icon) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 11, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.w500, color: AppColors.textMuted)),
      ]),
      const SizedBox(height: 3),
      SizedBox(
        height: 34,
        child: TextField(
          controller: controller,
          style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppColors.textMuted.withOpacity(0.3)),
            filled: true,
            fillColor: AppColors.bgInput,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusXs), borderSide: BorderSide(color: AppColors.borderSubtle, width: 0.5)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusXs), borderSide: BorderSide(color: AppColors.borderSubtle, width: 0.5)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusXs), borderSide: BorderSide(color: AppColors.accentPrimary.withOpacity(0.5), width: 1.0)),
          ),
        ),
      ),
    ]);
  }

  Widget _buildDateTimeField(String label, TextEditingController controller, IconData icon) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 11, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.w500, color: AppColors.textMuted)),
      ]),
      const SizedBox(height: 3),
      GestureDetector(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
            builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(
              colorScheme: ColorScheme.dark(primary: AppColors.accentPrimary, surface: AppColors.bgCard, onSurface: AppColors.textPrimary),
            ), child: child!),
          );
          if (picked != null) {
            final time = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.now(),
              builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(
                colorScheme: ColorScheme.dark(primary: AppColors.accentPrimary, surface: AppColors.bgCard, onSurface: AppColors.textPrimary),
              ), child: child!),
            );
            if (time != null) {
              final dt = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
              controller.text = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
              setState(() {});
            }
          }
        },
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: AppColors.bgInput,
            borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
            border: Border.all(color: AppColors.borderSubtle, width: 0.5),
          ),
          child: Row(children: [
            Expanded(child: Text(
              controller.text.isEmpty ? 'Select date/time' : controller.text,
              style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: controller.text.isEmpty ? FontWeight.w400 : FontWeight.w500, color: controller.text.isEmpty ? AppColors.textMuted.withOpacity(0.4) : AppColors.textPrimary),
              overflow: TextOverflow.ellipsis,
            )),
            Icon(Icons.calendar_today_rounded, size: 13, color: AppColors.textTertiary),
          ]),
        ),
      ),
    ]);
  }

  Widget _buildDropdownField(String label, String? value, List<String> options, IconData icon, ValueChanged<String?> onChanged) {
    final hasValue = value != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 11, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.w500, color: AppColors.textMuted)),
      ]),
      const SizedBox(height: 3),
      PopupMenuButton<String>(
        offset: const Offset(0, 34),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        color: AppColors.bgSecondary,
        constraints: BoxConstraints(maxHeight: 240),
        onSelected: onChanged,
        itemBuilder: (_) => options.map((opt) => PopupMenuItem<String>(
          value: opt,
          height: 32,
          child: Text(
            opt,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              fontWeight: opt == value ? FontWeight.w700 : FontWeight.w400,
              color: opt == value ? AppColors.accentPrimary : AppColors.textSecondary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        )).toList(),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: AppColors.bgInput,
            borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
            border: Border.all(
              color: hasValue ? AppColors.accentPrimary.withOpacity(0.3) : AppColors.borderSubtle,
              width: 1,
            ),
          ),
          child: Row(children: [
            Expanded(
              child: Text(
                hasValue ? value! : 'Select...',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  fontWeight: hasValue ? FontWeight.w500 : FontWeight.w400,
                  color: hasValue ? AppColors.textPrimary : AppColors.textMuted.withOpacity(0.4),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.expand_more_rounded, size: 16, color: AppColors.textTertiary),
          ]),
        ),
      ),
    ]);
  }

  // ============================================================
  // HISTORY
  // ============================================================

  Widget _buildHistorySection(AnalysisProvider ap) {
    final allHistory = ap.history;
    final currentSampleId = _currentSampleId;
    // Filter history by current Sample ID
    final filteredHistory = allHistory.where((r) => r.sampleId == currentSampleId).toList();
    final recentHistory = filteredHistory.length > 10 ? filteredHistory.sublist(filteredHistory.length - 10) : filteredHistory;
    final displayList = recentHistory.reversed.toList();

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.borderSubtle, width: 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.history_rounded, size: 13, color: AppColors.accentSecondary),
          const SizedBox(width: 4),
          Text('HISTORY', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textTertiary, letterSpacing: 1.5)),
          const SizedBox(width: 6),
          // Show Sample ID filter badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(color: AppColors.accentPrimary.withOpacity(0.1), borderRadius: BorderRadius.circular(2)),
            child: Text(currentSampleId, style: GoogleFonts.jetBrainsMono(fontSize: 7, fontWeight: FontWeight.w600, color: AppColors.accentPrimary, letterSpacing: 0.3)),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(color: AppColors.accentPrimary.withOpacity(0.1), borderRadius: BorderRadius.circular(3)),
            child: Text('${filteredHistory.length}', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.accentPrimary)),
          ),
        ]),
        const SizedBox(height: 5),
        if (displayList.isEmpty)
          Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.science_outlined, size: 20, color: AppColors.textMuted.withOpacity(0.4)),
            const SizedBox(height: 4),
            Text('No analysis for this sample', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
          ]))
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: displayList.length,
            separatorBuilder: (_, __) => const SizedBox(height: 3),
            itemBuilder: (ctx, i) => _buildHistoryItem(displayList[i]),
          ),
      ]),
    );
  }

  Widget _buildHistoryItem(AnalysisResult result) {
    final timeStr = _formatTimestamp(result.timestamp);
    final colonyCount = result.colonyCount;
    final total = result.totalDetections;
    final severity = colonyCount > 300 ? 'TNTC' : (colonyCount > 150 ? 'TFTC' : (colonyCount > 30 ? 'IDEAL' : 'LOW'));
    final severityColor = colonyCount > 300 ? AppColors.error : (colonyCount > 150 ? AppColors.warning : (colonyCount > 30 ? AppColors.success : AppColors.info));

    return GestureDetector(
      onTap: () => _showHistoryPopup(result),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.bgInput,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
          border: Border.all(color: AppColors.borderSubtle, width: 0.5),
        ),
        child: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: severityColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: severityColor.withOpacity(0.3), width: 0.5),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('$colonyCount', style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.w800, color: severityColor, height: 1.0)),
              Text('CFU', style: GoogleFonts.jetBrainsMono(fontSize: 5, color: severityColor.withOpacity(0.7), height: 1.0)),
            ]),
          ),
          const SizedBox(width: 6),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(severity, style: GoogleFonts.jetBrainsMono(fontSize: 7, fontWeight: FontWeight.w700, color: severityColor, letterSpacing: 1)),
              const SizedBox(width: 4),
              Text('$total det', style: GoogleFonts.jetBrainsMono(fontSize: 6, color: AppColors.textMuted)),
            ]),
            const SizedBox(height: 2),
            Text(timeStr, style: GoogleFonts.inter(fontSize: 7, color: AppColors.textMuted)),
          ])),
          Icon(Icons.chevron_right_rounded, size: 14, color: AppColors.textMuted),
        ]),
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _showHistoryPopup(AnalysisResult result) {
    final colonyCount = result.colonyCount;
    final severity = colonyCount > 300 ? 'TNTC' : (colonyCount > 150 ? 'TFTC' : (colonyCount > 30 ? 'IDEAL' : 'LOW'));
    final severityColor = colonyCount > 300 ? AppColors.error : (colonyCount > 150 ? AppColors.warning : (colonyCount > 30 ? AppColors.success : AppColors.info));

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.bgScaffold,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.bgSecondary,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
                ),
                child: Row(children: [
                  Icon(Icons.analytics_rounded, size: 18, color: severityColor),
                  const SizedBox(width: 8),
                  Text('ANALYSIS RESULT', style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: 1.5)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(dialogContext).pop(),
                    child: Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(color: AppColors.bgInput, borderRadius: BorderRadius.circular(6)),
                      child: Icon(Icons.close_rounded, size: 16, color: AppColors.textTertiary),
                    ),
                  ),
                ]),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: severityColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: severityColor.withOpacity(0.4)),
                        ),
                        child: Text(severity, style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.w800, color: severityColor, letterSpacing: 2)),
                      ),
                      const SizedBox(width: 12),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('$colonyCount', style: GoogleFonts.jetBrainsMono(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary, height: 1.0)),
                        Text('Colony Count (CFU)', style: GoogleFonts.inter(fontSize: 9, color: AppColors.textMuted)),
                      ]),
                    ]),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.bgCard,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('DETECTION BREAKDOWN', style: GoogleFonts.jetBrainsMono(fontSize: 8, fontWeight: FontWeight.w600, color: AppColors.textTertiary, letterSpacing: 1.5)),
                        const SizedBox(height: 8),
                        _buildPopupCountRow('Colony', result.colonyCount, AppColors.colonyColor),
                        const SizedBox(height: 4),
                        _buildPopupCountRow('Bubble', result.bubbleCount, AppColors.bubbleColor),
                        const SizedBox(height: 4),
                        _buildPopupCountRow('Dust', result.dustCount, AppColors.dustColor),
                        const SizedBox(height: 4),
                        _buildPopupCountRow('Crack', result.crackCount, AppColors.crackColor),
                        const Divider(height: 16, color: AppColors.borderSubtle),
                        _buildPopupCountRow('Total', result.totalDetections, AppColors.textPrimary),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.bgCard,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('DETAILS', style: GoogleFonts.jetBrainsMono(fontSize: 8, fontWeight: FontWeight.w600, color: AppColors.textTertiary, letterSpacing: 1.5)),
                        const SizedBox(height: 8),
                        _buildPopupDetailRow('Time', _formatTimestamp(result.timestamp)),
                        const SizedBox(height: 3),
                        _buildPopupDetailRow('Processing', '${result.processingTime.inMilliseconds} ms'),
                        const SizedBox(height: 3),
                        _buildPopupDetailRow('Image Size', '${result.imageWidth} x ${result.imageHeight}'),
                        const SizedBox(height: 3),
                        _buildPopupDetailRow('Avg Confidence', '${(result.averageConfidence * 100).toStringAsFixed(1)}%'),
                        const SizedBox(height: 3),
                        _buildPopupDetailRow('Model', result.modelVersion),
                      ]),
                    ),
                  ]),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.borderSubtle)),
                ),
                child: Row(children: [
                  Text('ID: ${result.id.substring(0, 8)}', style: GoogleFonts.jetBrainsMono(fontSize: 7, color: AppColors.textMuted)),
                  const Spacer(),
                  SizedBox(
                    height: 32,
                    child: LabButton(
                      label: 'CLOSE',
                      variant: LabButtonVariant.secondary,
                      size: LabButtonSize.sm,
                      icon: Icons.close_rounded,
                      onPressed: () => Navigator.of(dialogContext).pop(),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPopupCountRow(String label, int count, Color color) {
    return Row(children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(label, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSecondary)),
      const Spacer(),
      Text('$count', style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    ]);
  }

  Widget _buildPopupDetailRow(String label, String value) {
    return Row(children: [
      Text(label, style: GoogleFonts.inter(fontSize: 9, color: AppColors.textMuted)),
      const Spacer(),
      Text(value, style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
    ]);
  }
}
