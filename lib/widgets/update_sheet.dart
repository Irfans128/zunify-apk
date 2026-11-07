import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_version.dart';
import '../providers/theme_provider.dart';
import '../services/update_service.dart';
import 'liquid_background_widget.dart';

/// Shows the update bottom sheet: changelog + "Update Sekarang", "Nanti", "Lewati versi ini".
Future<void> showUpdateSheet(BuildContext context, UpdateInfo info) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    backgroundColor: Colors.transparent,
    builder: (_) => UpdateSheet(info: info),
  );
}

/// Manual check (from Settings). Shows a snackbar when already up to date.
Future<void> runManualUpdateCheck(BuildContext context) async {
  final accent = context.read<ThemeProvider>().accentColor;
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    const SnackBar(
      duration: Duration(seconds: 1),
      content: Text('Mengecek pembaruan...'),
    ),
  );
  try {
    final info = await UpdateService().checkForUpdate(manual: true);
    if (!context.mounted) return;
    messenger.hideCurrentSnackBar();
    if (info == null) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: accent,
          content: const Text(
            'Zunify sudah versi terbaru',
            style: TextStyle(
              color: Color(0xFF111111),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
    } else {
      await showUpdateSheet(context, info);
    }
  } catch (_) {
    if (!context.mounted) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Gagal mengecek update. Periksa koneksi internet.'),
      ),
    );
  }
}

class UpdateSheet extends StatefulWidget {
  final UpdateInfo info;

  const UpdateSheet({super.key, required this.info});

  @override
  State<UpdateSheet> createState() => _UpdateSheetState();
}

class _UpdateSheetState extends State<UpdateSheet> {
  final UpdateService _service = UpdateService();
  bool _downloading = false;
  double _progress = 0;
  String? _error;
  String? _downloadedPath;

  Future<void> _startUpdate() async {
    setState(() {
      _downloading = true;
      _error = null;
      _progress = 0;
    });
    try {
      final path = _downloadedPath ??
          await _service.downloadApk(
            widget.info,
            onProgress: (p) {
              if (mounted) setState(() => _progress = p);
            },
          );
      _downloadedPath = path;
      if (!mounted) return;
      setState(() => _downloading = false);
      final ok = await _service.installApk(path);
      if (!ok && mounted) {
        setState(
          () => _error =
              'Installer tidak terbuka. Izinkan "Instal aplikasi tidak dikenal" untuk Zunify lalu coba lagi.',
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _error = 'Download gagal. Periksa koneksi lalu coba lagi.';
      });
    }
  }

  List<String> _changelogLines() {
    final raw = widget.info.changelog;
    if (raw.isEmpty) return const ['Peningkatan performa & perbaikan bug.'];
    return raw
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('#'))
        .map((l) => l.replaceFirst(RegExp(r'^[-*•]\s*'), ''))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final accent = theme.accentColor;
    final isBrutal = theme.isNeoBrutalism;
    final info = widget.info;
    final lines = _changelogLines();

    return ZunifySheetContainer(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isBrutal ? accent : accent.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(isBrutal ? 11 : 14),
                    border: isBrutal
                        ? Border.all(color: theme.brutalBorderColor, width: 2.0)
                        : null,
                  ),
                  child: Icon(
                    Icons.system_update_rounded,
                    color: isBrutal ? const Color(0xFF111111) : accent,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Update Tersedia',
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'v$kAppVersion  →  v${info.version}'
                        '${info.sizeLabel.isNotEmpty ? '  •  ${info.sizeLabel}' : ''}',
                        style: TextStyle(
                          color: theme.accentText,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Yang baru',
              style: TextStyle(
                color: theme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: LiquidGlassBox(
                width: double.infinity,
                borderRadius: 16,
                padding: const EdgeInsets.all(14),
                tintOpacity: 0.06,
                rimIntensity: 0.28,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: lines
                        .map(
                          (l) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Container(
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: theme.accentText,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    l.replaceAll('**', ''),
                                    style: TextStyle(
                                      color: theme.textPrimary,
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_downloading) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  minHeight: 6,
                  color: theme.accentText,
                  backgroundColor: theme.dividerColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Mengunduh update... ${(_progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  color: theme.accentText,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_error != null) ...[
              Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: const Color(0xFF111111),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: isBrutal
                      ? BorderSide(color: theme.brutalBorderColor, width: 2.2)
                      : BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(isBrutal ? 11 : 14),
                  ),
                ),
                onPressed: _downloading ? null : _startUpdate,
                icon: Icon(
                  _downloadedPath != null
                      ? Icons.install_mobile_rounded
                      : Icons.download_rounded,
                  size: 20,
                ),
                label: Text(
                  _downloadedPath != null
                      ? 'Install Sekarang'
                      : 'Update Sekarang',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed:
                        _downloading ? null : () => Navigator.pop(context),
                    child: Text(
                      'Nanti',
                      style: TextStyle(
                        color: theme.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: _downloading
                        ? null
                        : () async {
                            await _service.skipVersion(info.version);
                            if (context.mounted) Navigator.pop(context);
                          },
                    child: Text(
                      'Lewati versi ini',
                      style: TextStyle(
                        color: theme.textMuted,
                        fontWeight: FontWeight.w600,
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
}
