import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  static Future<void> write(String event, String message,
      [String? stack]) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/my_latest_artifacts.log');
      final line = jsonEncode({
        'time': DateTime.now().toUtc().toIso8601String(),
        'version': '0.1.0',
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
    } catch (_) {
      // Diagnostics must never interrupt normal app usage.
    }
  }
}

class SavedProject {
  const SavedProject({required this.name, required this.provider, required this.url});
  final String name;
  final String provider;
  final String url;

  Map<String, dynamic> toJson() => {'name': name, 'provider': provider, 'url': url};
  factory SavedProject.fromJson(Map<String, dynamic> json) => SavedProject(
    name: json['name'] as String,
    provider: json['provider'] as String,
    url: json['url'] as String,
  );
}

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
  List<SavedProject> projects = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadProjects();
    DiagnosticLog.write('app_started', 'Application launched');
  }

  Future<void> _loadProjects() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('projects') ?? [];
    final loaded = raw.map((e) =>
        SavedProject.fromJson(jsonDecode(e) as Map<String, dynamic>)).toList();
    if (!mounted) return;
    setState(() {
      projects = loaded;
      loading = false;
    });
  }

  Future<void> _addProject() async {
    final result = await showDialog<SavedProject>(
      context: context,
      builder: (context) => const AddProjectDialog(),
    );
    if (result == null) return;
    final updated = [...projects, result];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'projects', updated.map((p) => jsonEncode(p.toJson())).toList());
    if (!mounted) return;
    setState(() => projects = updated);
    DiagnosticLog.write('project_added', '${result.provider}: ${result.url}');
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'My Latest Artifacts',
      applicationVersion: '0.1.0',
      applicationIcon: Image.asset('js_logo.png', width: 64, height: 64,
          fit: BoxFit.contain),
      children: const [
        SizedBox(height: 8),
        Text('Ryoo jaesang & 최피디'),
        SizedBox(height: 8),
        Text('여러 개발 플랫폼의 최신 빌드 결과물을 한곳에서 확인합니다.'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...projects]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Latest Artifacts',
            style: TextStyle(fontWeight: FontWeight.w700)),
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
        onPressed: _addProject,
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
                    child: sorted.isEmpty
                        ? _EmptyState(onAdd: _addProject)
                        : ListView.separated(
                            itemCount: sorted.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final project = sorted[index];
                              return Card(
                                elevation: 0,
                                color: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: const BorderSide(color: Color(0xFFE7EAF0)),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(project.name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 16)),
                                      const SizedBox(height: 5),
                                      Text('${project.provider} · ${project.url}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              color: Colors.black54, fontSize: 12)),
                                      const Divider(height: 22),
                                      const Text('최신 아티팩트 정보를 아직 가져오지 못했습니다.',
                                          style: TextStyle(color: Colors.black54)),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.inventory_2_outlined, size: 58, color: Color(0xFF9AA4B2)),
        const SizedBox(height: 14),
        const Text('등록된 프로젝트가 없습니다',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 7),
        const Text('프로젝트를 추가하면 최신 아티팩트를\n이 화면에서 확인할 수 있습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54, height: 1.5)),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: const Text('첫 프로젝트 추가'),
        ),
      ],
    ),
  );
}

class AddProjectDialog extends StatefulWidget {
  const AddProjectDialog({super.key});

  @override
  State<AddProjectDialog> createState() => _AddProjectDialogState();
}

class _AddProjectDialogState extends State<AddProjectDialog> {
  final nameController = TextEditingController();
  final urlController = TextEditingController();
  String provider = 'GitHub';

  @override
  void dispose() {
    nameController.dispose();
    urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('프로젝트 추가'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            value: provider,
            decoration: const InputDecoration(labelText: '플랫폼'),
            items: const ['GitHub', 'GitLab', 'Bitbucket', 'Azure DevOps', 'Jenkins']
                .map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (v) => setState(() => provider = v ?? provider),
          ),
          const SizedBox(height: 12),
          TextField(controller: nameController,
              decoration: const InputDecoration(labelText: '프로젝트 이름')),
          const SizedBox(height: 12),
          TextField(controller: urlController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(labelText: '프로젝트 주소')),
        ],
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context),
          child: const Text('취소')),
      FilledButton(
        onPressed: () {
          final name = nameController.text.trim();
          final url = urlController.text.trim();
          if (name.isEmpty || Uri.tryParse(url)?.hasScheme != true) return;
          Navigator.pop(context,
              SavedProject(name: name, provider: provider, url: url));
        },
        child: const Text('추가'),
      ),
    ],
  );
}
