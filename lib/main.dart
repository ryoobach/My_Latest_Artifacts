import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runZonedGuarded(() async {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      DiagnosticLog.write('flutter_error', details.exceptionAsString(),
          details.stack?.toString());
    };
    runApp(const MyLatestArtifactsApp());
  }, (error, stack) {
    DiagnosticLog.write('uncaught_error', error.toString(), stack.toString());
  });
}

class DiagnosticLog {
  static Future<void> write(String event, String message, [String? stack]) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/my_latest_artifacts.log');
      final line = jsonEncode({
        'time': DateTime.now().toUtc().toIso8601String(),
        'version': '0.2.1',
        'platform': Platform.operatingSystem,
        'event': event,
        'message': message,
        if (stack != null) 'stack': stack,
      });
      await file.writeAsString('$line\n', mode: FileMode.append, flush: true);
      if (await file.length() > 1024 * 1024) {
        final lines = await file.readAsLines();
        await file.writeAsString(lines.skip(lines.length ~/ 2).join('\n') + '\n');
      }
    } catch (_) {}
  }
}

const List<String> supportedPlatforms = [
  'GitHub',
  'GitLab',
  'Bitbucket',
  'Azure DevOps',
  'Jenkins',
];

class MyLatestArtifactsApp extends StatelessWidget {
  const MyLatestArtifactsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Latest Artifacts',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4267B2)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF5F7FA),
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
        ),
      ),
      home: const ArtifactHomePage(),
    );
  }
}

class ArtifactHomePage extends StatefulWidget {
  const ArtifactHomePage({super.key});

  @override
  State<ArtifactHomePage> createState() => _ArtifactHomePageState();
}

