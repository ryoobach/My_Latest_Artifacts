import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'github_service.dart';

const String appVersion = '0.2.11';

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

  static Future<String> read() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/my_latest_artifacts.log');
      if (!await file.exists()) return '';
      return await file.readAsString();
    } catch (error, stack) {
      return '로그 파일을 읽지 못했습니다.\\n$error\\n$stack';
    }
  }
}

class DiagnosticLogPage extends StatefulWidget {
  const DiagnosticLogPage({super.key});

  @override
  State<DiagnosticLogPage> createState() => _DiagnosticLogPageState();
}

class _DiagnosticLogPageState extends State<DiagnosticLogPage> {
  String _content = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final content = await DiagnosticLog.read();
    if (!mounted) return;
    setState(() {
      _content = content;
      _loading = false;
    });
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _content));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('진단 로그를 복사했습니다.')),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('진단 로그'),
      actions: [
        IconButton(
          tooltip: '새로고침',
          onPressed: _reload,
          icon: const Icon(Icons.refresh),
        ),
        IconButton(
          tooltip: '로그 복사',
          onPressed: _content.isEmpty ? null : _copy,
          icon: const Icon(Icons.copy),
        ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _content.isEmpty
            ? const Center(child: Text('아직 기록된 진단 로그가 없습니다.'))
            : SelectionArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    _content,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ),
              ),
  );
}

