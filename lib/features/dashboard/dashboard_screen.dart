import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../core/theme.dart';
import '../../models/board.dart';
import '../../services/auth_service.dart';
import '../../services/board_service.dart';

// Riverpod Provider for tracking active list of boards
final boardsNotifierProvider = StateNotifierProvider<BoardsNotifier, List<Board>>((ref) {
  return BoardsNotifier(ref);
});

class BoardsNotifier extends StateNotifier<List<Board>> {
  final Ref _ref;
  bool _isLoading = false;

  BoardsNotifier(this._ref) : super([]) {
    fetchBoards();
  }

  bool get isLoading => _isLoading;

  Future<void> fetchBoards() async {
    _isLoading = true;
    final auth = _ref.read(authServiceProvider);
    
    // In local sandbox, we will return some sample mock boards if there's no backend connection
    try {
      final boards = await _ref.read(boardServiceProvider).getBoards(auth.currentUser?.id ?? "mock-token");
      state = boards;
    } catch (e) {
      // Fallback sample data for local developer testing
      state = [
        Board(
          id: "board-1",
          title: "Math Class Geometry Notes",
          ownerId: auth.currentUser?.id ?? "mock-user-123",
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
        Board(
          id: "board-2",
          title: "Physics Circuit Diagram",
          ownerId: auth.currentUser?.id ?? "mock-user-123",
          createdAt: DateTime.now().subtract(const Duration(hours: 4)),
        ),
        Board(
          id: "board-3",
          title: "Chemistry Organic Formulas",
          ownerId: auth.currentUser?.id ?? "mock-user-123",
          createdAt: DateTime.now().subtract(const Duration(minutes: 45)),
        ),
      ];
    } finally {
      _isLoading = false;
    }
  }

  Future<void> createNewBoard(String title) async {
    final auth = _ref.read(authServiceProvider);
    try {
      final newBoard = await _ref.read(boardServiceProvider).createBoard(
        title, 
        auth.currentUser?.id ?? "mock-token",
      );
      state = [newBoard, ...state];
    } catch (e) {
      // Fallback mock addition
      final newBoard = Board(
        id: "board-${DateTime.now().millisecondsSinceEpoch}",
        title: title,
        ownerId: auth.currentUser?.id ?? "mock-user-123",
        createdAt: DateTime.now(),
      );
      state = [newBoard, ...state];
    }
  }

  Future<void> deleteBoard(String boardId) async {
    final auth = _ref.read(authServiceProvider);
    try {
      await _ref.read(boardServiceProvider).deleteBoard(boardId, auth.currentUser?.id ?? "mock-token");
      state = state.where((b) => b.id != boardId).toList();
    } catch (e) {
      // Fallback mock deletion
      state = state.where((b) => b.id != boardId).toList();
    }
  }
}

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final _sessionCodeController = TextEditingController();
  final _newBoardTitleController = TextEditingController();
  String _selectedFolder = "All";
  String _searchQuery = "";

  @override
  void dispose() {
    _sessionCodeController.dispose();
    _newBoardTitleController.dispose();
    super.dispose();
  }

