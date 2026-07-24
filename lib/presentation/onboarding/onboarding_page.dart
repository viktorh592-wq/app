/// Onboarding — create the single local profile (ADR-001 / Rule 6 — no
/// Firebase Auth). Privacy-first: no account, no server.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:pokatuha/core/errors/app_error.dart';
import 'package:pokatuha/l10n/app_localizations.dart';
import 'package:pokatuha/presentation/app_view_model.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _bio = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await context.read<AppViewModel>().completeOnboarding(
            displayName: _name.text,
            username: _username.text.trim().isEmpty ? null : _username.text,
            bio: _bio.text.trim().isEmpty ? null : _bio.text,
          );
    } on AppError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.directions_bike_rounded,
                      size: 72, color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(l.welcome,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(l.welcomeHint,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _name,
                    decoration: InputDecoration(labelText: l.yourName),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? l.yourName : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _username,
                    decoration: const InputDecoration(
                      labelText: '@username',
                      prefixText: '@',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _bio,
                    decoration: const InputDecoration(labelText: 'Bio'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _saving ? null : _submit,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l.continueButton),
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
