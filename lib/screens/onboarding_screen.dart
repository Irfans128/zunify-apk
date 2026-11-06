import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/library_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/liquid_background_widget.dart';
import '../widgets/vinyl_disc_widget.dart';

/// First-Time Welcome & Local Account Login Screen
/// Shown when the user opens Zunify for the first time to enter their name.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final TextEditingController _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submitName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    await context.read<LibraryProvider>().completeOnboarding(name);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final accent = theme.accentColor;

    return Scaffold(
      backgroundColor: theme.scaffoldBgColor,
      body: LiquidBackgroundWidget(
        primaryColor: accent,
        secondaryColor: theme.secondaryAccentColor,
        baseColor: theme.scaffoldBgColor,
        intensity: 0.48,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 132,
                    height: 132,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(34),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withOpacity(0.42),
                          blurRadius: 34,
                          spreadRadius: 2,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(34),
                      child: Image.asset(
                        'assets/images/zunify_logo.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => VinylDiscWidget(
                          imageUrl: '',
                          isPlaying: true,
                          accentColor: accent,
                          size: 132,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  const Text(
                    'Zunify',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Liquid Glass Music Experience',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.62),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // iOS 27.2 Liquid Glass Login Box
                  LiquidGlassBox(
                    borderRadius: 28,
                    padding: const EdgeInsets.all(24),
                    tintOpacity: 0.14,
                    rimIntensity: 0.44,
                    enableBlur: true,
                    enableShadow: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Siapa nama panggilanmu?',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _nameController,
                          autofocus: true,
                          textCapitalization: TextCapitalization.words,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          onSubmitted: (_) => _submitName(),
                          decoration: InputDecoration(
                            hintText: 'Ketik nama kamu...',
                            hintStyle: const TextStyle(color: Colors.white38),
                            filled: true,
                            fillColor: Colors.black.withOpacity(0.35),
                            prefixIcon: Icon(Icons.person_rounded, color: accent),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 16,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide(color: accent, width: 1.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        IosSpringButton(
                          scaleDown: 0.93,
                          borderRadius: 18,
                          onTap: _submitName,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: accent,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: accent.withOpacity(0.36),
                                  blurRadius: 18,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Text(
                              'Masuk',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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