const List<String> supportedPlatforms = [
  'GitHub',
  'GitLab',
  'Bitbucket',
  'Azure DevOps',
  'Jenkins',
  'SourceForge',
  'Gitea',
  'Codeberg',
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


String _formattedToday() {
  final now = DateTime.now();
  final year = now.year.toString().padLeft(4, '0');
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}


Widget _platformMark(String platform, {double size = 24}) {
  final Color color;
  final IconData icon;
  switch (platform) {
    case 'GitHub':
      color = const Color(0xFF24292F);
      icon = Icons.code;
      break;
    case 'GitLab':
      color = const Color(0xFFFC6D26);
      icon = Icons.merge_type;
      break;
    case 'Bitbucket':
      color = const Color(0xFF0052CC);
      icon = Icons.call_split;
      break;
    case 'Azure DevOps':
      color = const Color(0xFF0078D4);
      icon = Icons.cloud_queue;
      break;
    case 'Jenkins':
      color = const Color(0xFFD33833);
      icon = Icons.build_circle_outlined;
      break;
    case 'SourceForge':
      color = const Color(0xFFFF6600);
      icon = Icons.source_outlined;
      break;
    case 'Gitea':
      color = const Color(0xFF609926);
      icon = Icons.fork_right;
      break;
    default:
      color = const Color(0xFF1685A9);
      icon = Icons.code;
  }
  return Container(
    width: size + 12,
    height: size + 12,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Icon(icon, color: color, size: size),
  );
}

Widget _loginAppBarTitle(String platform) => Row(
  children: [
    Image.asset('my latest artifacts icon.jpg',
        width: 30, height: 30, fit: BoxFit.contain),
    const SizedBox(width: 8),
    const Flexible(
      child: Text('My Latest Artifacts',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
    ),
    const SizedBox(width: 14),
    _platformMark(platform, size: 22),
    const SizedBox(width: 7),
    Flexible(
      child: Text(platform,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
    ),
  ],
);

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.platform});
  final String platform;

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
    _showNotice('${widget.platform} 공식 인증 연동이 아직 설정되지 않았습니다.');
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
    if (widget.platform == 'GitHub') return const GithubLoginPage();
    return Scaffold(
      appBar: AppBar(title: _loginAppBarTitle(widget.platform)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_sync_outlined, size: 52),
                    const SizedBox(height: 16),
                    Text('${widget.platform} 공식 계정 연결',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    const Text(
                      '이 플랫폼의 공식 인증 및 아티팩트 API 연동은 아직 구현 중입니다. 비밀번호나 토큰을 이 화면에 입력하지 마세요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54, height: 1.5),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('닫기'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

  }
}


class GithubLoginPage extends StatefulWidget {
  const GithubLoginPage({super.key});
  @override
  State<GithubLoginPage> createState() => _GithubLoginPageState();
}

class _GithubLoginPageState extends State<GithubLoginPage> {
  bool _busy = false;
  String _status = 'GitHub 공식 Device Flow로 안전하게 연결합니다.';
  String? _userCode;

  Future<void> _openInstallPage() async {
    final uri = Uri.parse('https://github.com/apps/my-latest-artifacts/installations/new');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      _notice('브라우저를 열지 못했습니다. GitHub에서 My Latest Artifacts 앱을 설치해 주세요.');
    }
  }

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _connect() async {
    if (_busy) return;
    setState(() { _busy = true; _status = 'GitHub 인증을 준비하고 있습니다.'; _userCode = null; });
    await DiagnosticLog.write('github_connect_started', 'GitHub connection flow started');
    try {
      if (!await GithubAuthService.isSignedIn) {
        final code = await GithubAuthService.requestDeviceCode();
        await DiagnosticLog.write('github_device_code_received', 'Device code received; code value excluded');
        if (!mounted) return;
        setState(() { _userCode = code.userCode; _status = '브라우저에서 GitHub에 로그인한 뒤 아래 코드를 입력해 주세요.'; });
        await launchUrl(Uri.parse(code.verificationUri), mode: LaunchMode.externalApplication);
        await DiagnosticLog.write('github_verification_opened', 'GitHub verification page opened');
        await GithubAuthService.pollForToken(code);
        await DiagnosticLog.write('github_auth_completed', 'GitHub device authorization completed');
      }
      if (!mounted) return;
      setState(() => _status = '저장소와 실제 Actions 아티팩트를 조회하고 있습니다.');
      await DiagnosticLog.write('github_artifact_fetch_started', 'Fetching repositories and successful artifacts');
      final repositories = await GithubAuthService.fetchRepositories();
      await DiagnosticLog.write('github_repositories_fetch_completed', 'count=${repositories.length}');
      final prefs = await SharedPreferences.getInstance();
      final oldIds = (prefs.getStringList('github_selected_artifact_ids') ?? []).toSet();
      final oldProjects = (prefs.getStringList('github_selected_projects') ?? []).toSet();
      final selectedProjects = oldProjects.isNotEmpty
          ? oldProjects
          : <String>{};
      if (!mounted) return;
      final selected = await Navigator.of(context).push<Set<String>>(
        MaterialPageRoute(builder: (_) => ArtifactSelectionPage(
          platform: 'GitHub', artifacts: const [], projects: repositories,
          initiallySelectedIds: selectedProjects,
        )),
      );
      if (selected == null) return;
      await prefs.setStringList('github_selected_projects', selected.toList());
      if (selected.isEmpty) {
        await prefs.setStringList('github_selected_artifact_ids', []);
        await prefs.setString('github_artifacts_cache', '[]');
        await DiagnosticLog.write('github_artifacts_selected', 'count=0');
        if (mounted) Navigator.pop(context);
        return;
      }
      if (!mounted) return;
      setState(() => _status = '선택한 ${selected.length}개 프로젝트의 성공한 아티팩트만 조회하고 있습니다.');
      await DiagnosticLog.write('github_selected_artifact_fetch_started', 'repositories=${selected.length}');
      final artifacts = await GithubAuthService.fetchArtifacts(repositories: selected.toList());
      await DiagnosticLog.write('github_artifact_fetch_completed', 'count=${artifacts.length}');
      await prefs.setStringList('github_selected_artifact_ids', artifacts.map((a) => a.id).toList());
      await prefs.setString('github_artifacts_cache',
        jsonEncode(artifacts.map((a) => a.toJson()).toList()));
      await DiagnosticLog.write('github_artifacts_selected', 'count=${selected.length}');
      if (!mounted) return;
      setState(() => _status = '조회가 완료되었습니다. 메인 화면에 결과를 표시합니다.');
      Navigator.pop(context);
    } catch (error, stack) {
      await DiagnosticLog.write('github_connection_failed', error.toString(), stack.toString());
      if (mounted) setState(() => _status = '연결 또는 조회에 실패했습니다. GitHub 앱 설치와 저장소 권한을 확인해 주세요. ${error.toString()}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: _loginAppBarTitle('GitHub'),
      actions: [
        IconButton(
          tooltip: '진단 로그',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const DiagnosticLogPage()),
          ),
          icon: const Icon(Icons.receipt_long_outlined),
        ),
      ],
    ),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.account_tree_outlined, size: 54),
                const SizedBox(height: 14),
                const Text('GitHub 로그인', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                const Text('비밀번호를 앱에 입력하지 않습니다. GitHub 공식 인증 페이지에서 승인해 주세요.', textAlign: TextAlign.center),
                const SizedBox(height: 18),
                if (_userCode != null) SelectableText(_userCode!, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 3)),
                Text(_status, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 20),
                SizedBox(width: double.infinity, child: FilledButton(
                  onPressed: _busy ? null : _connect,
                  child: _busy ? const SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2)) : Text(_userCode == null ? 'GitHub 로그인 및 아티팩트 조회' : '인증 완료 대기 중'),
                )),
                const SizedBox(height: 8),
                TextButton(onPressed: _busy ? null : _openInstallPage, child: const Text('GitHub 앱 설치 / 저장소 권한 설정')),
                const SizedBox(height: 8),
                const Text('처음 한 번 승인하면 인증 토큰은 기기의 보안 저장소에 보관됩니다. GitHub 앱이 설치된 저장소의 Actions 권한이 있어야 아티팩트를 조회할 수 있습니다.', style: TextStyle(fontSize: 12, color: Colors.black54), textAlign: TextAlign.center),
              ]),
            ),
          ),
        ),
      ),
    ),
  );
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
      if (platform == 'GitHub') {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('github_selected_artifact_ids');
        await prefs.remove('github_selected_projects');
        await prefs.remove('github_artifacts_cache');
      }
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
            tooltip: '진단 로그',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const DiagnosticLogPage()),
            ),
            icon: const Icon(Icons.receipt_long_outlined),
          ),
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
        label: const Text('새 프로젝트'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('프로젝트별 최신 성공 아티팩트',
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
        Text('선택한 프로젝트가 없습니다.',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        SizedBox(height: 7),
        Text('＋ 새 프로젝트를 눌러 개발 플랫폼을 추가하세요.',
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
    if (platform == 'GitHub') return GithubAuthService.isSignedIn;
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
    if (platform == 'GitHub') {
      await GithubAuthService.clearSession();
      return;
    }
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
  late String activePlatform;

  @override
  void initState() {
    super.initState();
    activePlatform = widget.platforms.first;
  }

  Future<void> _openPlatform(String platform) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => LoginPage(platform: platform)),
    );
    if (mounted) setState(() {});
  }

  Future<List<ArtifactItem>> _loadSelectedArtifacts(String platform) async {
    if (platform != 'GitHub') return <ArtifactItem>[];
    final prefs = await SharedPreferences.getInstance();
    final selectedProjects = (prefs.getStringList('github_selected_projects') ?? []).toSet();
    if (selectedProjects.isEmpty) return <ArtifactItem>[];
    if (await GithubAuthService.isSignedIn) {
      try {
        final fresh = await GithubAuthService.fetchArtifacts(
          repositories: selectedProjects.toList(),
        );
        await prefs.setString('github_artifacts_cache',
            jsonEncode(fresh.map((a) => a.toJson()).toList()));
      } catch (error, stack) {
        await DiagnosticLog.write('github_auto_refresh_failed', error.toString(), stack.toString());
      }
    }
    final raw = prefs.getString('github_artifacts_cache');
    if (raw == null) return <ArtifactItem>[];
    final decoded = jsonDecode(raw) as List<dynamic>;
    final all = decoded.map((e) => GithubArtifact.fromJson(e as Map<String, dynamic>)).toList();
    final latestByProject = <String, GithubArtifact>{};
    for (final artifact in all.where((a) => selectedProjects.contains(a.repository))) {
      final old = latestByProject[artifact.repository];
      if (old == null || artifact.createdAt.isAfter(old.createdAt)) {
        latestByProject[artifact.repository] = artifact;
      }
    }
    return selectedProjects.map((project) {
      final artifact = latestByProject[project];
      if (artifact == null) {
        return ArtifactItem(
          id: '', title: '', platform: 'GitHub', project: project,
          description: '', createdAt: DateTime.fromMillisecondsSinceEpoch(0),
          hasArtifact: false,
        );
      }
      return ArtifactItem(
        id: artifact.id, title: artifact.name, platform: 'GitHub',
        project: artifact.repository, description: artifact.description,
        createdAt: artifact.createdAt,
      );
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> _downloadArtifact(ArtifactItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('아티팩트 다운로드'),
        content: Text('${item.title}\\n${item.project}\\n\\n다운로드하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('확인')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final artifact = GithubArtifact(
        id: item.id, name: item.title, repository: item.project,
        createdAt: item.createdAt, description: item.description,
      );
      final file = await GithubAuthService.download(artifact);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('다운로드 완료: ${file.path}'), duration: const Duration(seconds: 6)),
      );
    } catch (error, stack) {
      await DiagnosticLog.write('artifact_download_failed', error.toString(), stack.toString());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('다운로드 실패: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final platforms = widget.platforms;
    if (!platforms.contains(activePlatform)) activePlatform = platforms.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: platforms.map((platform) {
              final selected = activePlatform == platform;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  selected: selected,
                  avatar: _platformMark(platform, size: 16),
                  label: Text(platform),
                  onSelected: (_) => setState(() => activePlatform = platform),
                  selectedColor: const Color(0xFFDCE8FF),
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: selected ? const Color(0xFF4267B2) : const Color(0xFFD7DDE5),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 18),
        Expanded(
          child: activePlatform == 'GitHub'
              ? FutureBuilder<List<ArtifactItem>>(
                  key: ValueKey(activePlatform),
                  future: _loadSelectedArtifacts(activePlatform),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final items = snapshot.data ?? const <ArtifactItem>[];
                    if (items.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inventory_2_outlined, size: 56, color: Color(0xFF9AA4B2)),
                              SizedBox(height: 14),
                              Text('표시할 아티팩트가 없습니다.',
                                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                              SizedBox(height: 8),
                              Text('체크한 프로젝트에 성공한 빌드의 아티팩트가 생성되면 여기에 표시됩니다.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.black54, height: 1.5)),
                              SizedBox(height: 12),
                              Text('아래 버튼에서 GitHub 계정을 연결하고 확인할 프로젝트를 체크해 주세요.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.black54)),
                              const SizedBox(height: 14),
                              OutlinedButton.icon(
                                onPressed: () => _openPlatform('GitHub'),
                                icon: const Icon(Icons.folder_open_outlined),
                                label: const Text('GitHub 프로젝트 선택'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return ListView(
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text('프로젝트별 가장 최근 성공 빌드의 아티팩트',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        ...items.map((item) => Card(
                          elevation: 0,
                          color: Colors.white,
                          child: ListTile(
                            title: Text(item.project,
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text(item.hasArtifact
                                ? '${item.title} · ${item.createdAt.toLocal()}'
                                : '성공한 빌드의 아티팩트가 없습니다.'),
                            trailing: Icon(item.hasArtifact
                                ? Icons.download_outlined
                                : Icons.info_outline, color: Colors.black45),
                            onTap: item.hasArtifact ? () => _downloadArtifact(item) : null,
                          ),
                        )),
                      ],
                    );
                  },
                )
              : Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _platformMark(activePlatform, size: 38),
                      const SizedBox(height: 14),
                      Text('$activePlatform 연동 준비 중',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      const Text('현재 이 플랫폼의 로그인 및 아티팩트 조회 기능은 아직 연결되지 않았습니다.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black54)),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: () => _openPlatform(activePlatform),
                        icon: const Icon(Icons.login),
                        label: Text('$activePlatform 연결'),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
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


/// Intermediate selection screen. The list is populated by platform API adapters.
class ArtifactItem {
  const ArtifactItem({required this.id, required this.title, required this.platform, required this.project, required this.description, required this.createdAt, this.downloadUrl, this.hasArtifact = true});
  final String id;
  final String title;
  final String platform;
  final String project;
  final String description;
  final DateTime createdAt;
  final String? downloadUrl;
  final bool hasArtifact;
}

class ArtifactSelectionPage extends StatefulWidget {
  const ArtifactSelectionPage({super.key, required this.platform, required this.artifacts, required this.projects, required this.initiallySelectedIds});
  final String platform;
  final List<ArtifactItem> artifacts;
  final List<String> projects;
  final Set<String> initiallySelectedIds;
  @override
  State<ArtifactSelectionPage> createState() => _ArtifactSelectionPageState();
}

class _ArtifactSelectionPageState extends State<ArtifactSelectionPage> {
  late Set<String> selectedIds;
  @override
  void initState() {
    super.initState();
    selectedIds = Set<String>.from(widget.initiallySelectedIds);
  }

  @override
  Widget build(BuildContext context) {
    final artifacts = [...widget.artifacts]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final projects = [...widget.projects]..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final latestByProject = <String, ArtifactItem>{};
    for (final artifact in artifacts) {
      latestByProject.putIfAbsent(artifact.project, () => artifact);
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.platform} 프로젝트 선택'),
        actions: [
          TextButton(
            onPressed: () => setState(() {
              if (selectedIds.length == projects.length) {
                selectedIds.clear();
              } else {
                selectedIds..clear()..addAll(projects);
              }
            }),
            child: Text(selectedIds.length == projects.length ? '전체 해제' : '전체 선택'),
          ),
        ],
      ),
      body: projects.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Text('GitHub 저장소가 없습니다. 계정의 저장소 접근 권한을 확인해 주세요.',
                    textAlign: TextAlign.center),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: projects.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final project = projects[index];
                final latest = latestByProject[project];
                return Card(
                  elevation: 0,
                  color: Colors.white,
                  child: CheckboxListTile(
                    value: selectedIds.contains(project),
                    onChanged: (checked) => setState(() {
                      if (checked == true) { selectedIds.add(project); } else { selectedIds.remove(project); }
                    }),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(project, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(latest == null
                          ? '선택 후 성공한 빌드의 아티팩트를 조회합니다.'
                          : '${latest.title} · ${latest.createdAt.toLocal()}'),
                    ),
                    isThreeLine: false,
                  ),
                );
              },
            ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton(onPressed: () => Navigator.pop(context, selectedIds), child: Text('선택 완료 (${selectedIds.length})')),
      ),
    );
  }
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
            '선택한 사이트는 다음 실행 때도 유지됩니다. 실제 연동은 GitHub부터 순서대로 지원합니다.',
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
        child: const Text('추가'),
      ),
    ],
  );
}