class _ArtifactHomePageState extends State<ArtifactHomePage> {
  Set<String> selectedPlatforms = {};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    DiagnosticLog.write('app_started', 'Application launched');
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList('selected_platforms') ?? [];
      if (!mounted) return;
      setState(() {
        selectedPlatforms = saved.where(supportedPlatforms.contains).toSet();
        loading = false;
      });
    } catch (error, stack) {
      DiagnosticLog.write('settings_load_failed', error.toString(), stack.toString());
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _editPlatforms() async {
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (_) => PlatformSelectionDialog(initial: selectedPlatforms),
    );
    if (result == null) return;
    final removed = selectedPlatforms.difference(result);
    for (final platform in removed) {
      await PlatformCredentials.delete(platform);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('selected_platforms', supportedPlatforms
        .where(result.contains).toList());
    if (!mounted) return;
    setState(() => selectedPlatforms = result);
    DiagnosticLog.write('platform_selection_saved', result.join(','));
  }

  void _showAbout() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('앱 정보'),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('js_logo.png',
                width: 88, height: 56, fit: BoxFit.contain),
            const SizedBox(width: 12),
            const Flexible(
              child: Text(
                'Ryoo jaesang & 최피디',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('my latest artifacts icon.jpg',
                width: 34, height: 34, fit: BoxFit.contain),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('My Latest Artifacts',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '앱 정보',
            onPressed: _showAbout,
            icon: const Icon(Icons.info_outline),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: loading ? null : _editPlatforms,
        icon: const Icon(Icons.add),
        label: const Text('프로젝트 추가'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('프로젝트별 최신 아티팩트',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text('각 프로젝트의 가장 최근 결과물만 표시합니다.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.black54)),
                  const SizedBox(height: 16),
                  Expanded(
                    child: selectedPlatforms.isEmpty
                        ? const _EmptyState()
                        : _SelectedPlatformsState(platforms: supportedPlatforms
                            .where(selectedPlatforms.contains).toList()),
                  ),
                ],
              ),
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.inventory_2_outlined, size: 58, color: Color(0xFF9AA4B2)),
        SizedBox(height: 14),
        Text('등록된 프로젝트가 없습니다',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        SizedBox(height: 7),
        Text('프로젝트를 추가하면 최신 아티팩트를\n이 화면에서 확인할 수 있습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54, height: 1.5)),
      ],
    ),
  );
}

class PlatformCredentials {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static String _key(String platform, String field) =>
      'platform_${platform.toLowerCase().replaceAll(' ', '_')}_$field';

  static Future<bool> hasCredentials(String platform) async {
    final id = await _storage.read(key: _key(platform, 'id'));
    final secret = await _storage.read(key: _key(platform, 'secret'));
    return (id?.isNotEmpty ?? false) && (secret?.isNotEmpty ?? false);
  }

  static Future<Map<String, String>> read(String platform) async => {
    'id': await _storage.read(key: _key(platform, 'id')) ?? '',
    'secret': await _storage.read(key: _key(platform, 'secret')) ?? '',
  };

  static Future<void> save(String platform, String id, String secret) async {
    await _storage.write(key: _key(platform, 'id'), value: id);
    await _storage.write(key: _key(platform, 'secret'), value: secret);
  }

  static Future<void> delete(String platform) async {
    await _storage.delete(key: _key(platform, 'id'));
    await _storage.delete(key: _key(platform, 'secret'));
  }
}

class _SelectedPlatformsState extends StatefulWidget {
  const _SelectedPlatformsState({required this.platforms});
  final List<String> platforms;

  @override
  State<_SelectedPlatformsState> createState() => _SelectedPlatformsStateState();
}

class _SelectedPlatformsStateState extends State<_SelectedPlatformsState> {
  void _openCredentials(String platform) async {
    await showDialog<void>(
      context: context,
      builder: (_) => PlatformCredentialDialog(platform: platform),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('선택된 개발 플랫폼',
          style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      ...widget.platforms.map((platform) => FutureBuilder<bool>(
        future: PlatformCredentials.hasCredentials(platform),
        builder: (context, snapshot) {
          final saved = snapshot.data == true;
          return Card(
            elevation: 0,
            color: Colors.white,
            child: ListTile(
              leading: const Icon(Icons.cloud_outlined),
              title: Text(platform),
              subtitle: Text(saved
                  ? '인증 정보가 안전하게 저장되어 있습니다.'
                  : '로그인 정보 입력이 필요합니다.'),
              trailing: Icon(
                saved ? Icons.verified_user_outlined : Icons.login,
                color: saved ? Colors.green : Colors.black54,
              ),
              onTap: () => _openCredentials(platform),
            ),
          );
        },
      )),
      const SizedBox(height: 8),
      const Text(
        '플랫폼을 누르면 인증 정보를 입력하거나 변경할 수 있습니다. 실제 계정 인증과 아티팩트 자동 조회는 각 사이트 API 연결 단계에서 활성화됩니다.',
        style: TextStyle(fontSize: 12, color: Colors.black54),
      ),
    ],
  );
}

class PlatformCredentialDialog extends StatefulWidget {
  const PlatformCredentialDialog({super.key, required this.platform});
  final String platform;

  @override
  State<PlatformCredentialDialog> createState() =>
      _PlatformCredentialDialogState();
}

class _PlatformCredentialDialogState extends State<PlatformCredentialDialog> {
  final _idController = TextEditingController();
  final _secretController = TextEditingController();
  bool _loading = true;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final saved = await PlatformCredentials.read(widget.platform);
    _idController.text = saved['id'] ?? '';
    _secretController.text = saved['secret'] ?? '';
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _idController.dispose();
    _secretController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final id = _idController.text.trim();
    final secret = _secretController.text;
    if (id.isEmpty || secret.isEmpty) return;
    await PlatformCredentials.save(widget.platform, id, secret);
    await DiagnosticLog.write('platform_credentials_saved',
        '${widget.platform}: credential values excluded');
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('${widget.platform} 로그인 정보'),
    content: SizedBox(
      width: 360,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _idController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'ID / 계정 이름',
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _secretController,
                  onChanged: (_) => setState(() {}),
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: '비밀번호 / API 토큰',
                    helperText: '가능하면 사이트에서 발급한 API 토큰을 사용하세요.',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(_obscure
                          ? Icons.visibility
                          : Icons.visibility_off),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '입력값은 기기의 보안 저장소에 보관됩니다. 현재 단계에서는 저장만 가능하며, 실제 로그인 검증과 자동 아티팩트 조회는 아직 연결되지 않았습니다.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('취소'),
      ),
      TextButton(
        onPressed: _loading
            ? null
            : () async {
                await PlatformCredentials.delete(widget.platform);
                if (mounted) Navigator.pop(context);
              },
        child: const Text('정보 삭제'),
      ),
      FilledButton(
        onPressed: _loading ||
                _idController.text.trim().isEmpty ||
                _secretController.text.isEmpty
            ? null
            : _save,
        child: const Text('안전하게 저장'),
      ),
    ],
  );
}

class PlatformSelectionDialog extends StatefulWidget {
  const PlatformSelectionDialog({super.key, required this.initial});
  final Set<String> initial;

  @override
  State<PlatformSelectionDialog> createState() => _PlatformSelectionDialogState();
}

class _PlatformSelectionDialogState extends State<PlatformSelectionDialog> {
  late Set<String> checked;

  @override
  void initState() {
    super.initState();
    checked = Set<String>.from(widget.initial);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('개발 플랫폼 선택'),
    content: SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('아티팩트를 확인할 사이트를 선택하세요.'),
          ),
          const SizedBox(height: 8),
          ...supportedPlatforms.map((platform) => CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(platform),
            value: checked.contains(platform),
            onChanged: (value) => setState(() {
              if (value == true) {
                checked.add(platform);
              } else {
                checked.remove(platform);
              }
            }),
          )),
          const SizedBox(height: 4),
          const Text(
            '선택한 사이트는 다음 실행 때도 유지됩니다. 계정 인증 및 실제 아티팩트 자동 조회는 후속 연결이 필요합니다.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('취소'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, checked),
        child: const Text('저장'),
      ),
    ],
  );
}
