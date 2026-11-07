import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import 'liquid_background_widget.dart';

/// Manages Notification & Microphone permissions on first launch and whenever revoked.
class AppPermissionsManager {
  static const MethodChannel _channel = MethodChannel(
    'com.fannz.zunify/equalizer',
  );

  static bool _isSheetOpen = false;
  static bool _dismissedForCurrentMissingState = false;
  static bool _lastAllGranted = true;

  static Future<({bool notifGranted, bool micGranted})> getStatus() async {
    try {
      final raw = await _channel.invokeMethod<dynamic>('getPermissionsStatus');
      if (raw is Map) {
        return (
          notifGranted: raw['notifGranted'] == true,
          micGranted: raw['micGranted'] == true,
        );
      }
    } catch (_) {}
    return (notifGranted: true, micGranted: true);
  }

  /// Triggered on first-time OnboardingScreen so Android asks immediately on fresh install.
  static Future<({bool notifGranted, bool micGranted})>
      requestDirectPermissions() async {
    try {
      final raw = await _channel.invokeMethod<dynamic>('requestAppPermissions');
      if (raw is Map) {
        return (
          notifGranted: raw['notifGranted'] == true,
          micGranted: raw['micGranted'] == true,
        );
      }
    } catch (_) {}
    return getStatus();
  }

  static Future<void> openPermissionSettings({String target = 'app'}) async {
    try {
      await _channel.invokeMethod('openAppPermissionSettings', {
        'target': target,
      });
    } catch (_) {}
  }

  /// Checks Notification & Mic permissions on app open / resume.
  /// Shows a clean theme-adaptive prompt whenever either permission is missing or was revoked.
  static Future<void> checkAndPromptIfMissing(BuildContext context) async {
    if (_isSheetOpen || !context.mounted) return;

    final status = await getStatus();
    final allGranted = status.notifGranted && status.micGranted;

    if (allGranted) {
      _lastAllGranted = true;
      _dismissedForCurrentMissingState = false;
      return;
    }

    // If permissions were previously granted and got revoked ("izin hilang"), re-enable prompt
    if (_lastAllGranted) {
      _dismissedForCurrentMissingState = false;
    }
    _lastAllGranted = false;

    if (_dismissedForCurrentMissingState || !context.mounted) return;

    _isSheetOpen = true;
    try {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _PermissionsPromptSheet(
          initialNotifGranted: status.notifGranted,
          initialMicGranted: status.micGranted,
        ),
      );
    } finally {
      _isSheetOpen = false;
      final after = await getStatus();
      if (after.notifGranted && after.micGranted) {
        _lastAllGranted = true;
        _dismissedForCurrentMissingState = false;
      } else {
        _dismissedForCurrentMissingState = true;
      }
    }
  }
}

class _PermissionsPromptSheet extends StatefulWidget {
  final bool initialNotifGranted;
  final bool initialMicGranted;

  const _PermissionsPromptSheet({
    required this.initialNotifGranted,
    required this.initialMicGranted,
  });

  @override
  State<_PermissionsPromptSheet> createState() =>
      _PermissionsPromptSheetState();
}

