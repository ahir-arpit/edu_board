import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../services/auth_service.dart';
import '../../services/board_service.dart';

class PairingScreen extends ConsumerStatefulWidget {
  const PairingScreen({super.key});

  @override
  ConsumerState<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends ConsumerState<PairingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Host State
  bool _isGenerating = false;
  String? _sessionCode;
  String? _boardId;
  WebSocketChannel? _hostChannel;
  
  // Scanner State
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isScanning = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scannerController.dispose();
    _hostChannel?.sink.close();
    super.dispose();
  }

  // Generate pairing session code (Host Mode)
  Future<void> _generateHostSession() async {
    setState(() {
      _isGenerating = true;
      _sessionCode = null;
    });

    try {
      final auth = ref.read(authServiceProvider);
      final boardService = ref.read(boardServiceProvider);
      
      // 1. Create a default board for this session
      final board = await boardService.createBoard(
        "Lecture Whiteboard - ${DateTime.now().hour}:${DateTime.now().minute}", 
        auth.currentUser?.id ?? "mock-token"
      );
      _boardId = board.id;

      // 2. Request a pairing session code
      final session = await boardService.createSession(board.id, auth.currentUser?.id ?? "mock-token");
      
      setState(() {
        _sessionCode = session.sessionCode;
        _isGenerating = false;
      });

      // 3. Connect Host to WebSocket to listen for the controller joining
      _connectHostSocket(session.sessionCode);
    } catch (e) {
      // Fallback offline simulator session
      setState(() {
        _sessionCode = "SIMUL8";
        _boardId = "mock-board-id";
        _isGenerating = false;
      });
      _connectHostSocket("SIMUL8");
    }
  }

  void _connectHostSocket(String code) {
    _hostChannel?.sink.close();
    final uri = Uri.parse(AppConstants.wsUrl(code));
    
    try {
      _hostChannel = WebSocketChannel.connect(uri);
      _hostChannel!.stream.listen((message) {
        final data = json.decode(message);
        // If we receive a pairing sync event or any drawing event, it means a controller has connected!
        if (data['event'] == 'draw_stroke' || data['event'] == 'draw_shape' || data['event'] == 'sync_history') {
          // Controller connected! Automatically route to Whiteboard view
          if (mounted) {
            context.go('/whiteboard/$code/student'); // Host is the viewer/display (student/audience mode)
          }
        }
      }, onError: (err) {
        debugPrint("Host socket error: $err");
      });
    } catch (e) {
      debugPrint("Could not open host listening channel: $e");
    }
  }

  // Scan QR callback (Controller Mode)
  void _onDetect(BarcodeCapture capture) async {
    if (!_isScanning) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
      final String code = barcodes.first.rawValue!;
      setState(() {
        _isScanning = false;
      });
      
      _joinWithCode(code);
    }
  }

  Future<void> _joinWithCode(String rawCode) async {
    String code = rawCode;
    if (rawCode.contains('|')) {
      final parts = rawCode.split('|');
      final host = parts[0];
      code = parts[1];
      if (host.isNotEmpty && host != "localhost") {
        AppConstants.serverHost = host;
        debugPrint("Dynamically updating AppConstants.serverHost to: $host");
      }
    }

    try {
      final boardService = ref.read(boardServiceProvider);
      final session = await boardService.joinSession(code);
      if (mounted) {
        context.go('/whiteboard/${session.sessionCode}/teacher'); // Phone joins as teacher/controller
      }
    } catch (e) {
      // Offline fallback: connect directly
      if (mounted) {
        context.go('/whiteboard/$code/teacher');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Device Pairing"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.computer), text: "Host Screen"),
            Tab(icon: Icon(Icons.qr_code_scanner), text: "Pair Writing Pad"),
          ],
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [AppTheme.darkBlueBg, const Color(0xFF020617)]
                : [AppTheme.lightBlue, Colors.white],
          ),
        ),
        child: TabBarView(
          controller: _tabController,
          children: [
            // Tab 1: Host Mode (Laptop/Web View)
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: 440,
                  child: GlassContainer(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.tv_rounded, size: 54, color: AppTheme.accentBlue),
                        const SizedBox(height: 16),
                        const Text(
                          "Host Classroom Whiteboard",
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "Show this screen to your students or scan it with your smartphone controller to write from anywhere.",
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        if (_isGenerating)
                          const CircularProgressIndicator()
                        else if (_sessionCode == null)
                          ElevatedButton.icon(
                            onPressed: _generateHostSession,
                            icon: const Icon(Icons.power_rounded),
                            label: const Text("Generate Session Code"),
                          )
                        else ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.accentBlue.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.accentBlue.withOpacity(0.2)),
                            ),
                            child: QrImageView(
                              data: kIsWeb ? "${Uri.base.host}|$_sessionCode" : "localhost|$_sessionCode",
                              version: QrVersions.auto,
                              size: 200.0,
                              eyeStyle: QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: isDark ? Colors.white : AppTheme.primaryBlue,
                              ),
                              dataModuleStyle: QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.circle,
                                color: isDark ? Colors.white : AppTheme.primaryBlue,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text("SESSION PIN", style: TextStyle(fontSize: 12, letterSpacing: 1.5, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text(
                            _sessionCode!,
                            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: 4, color: AppTheme.accentBlue),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "Waiting for device to pair...",
                            style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              if (_sessionCode != null) {
                                // Jump directly to board if testing standalone
                                context.go('/whiteboard/$_sessionCode/student');
                              }
                            },
                            child: const Text("Skip & Open Whiteboard Canvas"),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            
            // Tab 2: Controller Mode (Phone QR Scanner)
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: 440,
                  child: GlassContainer(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.camera_alt_outlined, size: 48, color: Color(0xFF0D9488)),
                        const SizedBox(height: 16),
                        const Text(
                          "Scan Whiteboard QR Code",
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "Hold your phone camera over the QR code generated on the host laptop screen.",
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        
                        // Scanner preview bounding box
                        Container(
                          height: 250,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.black12,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.withOpacity(0.3)),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            children: [
                              MobileScanner(
                                controller: _scannerController,
                                onDetect: _onDetect,
                              ),
                              // Centered camera overlay target box
                              Center(
                                child: Container(
                                  width: 160,
                                  height: 160,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.greenAccent, width: 3),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {
                                _scannerController.toggleTorch();
                              },
                              icon: const Icon(Icons.flash_on),
                              label: const Text("Flash"),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _isScanning = true;
                                });
                                _scannerController.start();
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text("Retry"),
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
