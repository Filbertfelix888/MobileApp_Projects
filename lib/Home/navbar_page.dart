import 'package:flutter/material.dart';

import '../environment_config.dart';
import '../session_manager.dart';
import '../ui/Theme/theme_tonggle.dart'; // Import komponen ThemeToggle

class Navbar extends StatefulWidget implements PreferredSizeWidget {
  const Navbar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(56.0);

  @override
  State<Navbar> createState() => _NavbarState();
}

class _NavbarState extends State<Navbar> {
  String _userName = 'User';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final environment = await EnvironmentConfig.snapshot();
      final session = await SessionManager.getSessionForEnvironment(
        environment.environment,
      );
      if (mounted && session != null && session['user'] != null) {
        setState(() {
          _userName = session['user']['name'] ?? 'User';
        });
      }
    } catch (_) {
      // Keep the default user label when persisted session state is unavailable.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor, width: 1),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Logo and title.
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/PM_Logo.png',
                      width: 32,
                      height: 32,
                      errorBuilder: (context, error, stackTrace) {
                        final colors = Theme.of(context).colorScheme;
                        return Container(
                          width: 32,
                          height: 32,
                          color: colors.surfaceContainerHighest,
                          child: Icon(
                            Icons.business,
                            color: colors.primary,
                            size: 20,
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'PROJECT MANAGEMENT',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Right Actions: Theme Toggle & Profile Menu
              Row(
                children: [
                  const ThemeToggle(), // Pasang Komponen ThemeToggle di sini

                  PopupMenuButton<String>(
                    tooltip: 'Akun dan keluar',
                    icon: Icon(
                      Icons.account_circle,
                      size: 28,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    onSelected: (value) async {
                      if (value == 'logout') {
                        final messenger = ScaffoldMessenger.of(context);
                        final errorColor = Theme.of(context).colorScheme.error;
                        String? failure;
                        try {
                          await EnvironmentConfig.logout();
                        } catch (error) {
                          failure = error.toString().replaceAll(
                            'Exception: ',
                            '',
                          );
                        }
                        if (context.mounted) {
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            '/login',
                            (_) => false,
                          );
                        }
                        if (failure != null) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(failure),
                              backgroundColor: errorColor,
                            ),
                          );
                        }
                      }
                    },
                    itemBuilder: (BuildContext context) {
                      final colors = Theme.of(context).colorScheme;
                      return [
                        PopupMenuItem<String>(
                          value: 'profile',
                          child: Row(
                            children: [
                              const Icon(Icons.person_outline, size: 20),
                              const SizedBox(width: 8),
                              Flexible(child: Text(_userName)),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        PopupMenuItem<String>(
                          value: 'logout',
                          child: Row(
                            children: [
                              Icon(Icons.logout, size: 20, color: colors.error),
                              const SizedBox(width: 8),
                              Text(
                                'Logout',
                                style: TextStyle(color: colors.error),
                              ),
                            ],
                          ),
                        ),
                      ];
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
