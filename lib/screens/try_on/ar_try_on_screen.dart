import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:path_provider/path_provider.dart';

import '../../config/colors.dart';
import '../../widgets/app_image.dart';

/// شاشة التجربة الافتراضية بالواقع المعزز (AR Try-On)
class ArTryOnScreen extends StatefulWidget {
  final String productId;
  final String productName;
  final String? productImage;
  final String categoryId; // thobes, bisht, shemagh, etc.

  const ArTryOnScreen({
    super.key,
    required this.productId,
    required this.productName,
    this.productImage,
    required this.categoryId,
  });

  @override
  State<ArTryOnScreen> createState() => _ArTryOnScreenState();
}

class _ArTryOnScreenState extends State<ArTryOnScreen> {
  // Camera
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isFrontCamera = true;

  // Pose Detection
  PoseDetector? _poseDetector;
  bool _isDetecting = false;
  Pose? _latestPose;

  // Overlay state
  double _overlayOpacity = 0.85;
  double _overlayScale = 1.0;
  Offset _overlayOffset = Offset.zero;
  bool _showInstructions = true;

  // Image for try-on
  ui.Image? _productImage;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // Load product image
      if (widget.productImage != null && widget.productImage!.isNotEmpty) {
        await _loadProductImage(widget.productImage!);
      }

      // Initialize pose detector
      _poseDetector = PoseDetector(
        options: PoseDetectorOptions(
          mode: PoseDetectionMode.stream,
          model: PoseDetectionModel.base,
        ),
      );

