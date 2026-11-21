import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const String appVersion = '0.2.4';

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
        'version': appVersion,
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
      home: const LoginPage(),
    );
  }
}


String _formattedToday() {
  final now = DateTime.now();
  final year = now.year.toString().padLeft(4, '0');
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showNotice(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _login() {
    if (_idController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      _showNotice('아이디와 비밀번호를 입력해 주세요.');
      return;
    }
    DiagnosticLog.write('login_attempt', 'Password login attempted; credentials excluded');
    _showNotice('계정 인증 서버가 아직 연결되지 않았습니다. 인증 연동 후 사용할 수 있습니다.');
  }

  void _socialLogin(String provider) {
    DiagnosticLog.write('social_login_tapped', '$provider OAuth is not configured');
    _showNotice('$provider 간편 로그인은 서비스 인증 설정 후 사용할 수 있습니다.');
  }

  Widget _socialButton({
    required String name,
    required Color background,
    required Color foreground,
    required Widget mark,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _socialLogin(name),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE4E7EC)),
                ),
                child: DefaultTextStyle(
                  style: TextStyle(
                    color: foreground,
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                  ),
                  child: mark,
                ),
              ),
              const SizedBox(height: 6),
              Text(name, style: const TextStyle(fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Card(
                elevation: 1,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 28,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'my latest artifacts icon.jpg',
                        width: 68,
                        height: 68,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'My Latest Artifacts',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '로그인',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            flex: 5,
                            child: TextField(
                              controller: _idController,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                hintText: '아이디',
                                prefixIcon: Icon(Icons.person_outline, size: 19),
                                prefixIconConstraints:
                                    BoxConstraints(minWidth: 30),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 15,
                                ),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 5,
                            child: TextField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              onSubmitted: (_) => _login(),
                              decoration: InputDecoration(
                                hintText: '비밀번호',
                                prefixIcon:
                                    const Icon(Icons.lock_outline, size: 19),
                                prefixIconConstraints:
                                    const BoxConstraints(minWidth: 30),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 15,
                                ),
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 30,
                                    minHeight: 36,
                                  ),
                                  onPressed: () => setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  }),
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 50,
                            child: FilledButton(
                              onPressed: _login,
                              style: FilledButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(9),
                                ),
                              ),
                              child: const Text(
                                '로그인',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 26),
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              '간편 로그인',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _socialButton(
                            name: 'Google',
                            background: Colors.white,
                            foreground: const Color(0xFF4285F4),
                            mark: const Text('G'),
                          ),
                          _socialButton(
                            name: 'Facebook',
                            background: const Color(0xFF1877F2),
                            foreground: Colors.white,
                            mark: const Text('f'),
                          ),
                          _socialButton(
                            name: '카카오톡',
                            background: const Color(0xFFFEE500),
                            foreground: const Color(0xFF191919),
                            mark: const Icon(
                              Icons.chat_bubble,
                              size: 25,
                              color: Color(0xFF191919),
                            ),
                          ),
                          _socialButton(
                            name: '네이버',
                            background: const Color(0xFF03C75A),
                            foreground: Colors.white,
                            mark: const Text('N'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        '계정 로그인과 간편 로그인은 인증 서버 및 서비스별 설정이 완료된 후 활성화됩니다.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black45,
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Image.asset('my latest artifacts icon.jpg',
                    width: 52, height: 52, fit: BoxFit.contain),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('My Latest Artifacts',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700)),
                      SizedBox(height: 4),
                      Text('버전 $appVersion',
                          style: TextStyle(color: Colors.black54)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                _formattedToday(),
                style: const TextStyle(color: Colors.black54, fontSize: 13),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Image.asset('js_logo.png',
                    width: 58, height: 58, fit: BoxFit.contain),
                const SizedBox(width: 12),
                const Flexible(
                  child: Text(
                    'Ryoo jaesang & 최피디',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
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
