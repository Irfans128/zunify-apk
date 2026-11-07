import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/library_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/liquid_background_widget.dart';
import '../widgets/permissions_sheet.dart';
import '../widgets/vinyl_disc_widget.dart';

/// First-Time Welcome & Local Account Login Screen
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        unawaited(AppPermissionsManager.requestDirectPermissions());
      });
    });
  }

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
    final isBrutal = theme.isNeoBrutalism;

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
                    width: 128,
                    height: 128,
                    decoration: isBrutal
                        ? BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: theme.brutalBorderColor,
                              width: 2.6,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: theme.brutalShadowColor,
                                blurRadius: 0,
                                offset: const Offset(5.0, 5.0),
                              ),
                            ],
                          )
                        : BoxDecoration(
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
                      borderRadius: BorderRadius.circular(isBrutal ? 21.4 : 34),
                      child: Image.asset(
                        'assets/images/zunify_logo.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => VinylDiscWidget(
                          imageUrl: '',
                          isPlaying: true,
                          accentColor: accent,
                          size: 128,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'Zunify',
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 28),

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
                        Text(
                          'Siapa nama panggilanmu?',
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _nameController,
                          autofocus: true,
                          textCapitalization: TextCapitalization.words,
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          onSubmitted: (_) => _submitName(),
                          decoration: InputDecoration(
                            hintText: 'Ketik nama kamu...',
                            hintStyle: TextStyle(color: theme.textMuted),
                            filled: true,
                            fillColor: isBrutal
                                ? theme.scaffoldBgColor
                                : Colors.black.withOpacity(0.35),
                            prefixIcon: Icon(
                              Icons.person_rounded,
                              color: theme.accentText,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 16,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                isBrutal ? 12 : 18,
                              ),
                              borderSide: isBrutal
                                  ? BorderSide(
                                      color: theme.brutalBorderColor,
                                      width: 2.0,
                                    )
                                  : BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                isBrutal ? 12 : 18,
                              ),
                              borderSide: BorderSide(
                                color:
                                    isBrutal ? theme.brutalBorderColor : accent,
                                width: isBrutal ? 2.4 : 1.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        IosSpringButton(
                          scaleDown: 0.93,
                          borderRadius: isBrutal ? 12 : 18,
                          onTap: _submitName,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: accent,
                              borderRadius: BorderRadius.circular(
                                isBrutal ? 12 : 18,
                              ),
                              border: isBrutal
                                  ? Border.all(
                                      color: theme.brutalBorderColor,
                                      width: 2.2,
                                    )
                                  : null,
                              boxShadow: isBrutal
                                  ? [
                                      BoxShadow(
                                        color: theme.brutalShadowColor,
                                        blurRadius: 0,
                                        offset: const Offset(3.5, 3.5),
                                      ),
                                    ]
                                  : [
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
                                color: Color(0xFF111111),
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
