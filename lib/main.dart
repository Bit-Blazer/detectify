import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:camera/camera.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the camera for Windows
  final cameras = await availableCameras();
  final firstCamera = cameras.first;

  runApp(MyApp(camera: firstCamera));
}

class MyApp extends StatelessWidget {
  final CameraDescription camera;

  MyApp({required this.camera});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Detectify',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: DetectifyPage(camera: camera),
    );
  }
}

class DetectifyPage extends StatefulWidget {
  final CameraDescription camera;

  DetectifyPage({required this.camera});

  @override
  _DetectifyPageState createState() => _DetectifyPageState();
}

class _DetectifyPageState extends State<DetectifyPage> {
  late CameraController _cameraController;
  final ImagePicker _picker = ImagePicker();
  File? _videoFile;
  VideoPlayerController? _videoController;
  bool _useCamera = true;
  String? _detectionResults;
  Timer? _frameCaptureTimer;
  Process? _pythonProcess; // Keep a persistent Python process

  @override
  void initState() {
    super.initState();
    _cameraController = CameraController(widget.camera, ResolutionPreset.high);
    _cameraController.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      if (_useCamera) {
        _startPythonProcess(); // Start the Python process here
        _startRealTimeDetection();
      }
    });
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _videoController?.dispose();
    _frameCaptureTimer?.cancel();
    _pythonProcess?.kill(); // Kill the Python process when disposing
    super.dispose();
  }

  Future<void> _startPythonProcess() async {
    // Start the Python process once, keep it running
    String pythonScriptPath =
        'D:/Projects/Hack-o-Holics/detectify_new/detectify/detect_objects.py';
    _pythonProcess = await Process.start('python', [pythonScriptPath]);
    print("called");

    // Listen to the Python process output for results
    _pythonProcess?.stdout.transform(utf8.decoder).listen((output) {
      setState(() {
        _detectionResults = output;
      });
    });

    _pythonProcess?.stderr.transform(utf8.decoder).listen((error) {
      setState(() {
        _detectionResults = 'Error: $error';
      });
    });
  }

  void _startRealTimeDetection() {
    _frameCaptureTimer =
        Timer.periodic(Duration(milliseconds: 500), (timer) async {
      if (_cameraController.value.isInitialized) {
        final image = await _cameraController.takePicture();
        _processFrame(image.path); // Process frame instead of video
      }
    });
  }

  Future<void> _processFrame(String imagePath) async {
    if (_pythonProcess != null) {
      // Send the frame path to the running Python process
      _pythonProcess?.stdin.writeln(imagePath);
      print(imagePath);
    }
  }

  Future<void> _pickPreRecordedVideo() async {
    final pickedFile = await _picker.pickVideo(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _videoFile = File(pickedFile.path);
        _detectionResults = null; // Clear previous results
        _videoController = VideoPlayerController.file(_videoFile!)
          ..initialize().then((_) {
            setState(() {});
          });
      });
      await _processFrame(
          pickedFile.path); // Process video as a series of frames
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detectify: YOLO Detection'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Checkbox(
                    value: _useCamera,
                    onChanged: (value) {
                      setState(() {
                        _useCamera = value ?? true;
                        if (_useCamera) {
                          _startRealTimeDetection();
                        } else {
                          _frameCaptureTimer?.cancel();
                        }
                      });
                    },
                  ),
                  Text('Use Camera'),
                ],
              ),
              if (!_useCamera)
                ElevatedButton(
                  onPressed: _pickPreRecordedVideo,
                  child: Text('Select Video from Gallery'),
                ),
              if (_videoFile != null)
                Column(
                  children: [
                    _videoController != null &&
                            _videoController!.value.isInitialized
                        ? AspectRatio(
                            aspectRatio: _videoController!.value.aspectRatio,
                            child: VideoPlayer(_videoController!),
                          )
                        : Container(height: 200, color: Colors.grey),
                    if (_detectionResults != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: Text(
                          'Detection Results:\n$_detectionResults',
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              if (_useCamera && _cameraController.value.isInitialized)
                SizedBox(
                  height: 300, // Adjust this height as needed
                  child: CameraPreview(_cameraController),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
