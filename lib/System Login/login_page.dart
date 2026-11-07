import 'package:flutter/material.dart';
import '../environment_config.dart';
import '../network.dart';
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  int _requestId = 0;

  final RegExp _emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

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
          EnvironmentConfig.generation == environment.generation) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login Berhasil!')),
        );
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
            backgroundColor: Colors.red,
          ),
        );
        if (sessionPersistenceAttempted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/login',
            (_) => false,
          );
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
            backgroundColor: Colors.red,
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
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                       const Text(
                        'Masuk',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          
                        ),
                      ),
                      const SizedBox(height: 16),
                      ValueListenableBuilder<bool>(
                        valueListenable: EnvironmentConfig.switching,
                        builder: (context, switching, child) {
                          return ValueListenableBuilder<BackendEnvironment>(
                            valueListenable: EnvironmentConfig.selected,
                            builder: (context, environment, child) {
                              return DropdownButtonFormField<BackendEnvironment>(
                                key: ValueKey(
                                  '${environment.name}:${EnvironmentConfig.generation}:$switching',
                                ),
                                initialValue: environment,
                                decoration: const InputDecoration(
                                  labelText: 'Environment',
                                  border: OutlineInputBorder(),
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
                                        if (value != null) _selectEnvironment(value);
                                      },
                              );
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Email harus di isi';
                          if (!_emailRegExp.hasMatch(value)) return 'Format email tidak valid';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Password harus di isi';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      ValueListenableBuilder<bool>(
                        valueListenable: EnvironmentConfig.switching,
                        builder: (context, switching, child) {
                          return SizedBox(
                            width: double.infinity,
                            height: 42,
                            child: ElevatedButton(
                              onPressed: _isLoading || switching ? null : _onSubmit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1976D2),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Masuk ke akun Anda',
                                      style: TextStyle(
                                        color: Colors.white,
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
                                  : () => Navigator.pushNamed(context, '/signup'),
                              child: const Text('Daftar baru', style: TextStyle(color: Color(0xFF1976D2))),
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
    );
  }
}