  void _showCreateBoardDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Create New Board"),
          content: TextField(
            controller: _newBoardTitleController,
            decoration: const InputDecoration(
              hintText: "Enter board title...",
              labelText: "Board Title",
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                final title = _newBoardTitleController.text.trim();
                if (title.isNotEmpty) {
                  await ref.read(boardsNotifierProvider.notifier).createNewBoard(title);
                  _newBoardTitleController.clear();
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                }
              },
              child: const Text("Create"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleJoinSession() async {
    final code = _sessionCodeController.text.trim().toUpperCase();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid 6-character code")),
      );
      return;
    }

    try {
      // Join pairing session
      final session = await ref.read(boardServiceProvider).joinSession(code);
      if (mounted) {
        context.push('/whiteboard/${session.sessionCode}/student');
      }
    } catch (e) {
      // Fallback: in offline simulation, redirect to whiteboard directly
      debugPrint("API pairing join failed. Booting simulator drawing canvas directly...");
      if (mounted) {
        context.push('/whiteboard/$code/student');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final boards = ref.watch(boardsNotifierProvider);
    final user = ref.watch(authServiceProvider).currentUser;
    final currentTheme = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.gesture_rounded, color: AppTheme.accentBlue),
            SizedBox(width: 8),
            Text("SmartBoard Go"),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(currentTheme == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () {
              ref.read(themeModeProvider.notifier).state =
                  currentTheme == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authServiceProvider).logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Greeting Banner
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.accentBlue.withValues(alpha: 0.2),
                    radius: 28,
                    child: Text(
                      user?.name.substring(0, 1).toUpperCase() ?? "U",
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.accentBlue),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Hello, ${user?.name ?? 'Educator'} 👋",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppTheme.primaryBlue,
                        ),
                      ),
                      Text(
                        "Connect your smartphone to begin writing.",
                        style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black54),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Glassmorphic Quick Action Panels
              LayoutBuilder(
                builder: (context, constraints) {
                  final double cardWidth = constraints.maxWidth > 600 ? (constraints.maxWidth - 24) / 2 : constraints.maxWidth;
                  
                  return Wrap(
                    spacing: 24,
                    runSpacing: 24,
                    children: [
                      // Create Session Card
                      SizedBox(
                        width: cardWidth,
                        child: GlassContainer(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.add_to_queue_rounded, size: 40, color: AppTheme.accentBlue),
                              const SizedBox(height: 16),
                              const Text("Host Whiteboard", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              const Text("Open a blank interactive workspace. Display a QR code to connect your writing pad.", style: TextStyle(fontSize: 13, color: Colors.grey)),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: () => context.push('/pairing'),
                                icon: const Icon(Icons.qr_code_2),
                                label: const Text("Launch Room"),
                                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Join Session Card
                      SizedBox(
                        width: cardWidth,
                        child: GlassContainer(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.phonelink_setup_rounded, size: 40, color: Color(0xFF0D9488)),
                              const SizedBox(height: 16),
                              const Text("Connect as Controller", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              const Text("Enter the session code shown on your laptop screen to transform your phone into a writing pad.", style: TextStyle(fontSize: 13, color: Colors.grey)),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _sessionCodeController,
                                      decoration: InputDecoration(
                                        hintText: "SESSION CODE (e.g. ABCXYZ)",
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      ),
                                      textCapitalization: TextCapitalization.characters,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  ElevatedButton(
                                    onPressed: _handleJoinSession,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0D9488),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    ),
                                    child: const Icon(Icons.arrow_forward),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 40),

              // Recent Boards Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Recent Workspaces",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppTheme.primaryBlue,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _showCreateBoardDialog,
                    icon: const Icon(Icons.add),
                    label: const Text("New Board"),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Search Bar input
              TextField(
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
                decoration: InputDecoration(
                  hintText: "Search boards by title...",
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),

              // Folder chips row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ["All", "Maths", "Physics", "Chemistry", "Drafts"].map((folder) {
                    final isSelected = _selectedFolder == folder;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: FilterChip(
                        selected: isSelected,
                        label: Text(folder, style: TextStyle(fontSize: 12, color: isSelected ? AppTheme.accentBlue : null)),
                        onSelected: (val) {
                          setState(() {
                            _selectedFolder = folder;
                          });
                        },
                        selectedColor: AppTheme.accentBlue.withValues(alpha: 0.12),
                        checkmarkColor: AppTheme.accentBlue,
                        backgroundColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              Builder(
                builder: (context) {
                  final filteredBoards = boards.where((b) {
                    final matchesSearch = b.title.toLowerCase().contains(_searchQuery.toLowerCase());
                    if (_selectedFolder == "All") return matchesSearch;
                    if (_selectedFolder == "Maths") return matchesSearch && (b.title.toLowerCase().contains("math") || b.id == "board-1");
                    if (_selectedFolder == "Physics") return matchesSearch && (b.title.toLowerCase().contains("physics") || b.id == "board-2");
                    if (_selectedFolder == "Chemistry") return matchesSearch && (b.title.toLowerCase().contains("chem") || b.id == "board-3");
                    return matchesSearch;
                  }).toList();

                  if (filteredBoards.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40.0),
                        child: Column(
                          children: [
                            const Icon(Icons.folder_open_outlined, size: 64, color: Colors.grey),
                            const SizedBox(height: 12),
                            const Text("No matching workspaces found."),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredBoards.length,
                    itemBuilder: (context, index) {
                      final board = filteredBoards[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.accentBlue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.draw, color: AppTheme.accentBlue),
                          ),
                          title: Text(board.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("Created: ${board.createdAt.toLocal().toString().substring(0, 16)}"),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.open_in_new),
                                onPressed: () {
                                  context.push('/whiteboard/${board.id}/teacher');
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                onPressed: () => ref.read(boardsNotifierProvider.notifier).deleteBoard(board.id),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }
              ),
            ],
          ),
        ),
      ),
    );
  }
}
