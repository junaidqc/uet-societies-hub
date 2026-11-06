import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/uet_card_parser.dart';

class StudentCardScannerSheet extends StatefulWidget {
  final ValueChanged<UetCardData> onCardScanned;

  const StudentCardScannerSheet({
    super.key,
    required this.onCardScanned,
  });

  static Future<void> show({
    required BuildContext context,
    required ValueChanged<UetCardData> onCardScanned,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StudentCardScannerSheet(onCardScanned: onCardScanned),
    );
  }

  @override
  State<StudentCardScannerSheet> createState() => _StudentCardScannerSheetState();
}

class _StudentCardScannerSheetState extends State<StudentCardScannerSheet>
    with SingleTickerProviderStateMixin {
  late MobileScannerController _scannerController;
  late AnimationController _animController;
  late Animation<double> _laserAnimation;

  bool _hasDetected = false;
  bool _isTorchOn = false;
  final TextEditingController _manualController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _laserAnimation = Tween<double>(begin: 0.05, end: 0.95).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _scannerController.dispose();
    _manualController.dispose();
    super.dispose();
  }

  void _processScannedString(String rawString) {
    if (_hasDetected) return;

    final cardData = UetCardParser.parse(rawString);
    if (cardData != null) {
      _hasDetected = true;
      HapticFeedback.mediumImpact();
      widget.onCardScanned(cardData);
      Navigator.of(context).pop();
    }
  }

  void _useSampleCard() {
    final sample = UetCardParser.getSampleCard();
    HapticFeedback.selectionClick();
    widget.onCardScanned(sample);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.badge_rounded, color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Scan UET Student Card',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Point camera at the card barcode or QR',
                          style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 20),

          // Scanner Viewport
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Camera Stream
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    color: Colors.black,
                    child: MobileScanner(
                      controller: _scannerController,
                      errorBuilder: (context, error, child) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.videocam_off_rounded, color: Colors.white70, size: 48),
                                const SizedBox(height: 12),
                                const Text(
                                  'Camera Not Available or Permission Denied',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'You can test with the sample card or enter your roll number manually below.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white70, fontSize: 13),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: _useSampleCard,
                                  icon: const Icon(Icons.flash_on_rounded),
                                  label: const Text('Use Sample Card (2022-CS-101)'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      onDetect: (capture) {
                        for (final barcode in capture.barcodes) {
                          final val = barcode.rawValue;
                          if (val != null && val.isNotEmpty) {
                            _processScannedString(val);
                            break;
                          }
                        }
                      },
                    ),
                  ),
                ),

                // Card Overlay Guides & Laser
                IgnorePointer(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 36),
                    child: AspectRatio(
                      aspectRatio: 1.58, // Standard ID Card Aspect Ratio
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          // Corner Accents
                          Positioned(
                            top: 0,
                            left: 0,
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: const BoxDecoration(
                                border: Border(
                                  top: BorderSide(color: AppColors.primary, width: 4),
                                  left: BorderSide(color: AppColors.primary, width: 4),
                                ),
                                borderRadius: BorderRadius.only(topLeft: Radius.circular(14)),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: const BoxDecoration(
                                border: Border(
                                  top: BorderSide(color: AppColors.primary, width: 4),
                                  right: BorderSide(color: AppColors.primary, width: 4),
                                ),
                                borderRadius: BorderRadius.only(topRight: Radius.circular(14)),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: const BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: AppColors.primary, width: 4),
                                  left: BorderSide(color: AppColors.primary, width: 4),
                                ),
                                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(14)),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: const BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: AppColors.primary, width: 4),
                                  right: BorderSide(color: AppColors.primary, width: 4),
                                ),
                                borderRadius: BorderRadius.only(bottomRight: Radius.circular(14)),
                              ),
                            ),
                          ),

                          // Animated Laser Scanner Line
                          AnimatedBuilder(
                            animation: _laserAnimation,
                            builder: (context, child) {
                              return Align(
                                alignment: Alignment(0, (_laserAnimation.value * 2) - 1),
                                child: Container(
                                  height: 2.5,
                                  margin: const EdgeInsets.symmetric(horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary.withOpacity(0.8),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Viewport Controls (Torch & Flip)
                Positioned(
                  bottom: 24,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(
                            _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            setState(() => _isTorchOn = !_isTorchOn);
                            _scannerController.toggleTorch();
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.flip_camera_android_rounded, color: Colors.white),
                          onPressed: () => _scannerController.switchCamera(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom Action Panel: Manual Input or Quick Demo Card
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Quick Demo button
                OutlinedButton.icon(
                  onPressed: _useSampleCard,
                  icon: const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 18),
                  label: const Text(
                    'Simulate Scanning Sample Card (2022-CS-101)',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary),
                    minimumSize: const Size.fromHeight(42),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 10),

                // Manual barcode / roll number input
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: TextField(
                          controller: _manualController,
                          decoration: InputDecoration(
                            hintText: 'Or enter Roll No (e.g. 2022-CS-101)',
                            hintStyle: const TextStyle(fontSize: 13),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          textCapitalization: TextCapitalization.characters,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        if (_manualController.text.trim().isNotEmpty) {
                          _processScannedString(_manualController.text.trim());
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        minimumSize: const Size(80, 44),
                      ),
                      child: const Text('Auto-Fill'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
