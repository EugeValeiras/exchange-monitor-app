import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/services/api_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/passkey_service.dart';
import '../../../core/theme/em_tokens.dart';
import '../../../shared/widgets/logo_loader.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _error = null);

    try {
      await context.read<AuthService>().login(
            _emailController.text.trim(),
            _passwordController.text,
          );
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'No se pudo iniciar sesión');
    }
  }

  Future<void> _handlePasskeyLogin() async {
    setState(() => _error = null);

    final passkeyService = context.read<PasskeyService>();
    final tokenResponse = await passkeyService.authenticateWithPasskey();

    if (tokenResponse != null) {
      try {
        if (!mounted) return;
        await context.read<AuthService>().loginWithPasskey(tokenResponse);
      } catch (e) {
        setState(() => _error = 'No se pudo iniciar sesión con la passkey');
      }
    } else {
      setState(() => _error = passkeyService.error ?? 'No se pudo autenticar');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(EmSpace.xl),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const LogoLoader(size: 96, showText: false, float: false),
                  const SizedBox(height: EmSpace.xxl),
                  Text(
                    'Exchange Monitor',
                    style: EmText.displaySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: EmSpace.sm),
                  Text(
                    'Iniciá sesión para ver tu posición',
                    style: EmText.body.copyWith(color: EmColors.textTertiary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: EmSpace.xxl + EmSpace.sm),

                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(EmSpace.md),
                      decoration: BoxDecoration(
                        color: EmColors.wash(EmColors.down),
                        borderRadius: BorderRadius.circular(EmRadii.control),
                        border: Border.all(
                          color: EmColors.down.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: EmColors.down, size: 18),
                          const SizedBox(width: EmSpace.sm),
                          Expanded(
                            child: Text(
                              _error!,
                              style: EmText.label.copyWith(color: EmColors.down),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: EmSpace.lg),
                  ],

                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    style: EmText.body,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.alternate_email, size: 19),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Ingresá tu email';
                      }
                      if (!value.contains('@')) {
                        return 'Ese email no parece válido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: EmSpace.md),

                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: EmText.body,
                    onFieldSubmitted: (_) => _handleLogin(),
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock_outline, size: 19),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 19,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Ingresá tu contraseña';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: EmSpace.xl),

                  ElevatedButton(
                    onPressed: authService.isLoading ? null : _handleLogin,
                    child: authService.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: EmColors.bg,
                            ),
                          )
                        : const Text('Iniciar sesión'),
                  ),

                  Consumer<PasskeyService>(
                    builder: (context, passkeyService, _) {
                      if (!passkeyService.isSupported) {
                        return const SizedBox.shrink();
                      }

                      return Column(
                        children: [
                          const SizedBox(height: EmSpace.lg),
                          Row(
                            children: [
                              const Expanded(
                                child: Divider(color: EmColors.stroke),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: EmSpace.lg,
                                ),
                                child: Text(
                                  'o',
                                  style: EmText.meta.copyWith(
                                    color: EmColors.textMuted,
                                  ),
                                ),
                              ),
                              const Expanded(
                                child: Divider(color: EmColors.stroke),
                              ),
                            ],
                          ),
                          const SizedBox(height: EmSpace.lg),
                          OutlinedButton.icon(
                            onPressed:
                                (authService.isLoading || passkeyService.isLoading)
                                    ? null
                                    : _handlePasskeyLogin,
                            icon: passkeyService.isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child:
                                        CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.fingerprint, size: 20),
                            label: Text(
                              passkeyService.isLoading
                                  ? 'Autenticando…'
                                  : 'Entrar con passkey',
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
