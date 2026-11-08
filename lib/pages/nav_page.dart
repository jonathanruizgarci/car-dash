import 'package:flutter/material.dart';

import '../services/music.dart';
import '../services/native.dart';
import '../services/settings.dart';
import '../widgets/common.dart';
import 'home_page.dart';

/// Navegación + música: abre Waze/Maps/Android Auto y deja el reproductor flotando encima.
class NavPage extends StatefulWidget {
  const NavPage({super.key});

  @override
  State<NavPage> createState() => _NavPageState();
}

class _NavPageState extends State<NavPage> {
  Future<void> _go(QuickApp app) async {
    final s = Settings.I;
    if (s.floatingMusic && !await NativeBridge.canOverlay()) {
      if (!mounted) return;
      final allow = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Música encima del mapa'),
          content: const Text(
              'Para ver la canción y los botones mientras navegas, activa "Mostrar sobre otras apps" para AutoPanel.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Ahora no')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Activar')),
          ],
        ),
      );
      if (allow == true) {
        await NativeBridge.openOverlaySettings();
        return;
      }
    }
    if (!mounted) return;
    await launchQuickApp(context, app);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final navApps = [kQuickApps[0], kQuickApps[1], kQuickApps[3]];
    return ListenableBuilder(
      listenable: Listenable.merge([MusicService.I, Settings.I]),
      builder: (context, _) {
        final s = Settings.I;
        final canOverlay = MusicService.I.canOverlay;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Expanded(flex: 6, child: MusicPlayerCard()),
            const SizedBox(width: kGap),
            Expanded(
              flex: 5,
              child: ListView(
                children: [
                  const SectionTitle('Navegar'),
                  for (final app in navApps)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Panel(
                        onTap: () => _go(app),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: app.color.withValues(alpha: 0.15),
                              child: Icon(app.icon, color: app.color, size: 28),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text('Abrir ${app.name}',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Reproductor flotante al navegar'),
                          subtitle: Text(canOverlay
                              ? 'Aparece encima de Waze/Maps con portada y botones. Arrástralo a donde quieras.'
                              : 'Falta el permiso "Mostrar sobre otras apps"'),
                          value: s.floatingMusic,
                          onChanged: (v) => s.update((x) => x.floatingMusic = v),
                        ),
                        if (!canOverlay)
                          OutlinedButton.icon(
                            onPressed: () async {
                              await NativeBridge.openOverlaySettings();
                            },
                            icon: const Icon(Icons.picture_in_picture),
                            label: const Text('Dar permiso'),
                          ),
                        const SizedBox(height: 6),
                        Text(
                          'Tip: para controlar la música de tu celular, abre Spotify en la tableta con la misma cuenta '
                          'y elige tu celular en "Dispositivos disponibles" (Spotify Connect).',
                          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
