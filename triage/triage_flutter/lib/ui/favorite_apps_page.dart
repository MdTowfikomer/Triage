import 'package:flutter/material.dart';
import '../actions/favorite_apps_repository.dart';
import '../actions/native_action_client.dart';

class FavoriteAppsPage extends StatefulWidget {
  const FavoriteAppsPage({super.key, required this.repository});

  final FavoriteAppsRepository repository;

  @override
  State<FavoriteAppsPage> createState() => _FavoriteAppsPageState();
}

class _FavoriteAppsPageState extends State<FavoriteAppsPage> {
  static const ink = Color(0xFF242521);
  static const muted = Color(0xFF777971);
  static const line = Color(0xFFE9E8E2);
  static const accent = Color(0xFFE78A4E);

  final NativeActionClient _native = NativeActionClient();
  final TextEditingController _aliasController = TextEditingController();

  List<Map<String, String>> _installedApps = [];
  bool _isLoadingInstalled = false;

  @override
  void initState() {
    super.initState();
    _loadInstalledApps();
  }

  @override
  void dispose() {
    _aliasController.dispose();
    super.dispose();
  }

  Future<void> _loadInstalledApps() async {
    setState(() => _isLoadingInstalled = true);
    try {
      final apps = await _native.getInstalledApps();
      if (mounted) {
        setState(() {
          _installedApps = apps;
          _isLoadingInstalled = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingInstalled = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pinned = widget.repository.getAll();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F2),
      appBar: AppBar(
        title: const Text(
          'Pinned Favorite Apps',
          style: TextStyle(fontWeight: FontWeight.w700, color: ink, fontSize: 18),
        ),
        backgroundColor: const Color(0xFFF8F7F2),
        elevation: 0,
        iconTheme: const IconThemeData(color: ink),
        actions: [
          IconButton(
            tooltip: 'Add Favorite App',
            icon: const Icon(Icons.add_circle_outline_rounded, color: accent),
            onPressed: _showAddAppModal,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: line),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: accent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Triage can open any app on your phone. Pin favorites here to set custom voice aliases (e.g. say "insta" for Instagram).',
                    style: TextStyle(color: muted, fontSize: 13, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'PINNED APPS',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: muted),
          ),
          const SizedBox(height: 8),
          if (pinned.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: line),
              ),
              child: Column(
                children: [
                  Icon(Icons.apps_rounded, size: 42, color: muted.withValues(alpha: 0.5)),
                  const SizedBox(height: 12),
                  const Text(
                    'No pinned apps yet',
                    style: TextStyle(fontWeight: FontWeight.w700, color: ink, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Tap the + button above to pick an app and assign voice shortcuts.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted, fontSize: 13),
                  ),
                ],
              ),
            )
          else
            ...pinned.map((app) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: line),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Icon(Icons.android_rounded, color: accent, size: 24),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            app.name,
                            style: const TextStyle(fontWeight: FontWeight.w700, color: ink, fontSize: 15),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            app.aliases.isNotEmpty
                                ? 'Aliases: ${app.aliases.join(", ")}'
                                : app.packageName,
                            style: const TextStyle(color: muted, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20, color: muted),
                      onPressed: () => _editAliasesModal(app),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
                      onPressed: () async {
                        await widget.repository.remove(app.packageName);
                        setState(() {});
                      },
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  void _showAddAppModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF8F7F2),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: line,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Select App to Pin',
                    style: TextStyle(fontWeight: FontWeight.w800, color: ink, fontSize: 18),
                  ),
                  const SizedBox(height: 12),
                  if (_isLoadingInstalled)
                    const Expanded(
                      child: Center(
                        child: CircularProgressIndicator(color: accent),
                      ),
                    )
                  else if (_installedApps.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text('No launcher apps found.', style: TextStyle(color: muted)),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        itemCount: _installedApps.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: line),
                        itemBuilder: (context, i) {
                          final item = _installedApps[i];
                          final label = item['label'] ?? '';
                          final pkg = item['packageName'] ?? '';
                          final isAlreadyPinned = widget.repository
                              .getAll()
                              .any((a) => a.packageName == pkg);

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: ink)),
                            subtitle: Text(pkg, style: const TextStyle(fontSize: 11, color: muted)),
                            trailing: isAlreadyPinned
                                ? const Chip(
                                    label: Text('Pinned', style: TextStyle(fontSize: 10, color: muted)),
                                    backgroundColor: line,
                                  )
                                : ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: ink,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    ),
                                    onPressed: () async {
                                      Navigator.pop(ctx);
                                      await widget.repository.addOrUpdate(
                                        FavoriteApp(
                                          name: label,
                                          packageName: pkg,
                                          aliases: [label.toLowerCase()],
                                        ),
                                      );
                                      setState(() {});
                                    },
                                    child: const Text('Pin', style: TextStyle(fontSize: 12)),
                                  ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _editAliasesModal(FavoriteApp app) {
    _aliasController.text = app.aliases.join(', ');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFFF8F7F2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Edit Aliases: ${app.name}', style: const TextStyle(color: ink, fontSize: 17, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter comma-separated nicknames you might speak to open this app (e.g. "insta, ig"):',
                style: TextStyle(color: muted, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _aliasController,
                decoration: InputDecoration(
                  hintText: 'e.g. insta, photos, chat',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: line),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: muted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: ink,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final text = _aliasController.text.trim();
                final aliases = text.isEmpty
                    ? <String>[]
                    : text.split(',').map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty).toList();
                await widget.repository.addOrUpdate(
                  FavoriteApp(
                    name: app.name,
                    packageName: app.packageName,
                    aliases: aliases,
                  ),
                );
                if (context.mounted) {
                  Navigator.pop(ctx);
                  setState(() {});
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}
