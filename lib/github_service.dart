import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

class GithubArtifact {
  const GithubArtifact({required this.id,required this.name,required this.repository,required this.createdAt,required this.description});
  final String id,name,repository,description;
  final DateTime createdAt;
  Map<String,dynamic> toJson()=>{'id':id,'name':name,'repository':repository,'createdAt':createdAt.toIso8601String(),'description':description};
  factory GithubArtifact.fromJson(Map<String,dynamic> j)=>GithubArtifact(id:j['id'] as String,name:j['name'] as String,repository:j['repository'] as String,createdAt:DateTime.parse(j['createdAt'] as String),description:j['description'] as String? ?? '');
}
class GithubDeviceCode {
  const GithubDeviceCode(this.deviceCode,this.userCode,this.verificationUri,this.interval,this.expiresIn);
  final String deviceCode,userCode,verificationUri;
  final int interval,expiresIn;
}
class GithubAuthService {
  GithubAuthService._();
  static const clientId='Iv23lidL7sPMStRBo44f';
  static const _storage=FlutterSecureStorage();
  static const _access='github_access_token',_refresh='github_refresh_token',_expiry='github_access_expiry';
  static Future<bool> get isSignedIn async=>(await _storage.read(key:_access))?.isNotEmpty ?? false;
  static Future<void> clearSession() async {await _storage.delete(key:_access);await _storage.delete(key:_refresh);await _storage.delete(key:_expiry);}
  static Future<GithubDeviceCode> requestDeviceCode() async {
    final j=await _post(Uri.https('github.com','/login/device/code'),{'client_id':clientId,'scope':'offline_access'});
    return GithubDeviceCode(j['device_code'] as String,j['user_code'] as String,j['verification_uri'] as String,(j['interval'] as num?)?.toInt()??5,(j['expires_in'] as num?)?.toInt()??900);
  }
  static Future<void> pollForToken(GithubDeviceCode code) async {
    final end=DateTime.now().add(Duration(seconds:code.expiresIn));var delay=code.interval;
    while(DateTime.now().isBefore(end)){
      await Future<void>.delayed(Duration(seconds:delay));
      final j=await _post(Uri.https('github.com','/login/oauth/access_token'),{'client_id':clientId,'device_code':code.deviceCode,'grant_type':'urn:ietf:params:oauth:grant-type:device_code'},allowError:true);
      final error=j['error'] as String?;
      if(error=='authorization_pending')continue;
      if(error=='slow_down'){delay+=5;continue;}
      if(error=='access_denied')throw Exception('GitHub 인증이 취소되었습니다.');
      if(error=='expired_token')throw Exception('인증 코드가 만료되었습니다. 다시 시도해 주세요.');
      final token=j['access_token'] as String?;
      if(token==null||token.isEmpty)throw Exception('GitHub 액세스 토큰을 받지 못했습니다.');
      await _storage.write(key:_access,value:token);
      if(j['refresh_token'] is String)await _storage.write(key:_refresh,value:j['refresh_token'] as String);
      final seconds=(j['expires_in'] as num?)?.toInt()??28800;
      await _storage.write(key:_expiry,value:DateTime.now().add(Duration(seconds:seconds)).toIso8601String());return;
    }
    throw Exception('인증 대기 시간이 만료되었습니다. 다시 로그인해 주세요.');
  }
  static Future<String> _token() async {
    var token=await _storage.read(key:_access);if(token==null||token.isEmpty)throw Exception('GitHub 로그인이 필요합니다.');
    final expiry=DateTime.tryParse(await _storage.read(key:_expiry)??'');
    if(expiry!=null&&DateTime.now().isAfter(expiry.subtract(const Duration(minutes:2)))){
      final refresh=await _storage.read(key:_refresh);
      if(refresh==null||refresh.isEmpty){await clearSession();throw Exception('로그인이 만료되었습니다. 다시 인증해 주세요.');}
      Map<String,dynamic> j;
      try {
        j=await _post(Uri.https('github.com','/login/oauth/access_token'),{'client_id':clientId,'grant_type':'refresh_token','refresh_token':refresh});
      } catch (_) {
        await clearSession();
        rethrow;
      }
      token=j['access_token'] as String?;
      if(token==null||token.isEmpty){await clearSession();throw Exception('인증 갱신에 실패했습니다. 다시 로그인해 주세요.');}
      await _storage.write(key:_access,value:token);
      if(j['refresh_token'] is String)await _storage.write(key:_refresh,value:j['refresh_token'] as String);
      final seconds=(j['expires_in'] as num?)?.toInt()??28800;
      await _storage.write(key:_expiry,value:DateTime.now().add(Duration(seconds:seconds)).toIso8601String());
    }return token;
  }
  static Future<Map<String,dynamic>> _get(Uri uri) async {
    final c=HttpClient();
    try{
      final r=await c.getUrl(uri);r.headers.set(HttpHeaders.authorizationHeader,'Bearer ${await _token()}');r.headers.set(HttpHeaders.acceptHeader,'application/vnd.github+json');r.headers.set('X-GitHub-Api-Version','2022-11-28');r.headers.set(HttpHeaders.userAgentHeader,'My-Latest-Artifacts');
      final res=await r.close();final body=await utf8.decodeStream(res);
      if(res.statusCode<200||res.statusCode>=300){
        if(res.statusCode==401) await clearSession();
        var msg='요청을 처리하지 못했습니다.';
        try{msg=(jsonDecode(body) as Map<String,dynamic>)['message'] as String? ?? msg;}catch(_){}
        throw HttpException('GitHub API 오류 (${res.statusCode}): $msg');
      }
      return jsonDecode(body) as Map<String,dynamic>;
    }finally{c.close(force:true);}
  }
  static Future<List<dynamic>> _getList(Uri uri) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer ${await _token()}');
      request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      request.headers.set('X-GitHub-Api-Version', '2022-11-28');
      request.headers.set(HttpHeaders.userAgentHeader, 'My-Latest-Artifacts');
      final response = await request.close();
      final body = await utf8.decodeStream(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (response.statusCode == 401) await clearSession();
        throw HttpException('GitHub 저장소 조회 오류 (${response.statusCode})');
      }
      return jsonDecode(body) as List<dynamic>;
    } finally {
      client.close(force: true);
    }
  }

  static Future<List<String>> fetchRepositories() async {
    await _get(Uri.https('api.github.com','/user'));
    final names=<String>[];
    for(var page=1;page<=20;page++){
      final rows=await _getList(Uri.https('api.github.com','/user/repos',{'per_page':'100','sort':'updated','page':'$page'}));
      for(final raw in rows){
        final row=raw as Map<String,dynamic>;
        final full=row['full_name'] as String?;
        if(full!=null && full.isNotEmpty) names.add(full);
      }
      if(rows.length<100)break;
    }
    names.sort((a,b)=>a.toLowerCase().compareTo(b.toLowerCase()));
    return names;
  }

  static Future<List<GithubArtifact>> fetchArtifacts({List<String>? repositories}) async {
    await _get(Uri.https('api.github.com', '/user'));
    final repos = <Map<String, dynamic>>[];
    if (repositories == null) {
      for (var page = 1; page <= 20; page++) {
        final rows = await _getList(Uri.https('api.github.com', '/user/repos',
            {'per_page': '100', 'sort': 'updated', 'page': '$page'}));
        repos.addAll(rows.cast<Map<String, dynamic>>());
        if (rows.length < 100) break;
      }
    } else {
      for (final full in repositories) {
        final parts = full.split('/');
        if (parts.length != 2) continue;
        repos.add({
          'full_name': full,
          'name': parts[1],
          'owner': {'login': parts[0]}
        });
      }
    }

    // Fetch a repository's successful runs once, rather than requesting each
    // artifact's workflow run individually. This cuts API calls substantially.
    final out = <GithubArtifact>[];
    var nextIndex = 0;
    var inaccessibleRepositories = 0;
    Future<void> worker() async {
      while (true) {
        final index = nextIndex++;
        if (index >= repos.length) return;
        final repo = repos[index];
        final owner = repo['owner']?['login'] as String? ?? '';
        final name = repo['name'] as String? ?? '';
        final full = repo['full_name'] as String? ?? '';
        if (owner.isEmpty || name.isEmpty || full.isEmpty) continue;
        try {
          final successfulRunIds = <int>{};
          for (var page = 1; page <= 20; page++) {
            final runsResponse = await _get(Uri.https(
              'api.github.com',
              '/repos/$owner/$name/actions/runs',
              {'status': 'success', 'per_page': '100', 'page': '$page'},
            ));
            final runs = runsResponse['workflow_runs'] as List<dynamic>? ?? [];
            for (final raw in runs) {
              final run = raw as Map<String, dynamic>;
              final id = (run['id'] as num?)?.toInt();
              if (id != null) successfulRunIds.add(id);
            }
            if (runs.length < 100) break;
          }

          GithubArtifact? latestForRepository;
          for (var page = 1; page <= 20; page++) {
            final response = await _get(Uri.https(
              'api.github.com',
              '/repos/$owner/$name/actions/artifacts',
              {'per_page': '100', 'page': '$page'},
            ));
            final rows = response['artifacts'] as List<dynamic>? ?? [];
            for (final raw in rows) {
              final artifact = raw as Map<String, dynamic>;
              if (artifact['expired'] == true) continue;
              final date = DateTime.tryParse(artifact['created_at'] as String? ?? '');
              final workflow = artifact['workflow_run'] as Map<String, dynamic>?;
              final runId = (workflow?['id'] as num?)?.toInt();
              if (date == null || runId == null || !successfulRunIds.contains(runId)) continue;
              final candidate = GithubArtifact(
                id: '$full:${artifact['id']}',
                name: artifact['name'] as String? ?? 'Artifact',
                repository: full,
                createdAt: date,
                description: '성공한 GitHub Actions 아티팩트',
              );
              if (latestForRepository == null ||
                  candidate.createdAt.isAfter(latestForRepository.createdAt)) {
                latestForRepository = candidate;
              }
            }
            if (rows.length < 100) break;
          }
          if (latestForRepository != null) out.add(latestForRepository);
        } on HttpException catch (error) {
          if (error.message.contains('(403)') || error.message.contains('(404)')) {
            inaccessibleRepositories++;
            continue;
          }
          rethrow;
        }
      }
    }

    // Keep a small concurrency limit to speed up multi-project lookups without
    // overwhelming GitHub's API rate limits.
    final workerCount = repos.isEmpty ? 1 : (repos.length < 4 ? repos.length : 4);
    await Future.wait(List.generate(workerCount, (_) => worker()));
    if (out.isEmpty && inaccessibleRepositories > 0) {
      throw Exception('아티팩트를 읽을 수 있는 저장소가 없습니다. GitHub 앱 설치 대상과 Actions 읽기 권한을 확인해 주세요.');
    }
    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }
  static Future<File> download(GithubArtifact artifact) async {
    final parts=artifact.id.split(':');final repo=parts.first.split('/');if(parts.length!=2||repo.length!=2)throw Exception('아티팩트 정보가 올바르지 않습니다.');
    final c=HttpClient();
    try{
      final req=await c.getUrl(Uri.https('api.github.com','/repos/${repo[0]}/${repo[1]}/actions/artifacts/${parts[1]}/zip'));
      req.headers.set(HttpHeaders.authorizationHeader,'Bearer ${await _token()}');req.headers.set(HttpHeaders.acceptHeader,'application/vnd.github+json');req.headers.set('X-GitHub-Api-Version','2022-11-28');req.headers.set(HttpHeaders.userAgentHeader,'My-Latest-Artifacts');
      final res=await req.close();if(res.statusCode<200||res.statusCode>=300)throw HttpException('다운로드 오류 (${res.statusCode})');
      final bytes=await res.fold<List<int>>(<int>[],(all,chunk)=>all..addAll(chunk));final dir=await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();final safe=artifact.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'),'_');final file=File('${dir.path}/$safe-${parts[1]}.zip');await file.writeAsBytes(bytes,flush:true);return file;
    }finally{c.close(force:true);}
  }
  static Future<Map<String,dynamic>> _post(Uri uri,Map<String,String> fields,{bool allowError=false}) async {
    final c=HttpClient();
    try{
      final req=await c.postUrl(uri);req.headers.contentType=ContentType('application','x-www-form-urlencoded',charset:'utf-8');req.headers.set(HttpHeaders.acceptHeader,'application/json');
      req.write(fields.entries.map((e)=>'${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}').join('&'));
      final res=await req.close();final body=await utf8.decodeStream(res);if(res.statusCode<200||res.statusCode>=300)throw HttpException('GitHub 인증 오류 (${res.statusCode})');
      final j=jsonDecode(body) as Map<String,dynamic>;if(!allowError&&j['error']!=null)throw Exception(j['error_description']??j['error']);return j;
    }finally{c.close(force:true);}
  }
}