class _PermissionsPromptSheetState extends State<_PermissionsPromptSheet>
    with WidgetsBindingObserver {
  late bool _notifGranted;
  late bool _micGranted;
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    _notifGranted = widget.initialNotifGranted;
    _micGranted = widget.initialMicGranted;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshStatus();
    }
  }

  Future<void> _refreshStatus() async {
    final s = await AppPermissionsManager.getStatus();
    if (!mounted) return;
    setState(() {
      _notifGranted = s.notifGranted;
      _micGranted = s.micGranted;
    });
    if (s.notifGranted && s.micGranted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Future<void> _handleGrantNow() async {
    if (_requesting) return;
    setState(() => _requesting = true);
    final startedAt = DateTime.now();
    final res = await AppPermissionsManager.requestDirectPermissions();
    final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;

    if (!mounted) return;
    setState(() {
      _notifGranted = res.notifGranted;
      _micGranted = res.micGranted;
      _requesting = false;
    });

    if (res.notifGranted && res.micGranted) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      return;
    }

    // If Android suppressed the popup (<260ms) or notifications are disabled in system settings
    if (elapsedMs < 260) {
      final onlyNotifMissing = !res.notifGranted && res.micGranted;
      await AppPermissionsManager.openPermissionSettings(
        target: onlyNotifMissing ? 'notif' : 'app',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final accent = theme.accentColor;
    final isBrutal = theme.isNeoBrutalism;

    return ZunifySheetContainer(
      blurSigma: 32,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                LiquidGlassBox(
                  width: 40,
                  height: 40,
                  borderRadius: 13,
                  tintColor: accent,
                  tintOpacity: isBrutal ? 0.26 : 0.22,
                  rimIntensity: 0.48,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.verified_user_rounded,
                    color: isBrutal ? const Color(0xFF111111) : accent,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Aktifkan Izin Aplikasi',
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Agar notifikasi musik & pencarian suara optimal',
                        style: TextStyle(
                          color: theme.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildPermissionItem(
              icon: Icons.notifications_active_rounded,
              title: 'Notifikasi',
              subtitle: 'Kontrol pemutar latar belakang & Rapot Mingguan',
              granted: _notifGranted,
              theme: theme,
              accent: accent,
              isBrutal: isBrutal,
            ),
            const SizedBox(height: 10),
            _buildPermissionItem(
              icon: Icons.mic_rounded,
              title: 'Mikrofon',
              subtitle: 'Deteksi cepat judul lagu dengan suara',
              granted: _micGranted,
              theme: theme,
              accent: accent,
              isBrutal: isBrutal,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: LiquidGlassBox(
                    height: 46,
                    borderRadius: 15,
                    tintOpacity: 0.06,
                    rimIntensity: 0.30,
                    alignment: Alignment.center,
                    onTap: () => Navigator.pop(context),
                    child: Text(
                      'Nanti',
                      style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: IosSpringButton(
                    onTap: _requesting ? null : _handleGrantNow,
                    child: Container(
                      height: 46,
                      alignment: Alignment.center,
                      decoration: isBrutal
                          ? BoxDecoration(
                              color: accent,
                              borderRadius: BorderRadius.circular(11),
                              border: Border.all(
                                color: theme.brutalBorderColor,
                                width: 2.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.brutalShadowColor,
                                  blurRadius: 0,
                                  offset: const Offset(3, 3),
                                ),
                              ],
                            )
                          : BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color.lerp(accent, Colors.white, 0.22)!,
                                  accent,
                                ],
                              ),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.38),
                                width: 1.1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: accent.withOpacity(0.36),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                      child: Text(
                        _requesting ? 'Meminta Izin...' : 'Izinkan Sekarang',
                        style: const TextStyle(
                          color: Color(0xFF0B0E17),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool granted,
    required ThemeProvider theme,
    required Color accent,
    required bool isBrutal,
  }) {
    final statusColor = granted ? const Color(0xFF10B981) : accent;
    return LiquidGlassBox(
      borderRadius: 16,
      tintColor: statusColor,
      tintOpacity: isBrutal ? 0.12 : 0.09,
      rimIntensity: 0.38,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isBrutal
                  ? statusColor.withOpacity(0.28)
                  : statusColor.withOpacity(0.18),
              borderRadius: BorderRadius.circular(isBrutal ? 9 : 11),
              border: isBrutal
                  ? Border.all(color: theme.brutalBorderColor, width: 1.6)
                  : null,
            ),
            child: Icon(
              icon,
              color: isBrutal ? const Color(0xFF111111) : statusColor,
              size: 19,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 13.8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 1.5),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: theme.textMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: granted
                  ? const Color(0xFF10B981).withOpacity(0.18)
                  : accent.withOpacity(isBrutal ? 0.26 : 0.16),
              borderRadius: BorderRadius.circular(8),
              border: isBrutal
                  ? Border.all(color: theme.brutalBorderColor, width: 1.4)
                  : null,
            ),
            child: Text(
              granted ? 'Aktif' : 'Belum',
              style: TextStyle(
                color: granted
                    ? (isBrutal
                          ? const Color(0xFF065F46)
                          : const Color(0xFF34D399))
                    : (isBrutal ? const Color(0xFF111111) : accent),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
