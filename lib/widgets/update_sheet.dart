import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_version.dart';
import '../providers/theme_provider.dart';
import '../services/update_service.dart';

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
            'Zunify kamu sudah versi terbaru ✨',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
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
      const SnackBar(content: Text('Gagal mengecek update. Periksa koneksi internet.')),
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
        setState(() => _error =
            'Installer tidak terbuka. Izinkan "Instal aplikasi tidak dikenal" untuk Zunify lalu coba lagi.');
      }
    } catch (e) {
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
    final accent = context.watch<ThemeProvider>().accentColor;
    final info = widget.info;
    final lines = _changelogLines();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: const Color(0xFF101420),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
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
                  color: Colors.white24,
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
                    color: accent.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.system_update_rounded, color: accent, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Update Tersedia',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'v$kAppVersion  →  v${info.version}'
                        '${info.sizeLabel.isNotEmpty ? '  •  ${info.sizeLabel}' : ''}',
                        style: TextStyle(
                          color: accent,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Yang baru',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
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
                                      color: accent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    l.replaceAll('**', ''),
                                    style: const TextStyle(
                                      color: Colors.white,
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
                  color: accent,
                  backgroundColor: Colors.white12,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Mengunduh update... ${(_progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  color: accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
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
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
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
                  _downloadedPath != null ? 'Install Sekarang' : 'Update Sekarang',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _downloading ? null : () => Navigator.pop(context),
                    child: const Text(
                      'Nanti',
                      style: TextStyle(
                        color: Colors.white70,
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
                    child: const Text(
                      'Lewati versi ini',
                      style: TextStyle(
                        color: Colors.white38,
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