      // Initialize camera
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        await _initCamera();
      }
    } catch (e) {
      debugPrint('AR Try-On initialization error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تهيئة الكاميرا: $e'),
              backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _loadProductImage(String url) async {
    try {
      final byteData = await NetworkAssetBundle(Uri.parse(url)).load('');
      final codec = await ui.instantiateImageCodec(byteData.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      setState(() => _productImage = frame.image);
    } catch (e) {
      debugPrint('Error loading product image for try-on: $e');
    }
  }

  Future<void> _initCamera() async {
    if (_cameras == null || _cameras!.isEmpty) return;

    final camera = _isFrontCamera
        ? _cameras!.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.front,
            orElse: () => _cameras!.first)
        : _cameras!.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.back,
            orElse: () => _cameras!.first);

    _cameraController?.dispose();
    _cameraController = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    try {
      await _cameraController!.initialize();
      await _cameraController!.startImageStream(_processImage);
      if (mounted) setState(() => _isCameraInitialized = true);
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  Future<void> _processImage(CameraImage image) async {
    if (_isDetecting || _poseDetector == null) return;
    _isDetecting = true;

    try {
      final inputImage = _buildInputImage(image);
      if (inputImage == null) return;

      final poses = await _poseDetector!.detect(inputImage);
      if (poses.isNotEmpty && mounted) {
        setState(() {
          _latestPose = poses.first;
          _showInstructions = false;
        });
      }
    } catch (e) {
      debugPrint('Pose detection error: $e');
    } finally {
      _isDetecting = false;
    }
  }

  InputImage? _buildInputImage(CameraImage image) {
    final camera = _cameraController?.description;
    if (camera == null) return null;

    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isAndroid) {
      rotation = InputImageRotation.values.firstWhere(
        (r) => r.rawValue == sensorOrientation,
        orElse: () => InputImageRotation.rotation0deg,
      );
    } else {
      rotation = InputImageRotation.rotation0deg;
    }

    final format = Platform.isAndroid
        ? InputImageFormat.nv21
        : InputImageFormat.bgra8888;

    final planeData = image.planes.map(
      (plane) => InputImagePlaneMetadata(
        bytesPerRow: plane.bytesPerRow,
        height: plane.height,
        width: plane.width,
      ),
    ).toList();

    final inputImageData = InputImageData(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      imageRotation: rotation,
      inputImageFormat: format,
      planeData: planeData,
    );

    final bytes = image.planes.first.bytes;
    return InputImage.fromBytes(bytes: bytes, inputImageData: inputImageData);
  }

  @override
  void dispose() {
    _poseDetector?.close();
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    super.dispose();
  }

  void _toggleCamera() {
    setState(() {
      _isFrontCamera = !_isFrontCamera;
      _latestPose = null;
      _isCameraInitialized = false;
    });
    _initCamera();
  }

  Future<void> _takeSnapshot() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    try {
      final xFile = await _cameraController!.takePicture();
      final dir = await getTemporaryDirectory();
      final savedPath = '${dir.path}/try_on_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(xFile.path).copy(savedPath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('تم حفظ الصورة ✓'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Snapshot error: $e');
    }
  }

  /// حساب موضع وعرض الملابس بناءً على نقاط الجسم
  Rect? _calculateGarmentBounds(Pose pose) {
    final landmarks = pose.landmarks;

    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];
    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final rightHip = landmarks[PoseLandmarkType.rightHip];

    if (leftShoulder == null || rightShoulder == null) {
      // لا توجد أكتاف مكتشفة
      if (widget.categoryId == 'shemagh') {
        // للشماغ، نستخدم الأنف كمرجع
        final nose = landmarks[PoseLandmarkType.nose];
        if (nose != null) {
          return Rect.fromLTWH(
            nose.x - 60, nose.y - 100,
            120, 100,
          );
        }
      }
      return null;
    }

    final shoulderY = (leftShoulder.y + rightShoulder.y) / 2;
    final shoulderWidth = (rightShoulder.x - leftShoulder.x).abs();

    if (widget.categoryId == 'shemagh') {
      // الشماغ: يغطي الرأس (فوق الكتفين)
      return Rect.fromLTWH(
        leftShoulder.x - shoulderWidth * 0.1,
        shoulderY - shoulderWidth * 1.1,
        shoulderWidth * 1.2,
        shoulderWidth * 0.9,
      );
    }

    // ثوب / مشلح / بنطلون
    double bottomY;
    double topY = shoulderY - shoulderWidth * 0.1;

    if (widget.categoryId == 'thobes') {
      // الثوب: من الكتفين إلى الكاحل
      bottomY = shoulderY + shoulderWidth * 1.8;
    } else if (widget.categoryId == 'bisht') {
      // المشلح: من الكتفين إلى منتصف الفخذ
      bottomY = shoulderY + shoulderWidth * 1.0;
    } else {
      // بنطلونات: من الوسط إلى الكاحل
      final lHip = leftHip?.y ?? shoulderY + shoulderWidth * 0.6;
      bottomY = lHip + shoulderWidth * 1.2;
      topY = lHip - shoulderWidth * 0.1;
    }

    final centerX = (leftShoulder.x + rightShoulder.x) / 2;
    final garmentWidth = shoulderWidth * 1.4;
    final garmentHeight = bottomY - topY;

    return Rect.fromLTWH(
      centerX - garmentWidth / 2,
      topY,
      garmentWidth,
      garmentHeight,
    );
  }

  /// تحويل إحداثيات الصورة إلى إحداثيات الشاشة
  Offset _imageToScreen(double x, double y, Size screenSize, Size imageSize) {
    // معكوس للكاميرا الأمامية (selfie mirror)
    final mirror = _isFrontCamera;
    final scaleX = screenSize.width / imageSize.width;
    final scaleY = screenSize.height / imageSize.height;
    return Offset(
      mirror ? screenSize.width - x * scaleX : x * scaleX,
      y * scaleY,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black87,
          foregroundColor: Colors.white,
          title: Text(widget.productName),
          centerTitle: true,
          actions: [
            // زر حفظ الصورة
            IconButton(
              icon: const Icon(Icons.camera_alt_outlined),
              onPressed: _takeSnapshot,
              tooltip: 'التقاط صورة',
            ),
          ],
        ),
        body: Stack(
          children: [
            // طبقة الكاميرا
            if (_isCameraInitialized && _cameraController != null)
              SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: _cameraController!.buildPreview(),
              )
            else
              const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text('جاري تهيئة الكاميرا...',
                        style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),

            // طبقة الملابس الافتراضية
            if (_isCameraInitialized && _productImage != null && _latestPose != null)
              LayoutBuilder(
                builder: (context, constraints) {
                  final screenSize = Size(constraints.maxWidth, constraints.maxHeight);
                  final cameraSize = Size(
                    _cameraController!.value.previewSize!.height,
                    _cameraController!.value.previewSize!.width,
                  );

                  final bounds = _calculateGarmentBounds(_latestPose!);
                  if (bounds == null) return const SizedBox.shrink();

                  final topLeft = _imageToScreen(bounds.left, bounds.top, screenSize, cameraSize);
                  final bottomRight = _imageToScreen(bounds.right, bounds.bottom, screenSize, cameraSize);

                  final overlayWidth = (bottomRight.dx - topLeft.dx).abs() * _overlayScale;
                  final overlayHeight = (bottomRight.dy - topLeft.dy).abs() * _overlayScale;
                  final centerX = (topLeft.dx + bottomRight.dx) / 2 + _overlayOffset.dx;
                  final centerY = (topLeft.dy + bottomRight.dy) / 2 + _overlayOffset.dy;

                  return Positioned(
                    left: centerX - overlayWidth / 2,
                    top: centerY - overlayHeight / 2,
                    child: GestureDetector(
                      onPanUpdate: (details) {
                        setState(() {
                          _overlayOffset += details.delta;
                        });
                      },
                      child: Opacity(
                        opacity: _overlayOpacity,
                        child: SizedBox(
                          width: overlayWidth,
                          height: overlayHeight,
                          child: RawImage(
                            image: _productImage,
                            fit: BoxFit.fill,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

            // تعليمات البداية
            if (_showInstructions)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.accessibility_new, size: 64, color: Colors.white70),
                      SizedBox(height: 16),
                      Text(
                        'قف أمام الكاميرا لرؤية\nالمنتج عليك مباشرة',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          height: 1.5,
                        ),
                      ),
                      SizedBox(height: 24),
                      Icon(Icons.swap_camera_rounded, size: 36, color: Colors.white54),
                      SizedBox(height: 8),
                      Text(
                        'اضغط لتبديل الكاميرا',
                        style: TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),

            // التحكم في الشفافية
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: _buildControls(),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _toggleCamera,
          backgroundColor: AppColors.primary,
          child: const Icon(Icons.flip_camera_android, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.opacity, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white30,
                    thumbColor: Colors.white,
                    overlayColor: Colors.white24,
                  ),
                  child: Slider(
                    value: _overlayOpacity,
                    min: 0.2,
                    max: 1.0,
                    onChanged: (v) => setState(() => _overlayOpacity = v),
                  ),
                ),
              ),
              Text(
                '${(_overlayOpacity * 100).toInt()}%',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          Row(
            children: [
              const Icon(Icons.zoom_out_map, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white30,
                    thumbColor: Colors.white,
                    overlayColor: Colors.white24,
                  ),
                  child: Slider(
                    value: _overlayScale,
                    min: 0.5,
                    max: 1.5,
                    onChanged: (v) => setState(() => _overlayScale = v),
                  ),
                ),
              ),
              Text(
                '${(_overlayScale * 100).toInt()}%',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
