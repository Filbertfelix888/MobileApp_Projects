import 'package:flutter/material.dart';

import '../environment_config.dart';
import '../network.dart';
import 'email_validation.dart';
import '../ui/Theme/theme_tonggle.dart';

class LoginPage extends StatefulWidget {
  /// The academic demo always uses QA, so the DEV/QA selector is hidden by
  /// default. The selector and its switching logic stay compiled and testable.
  const LoginPage({super.key, this.showEnvironmentSelector = false});

  final bool showEnvironmentSelector;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _sessionWarning;
  bool _sessionWarningRead = false;
  int _requestId = 0;

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final requestId = ++_requestId;
    bool sessionPersistenceAttempted = false;
    int? requestGeneration;
    setState(() => _isLoading = true);

    try {
      final environment = await EnvironmentConfig.snapshot();
      if (!mounted || requestId != _requestId) return;
      requestGeneration = environment.generation;
      final payload = {
        'email': _emailController.text,
        'password': _passwordController.text,
      };

      final response = await AuthService.login(
        payload,
        environmentSnapshot: environment,
      );

      if (requestId != _requestId ||
          EnvironmentConfig.generation != environment.generation) {
        return;
      }
      final data = response is Map ? response['data'] : null;
      if (data is! Map<String, dynamic> ||
          data['access_token'] is! String ||
          (data['access_token'] as String).isEmpty) {
        throw StateError('Login response did not contain a valid access token');
      }
      sessionPersistenceAttempted = true;
      final saved = await EnvironmentConfig.saveSessionIfCurrent(
        environment.generation,
        environment.environment,
        data,
      );
      if (!saved) return;

      if (mounted &&
          requestId == _requestId &&
          EnvironmentConfig.generation == environment.generation + 1 &&
          EnvironmentConfig.selected.value.name == environment.environment) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Login Berhasil!')));
        Navigator.pushReplacementNamed(context, '/');
      }
    } catch (error) {
      if (mounted &&
          requestId == _requestId &&
          (requestGeneration == null ||
              requestGeneration == EnvironmentConfig.generation)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceAll('Exception: ', '')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        if (sessionPersistenceAttempted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
        }
      }
    } finally {
      if (mounted && requestId == _requestId) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectEnvironment(BackendEnvironment environment) async {
    final previousGeneration = EnvironmentConfig.generation;
    if (EnvironmentConfig.selected.value == environment) return;
    ++_requestId;
    setState(() => _isLoading = false);
    try {
      await EnvironmentConfig.select(environment);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceAll('Exception: ', '')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted &&
          EnvironmentConfig.generation != previousGeneration &&
          Navigator.of(context).canPop()) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_sessionWarningRead) {
      _sessionWarning = ModalRoute.of(context)?.settings.arguments as String?;
      _sessionWarningRead = true;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isWide = MediaQuery.sizeOf(context).width >= 600;
    return Scaffold(
      body: Stack(
        alignment: Alignment.topRight,
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Card(
                  color: isWide
                      ? colorScheme.surface
                      : Theme.of(context).scaffoldBackgroundColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    side: isWide
                        ? BorderSide(color: colorScheme.outlineVariant)
                        : BorderSide.none,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Masuk',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          if (_sessionWarning != null)
                            MaterialBanner(
                              content: Text(_sessionWarning!),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      setState(() => _sessionWarning = null),
                                  child: const Text('OK'),
                                ),
                              ],
                            ),
                          const SizedBox(height: 16),
                          if (widget.showEnvironmentSelector) ...[
                            ValueListenableBuilder<bool>(
                              valueListenable: EnvironmentConfig.switching,
                              builder: (context, switching, child) {
                                return ValueListenableBuilder<
                                  BackendEnvironment
                                >(
                                  valueListenable: EnvironmentConfig.selected,
                                  builder: (context, environment, child) {
                                    return DropdownButtonFormField<
                                      BackendEnvironment
                                    >(
                                      key: ValueKey(
                                        '${environment.name}:${EnvironmentConfig.generation}:$switching',
                                      ),
                                      initialValue: environment,
                                      decoration: InputDecoration(
                                        labelText: 'Environment',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                          value: BackendEnvironment.qa,
                                          child: Text('QA'),
                                        ),
                                        DropdownMenuItem(
                                          value: BackendEnvironment.dev,
                                          child: Text('DEV'),
                                        ),
                                      ],
                                      onChanged: switching
                                          ? null
                                          : (value) {
                                              if (value != null) {
                                                _selectEnvironment(value);
                                              }
                                            },
                                    );
                                  },
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                          ],
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Email harus di isi';
                              }
                              if (!isValidEmailAddress(value)) {
                                return 'Format email tidak valid';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                              suffixIcon: IconButton(
                                tooltip: _obscurePassword
                                    ? 'Tampilkan password'
                                    : 'Sembunyikan password',
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Password harus di isi';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          ValueListenableBuilder<bool>(
                            valueListenable: EnvironmentConfig.switching,
                            builder: (context, switching, child) {
                              return SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: _isLoading || switching
                                      ? null
                                      : _onSubmit,
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size.fromHeight(48),
                                  ),
                                  child: _isLoading
                                      ? SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: colorScheme.onPrimary,
                                          ),
                                        )
                                      : const Text(
                                          'Masuk ke akun Anda',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          ValueListenableBuilder<bool>(
                            valueListenable: EnvironmentConfig.switching,
                            builder: (context, switching, child) {
                              return SizedBox(
                                width: double.infinity,
                                child: TextButton(
                                  onPressed: _isLoading || switching
                                      ? null
                                      : () => Navigator.pushNamed(
                                          context,
                                          '/signup',
                                        ),
                                  style: TextButton.styleFrom(
                                    foregroundColor: colorScheme.primary,
                                  ),
                                  child: const Text('Daftar baru'),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 8, right: 8),
              child: const ThemeToggle(),
            ),
          ),
        ],
      ),
    );
  }
}
