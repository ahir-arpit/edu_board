import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Mock Settings States
  String _selectedLanguage = 'English';
  bool _drawingHaptics = true;
  bool _pushNotifications = true;
  bool _autoSave = true;

  final List<String> _languages = ['English', 'Spanish', 'French', 'German', 'Hindi', 'Mandarin'];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(authServiceProvider).currentUser;
    final currentTheme = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
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
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // 1. Profile Summary Card
            GlassContainer(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.accentBlue.withValues(alpha: 0.15),
                    radius: 32,
                    child: const Icon(Icons.person, size: 36, color: AppTheme.accentBlue),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? "Educator Name",
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user?.email ?? "educator@smartboard.com",
                          style: const TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            "Verified Teacher Account",
                            style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 2. Personalization Settings Group
            _buildSectionHeader("Personalization"),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  // Dark Mode Switch
                  ListTile(
                    leading: const Icon(Icons.dark_mode_outlined),
                    title: const Text("Dark Theme Mode"),
                    subtitle: const Text("Enable dark mode environment"),
                    trailing: Switch(
                      value: currentTheme == ThemeMode.dark,
                      onChanged: (val) {
                        ref.read(themeModeProvider.notifier).state =
                            val ? ThemeMode.dark : ThemeMode.light;
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  // Language selection
                  ListTile(
                    leading: const Icon(Icons.language_outlined),
                    title: const Text("App Language"),
                    subtitle: Text(_selectedLanguage),
                    trailing: DropdownButton<String>(
                      value: _selectedLanguage,
                      underline: const SizedBox(),
                      icon: const Icon(Icons.chevron_right),
                      items: _languages.map((lang) {
                        return DropdownMenuItem<String>(
                          value: lang,
                          child: Text(lang),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedLanguage = val;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 3. Workspace Settings Group
            _buildSectionHeader("Workspace & Styling"),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.touch_app_outlined),
                    title: const Text("Stylus Haptics"),
                    subtitle: const Text("Vibrate slightly during stroke drawing"),
                    trailing: Switch(
                      value: _drawingHaptics,
                      onChanged: (val) => setState(() => _drawingHaptics = val),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.cloud_upload_outlined),
                    title: const Text("Auto Save Notes"),
                    subtitle: const Text("Automatically sync completed paths to cloud database"),
                    trailing: Switch(
                      value: _autoSave,
                      onChanged: (val) => setState(() => _autoSave = val),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 4. Notifications Settings Group
            _buildSectionHeader("Communication"),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.notifications_active_outlined),
                    title: const Text("Push Notifications"),
                    subtitle: const Text("Notify when students join classrooms"),
                    trailing: Switch(
                      value: _pushNotifications,
                      onChanged: (val) => setState(() => _pushNotifications = val),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // 5. Help / Info Section
            Center(
              child: Column(
                children: [
                  const Text(
                    "SmartBoard Go v1.0.0",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Powered by Antigravity AI & Google DeepMind",
                    style: TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      // Launch legal or support dialog
                      showAboutDialog(
                        context: context,
                        applicationName: "SmartBoard Go",
                        applicationVersion: "1.0.0",
                        applicationIcon: const Icon(Icons.gesture_rounded, color: AppTheme.accentBlue),
                        applicationLegalese: "© 2026 Edu Board Corp. All rights reserved.",
                      );
                    },
                    child: const Text("View License & Open Source Libraries"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppTheme.accentBlue.withValues(alpha: 0.8),
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
