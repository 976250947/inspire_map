import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../data/models/poi_model.dart';

class POIFetchResult {
  final List<POIModel> pois;
  final List<POIClusterModel> clusters;

  const POIFetchResult({this.pois = const [], this.clusters = const []});

  bool get isEmpty => pois.isEmpty && clusters.isEmpty;
  bool get isNotEmpty => !isEmpty;
  int get total => pois.length + clusters.length;
}

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late final Dio _dio;

  ApiService._internal() {
    const hostOverride = String.fromEnvironment('BACKEND_HOST');
    String baseUrl;
    if (hostOverride.isNotEmpty) {
      baseUrl = 'http://$hostOverride:8001';
    } else if (!kIsWeb && Platform.isAndroid) {
      baseUrl = 'http://10.0.2.2:8001';
    } else {
      baseUrl = 'http://127.0.0.1:8001';
    }

    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = getAuthToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        // ignore: avoid_print
        print('[API] ${options.method} ${options.path}');
        return handler.next(options);
      },
      onResponse: (response, handler) {
        final raw = response.data;
        if (raw is Map<String, dynamic> &&
            raw.containsKey('code') &&
            raw.containsKey('data')) {
          response.data = raw['data'];
        }
        return handler.next(response);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401 &&
            error.requestOptions.path != '/api/v1/users/refresh-token') {
          final refreshed = await _tryRefreshToken();
          if (refreshed) {
            final opts = error.requestOptions;
            opts.headers['Authorization'] = 'Bearer ${getAuthToken()}';
            try {
              final retryResponse = await _dio.fetch(opts);
              return handler.resolve(retryResponse);
            } on DioException catch (retryError) {
              return handler.next(retryError);
            }
          }
        }
        // ignore: avoid_print
        print('[API Error] ${error.type}: ${error.message}');
        return handler.next(error);
      },
    ));
  }

  bool _isRefreshing = false;

  Future<bool> _tryRefreshToken() async {
    if (_isRefreshing) return false;
    _isRefreshing = true;
    try {
      final currentToken = getAuthToken();
      if (currentToken == null) return false;

      final response = await _dio.post(
        '/api/v1/users/refresh-token',
        options: Options(
          headers: {'Authorization': 'Bearer $currentToken'},
        ),
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final newToken = data['access_token'] as String?;
        if (newToken != null) {
          await saveAuthToken(newToken);
          return true;
        }
      }
      return false;
    } catch (_) {
      await clearAuthToken();
      return false;
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> saveAuthToken(String token) async {
    final box = Hive.box('user_prefs');
    await box.put('auth_token', token);
  }

  String? getAuthToken() {
    final box = Hive.box('user_prefs');
    return box.get('auth_token') as String?;
  }

  Future<void> clearAuthToken() async {
    final box = Hive.box('user_prefs');
    await box.delete('auth_token');
  }

  void setBaseUrl(String url) {
    _dio.options.baseUrl = url;
  }

  Future<Map<String, dynamic>> register({
    required String phone,
    required String password,
    String? nickname,
  }) async {
    try {
      final response = await _dio.post(
        '/api/v1/users/register',
        data: {
          'phone': phone,
          'password': password,
          if (nickname != null) 'nickname': nickname,
        },
      );
      final data = response.data as Map<String, dynamic>;
      final token = data['access_token'] as String?;
      if (token != null) await saveAuthToken(token);
      return data;
    } on DioException catch (e) {
      // ignore: avoid_print
      print('[ApiService] 注册失败: ${e.response?.data}');
      return {'error': _extractErrorMessage(e, '注册失败')};
    }
  }

  Future<Map<String, dynamic>> login({
    required String phone,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '/api/v1/users/login',
        data: {
          'phone': phone,
          'password': password,
        },
      );
      final data = response.data as Map<String, dynamic>;
      final token = data['access_token'] as String?;
      if (token != null) await saveAuthToken(token);
      return data;
    } on DioException catch (e) {
      // ignore: avoid_print
      print('[ApiService] 登录失败: ${e.response?.data}');
      return {'error': _extractErrorMessage(e, '登录失败')};
    }
  }

  String _extractErrorMessage(DioException e, String fallback) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.connectionError) {
      return '无法连接服务端，请确认后端已经启动';
    }
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final detail = data['detail'];
      if (detail is String) return detail;
    }
    return fallback;
  }

  Future<Map<String, dynamic>?> fetchCurrentUser() async {
    try {
      final response = await _dio.get('/api/v1/users/me');
      return response.data as Map<String, dynamic>;
    } on DioException {
      return null;
    }
  }

  Future<Map<String, dynamic>?> publishPost({
    required String content,
    String? poiId,
    List<String>? tags,
    List<String>? images,
    double? longitude,
    double? latitude,
  }) async {
    try {
      final response = await _dio.post(
        '/api/v1/posts/publish',
        data: {
          'content': content,
          if (poiId != null) 'poi_id': poiId,
          'tags': tags ?? [],
          'images': images ?? [],
          if (longitude != null) 'longitude': longitude,
          if (latitude != null) 'latitude': latitude,
        },
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      // ignore: avoid_print
      print('[ApiService] 发布动态失败: ${e.response?.data}');
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchPosts({
    int page = 1,
    int pageSize = 20,
    String? poiId,
    String? userId,
  }) async {
    try {
      final response = await _dio.get(
        '/api/v1/posts',
        queryParameters: {
          'page': page,
          'page_size': pageSize,
          if (poiId != null) 'poi_id': poiId,
          if (userId != null) 'user_id': userId,
        },
      );
      return response.data as Map<String, dynamic>;
    } on DioException {
      return null;
    }
  }

  Future<bool> likePost(String postId) async {
    try {
      await _dio.post('/api/v1/posts/$postId/like');
      return true;
    } on DioException {
      return false;
    }
  }

  Future<bool> unlikePost(String postId) async {
    try {
      await _dio.delete('/api/v1/posts/$postId/like');
      return true;
    } on DioException {
      return false;
    }
  }

  Future<Map<String, dynamic>?> fetchComments(
    String postId, {
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final response = await _dio.get(
        '/api/v1/posts/$postId/comments',
        queryParameters: {'page': page, 'page_size': pageSize},
      );
      return response.data as Map<String, dynamic>;
    } on DioException {
      return null;
    }
  }

  Future<Map<String, dynamic>?> createComment(
    String postId, {
    required String content,
    String? parentId,
  }) async {
    try {
      final response = await _dio.post(
        '/api/v1/posts/$postId/comments',
        data: {
          'content': content,
          if (parentId != null) 'parent_id': parentId,
        },
      );
      return response.data as Map<String, dynamic>;
    } on DioException {
      return null;
    }
  }

  Future<bool> deleteComment(String commentId) async {
    try {
      await _dio.delete('/api/v1/posts/comments/$commentId');
      return true;
    } on DioException {
      return false;
    }
  }

  Future<String?> uploadImage(String filePath) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
      });
      final response = await _dio.post(
        '/api/v1/upload/image',
        data: formData,
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return data['url'] as String?;
      }
      return null;
    } on DioException catch (e) {
      // ignore: avoid_print
      print('[ApiService] 图片上传失败: ${e.response?.data}');
      return null;
    }
  }

  Future<List<String>> uploadImages(List<String> filePaths) async {
    final urls = <String>[];
    for (final path in filePaths) {
      final url = await uploadImage(path);
      if (url != null) urls.add(url);
    }
    return urls;
  }

  Future<bool> followUser(String userId) async {
    try {
      await _dio.post('/api/v1/social/follow/$userId');
      return true;
    } on DioException {
      return false;
    }
  }

  Future<bool> unfollowUser(String userId) async {
    try {
      await _dio.delete('/api/v1/social/follow/$userId');
      return true;
    } on DioException {
      return false;
    }
  }

  Future<bool> isFollowing(String userId) async {
    try {
      final response = await _dio.get('/api/v1/social/is-following/$userId');
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return data['is_following'] as bool? ?? false;
      }
      return false;
    } on DioException {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchFollowers(String userId, {int page = 1}) async {
    try {
      final response = await _dio.get(
        '/api/v1/social/followers/$userId',
        queryParameters: {'page': page},
      );
      final data = response.data;
      if (data is List) return data.cast<Map<String, dynamic>>();
      return [];
    } on DioException {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchFollowing(String userId, {int page = 1}) async {
    try {
      final response = await _dio.get(
        '/api/v1/social/following/$userId',
        queryParameters: {'page': page},
      );
      final data = response.data;
      if (data is List) return data.cast<Map<String, dynamic>>();
      return [];
    } on DioException {
      return [];
    }
  }

  Future<List<POIModel>> fetchMockPOIs() async {
    try {
      final response = await _dio.get('/api/v1/map/pois/mock');
      final data = response.data;
      if (data == null || data['pois'] == null) return [];
      final list = data['pois'] as List;
      return list.map((j) => POIModel.fromJson(j as Map<String, dynamic>)).toList();
    } on DioException {
      return [];
    }
  }

  Future<POIFetchResult> fetchPOIsByBoundsWithClusters({
    required double minLon,
    required double maxLon,
    required double minLat,
    required double maxLat,
    int zoomLevel = 14,
    String? category,
    String? mbtiType,
    String? clusterMode,
    String? selectedProvince,
    CancelToken? cancelToken,
    bool useFallback = true,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'min_lon': minLon,
        'max_lon': maxLon,
        'min_lat': minLat,
        'max_lat': maxLat,
        'zoom_level': zoomLevel,
      };
      if (category != null && category.isNotEmpty) {
        queryParams['category'] = category;
      }
      if (mbtiType != null && mbtiType.isNotEmpty) {
        queryParams['mbti_type'] = mbtiType;
      }
      if (clusterMode != null && clusterMode.isNotEmpty) {
        queryParams['cluster_mode'] = clusterMode;
      }
      if (selectedProvince != null && selectedProvince.isNotEmpty) {
        queryParams['selected_province'] = selectedProvince;
      }

      final response = await _dio.get(
        '/api/v1/map/pois/bounds',
        queryParameters: queryParams,
        cancelToken: cancelToken,
      );

      final data = response.data;
      if (data == null) return const POIFetchResult();

      final poisList = data['pois'] as List? ?? [];
      final clustersList = data['clusters'] as List? ?? [];

      return POIFetchResult(
        pois: poisList.map((j) => POIModel.fromJson(j as Map<String, dynamic>)).toList(),
        clusters: clustersList.map((j) => POIClusterModel.fromJson(j as Map<String, dynamic>)).toList(),
      );
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        return const POIFetchResult();
      }

      // ignore: avoid_print
      print('[ApiService] Connection failed: $e');

      if (!useFallback) {
        throw Exception('API_FAILED');
      }

      return const POIFetchResult(
        pois: [
          POIModel(
            poiId: 'hardcoded-bj-1', name: '故宫（本地）',
            category: '景点', subCategory: '历史',
            longitude: 116.3975, latitude: 39.9087,
            aiSummary: '本地兜底数据：明清皇宫，北京地标。',
            rating: 5.0,
            isRecommended: true,
          ),
          POIModel(
            poiId: 'hardcoded-bj-2', name: '南锣鼓巷（本地）',
            category: '美食', subCategory: '胡同',
            longitude: 116.4039, latitude: 39.9407,
            aiSummary: '本地兜底数据：胡同风情街区，适合慢逛。',
            rating: 4.5,
          ),
          POIModel(
            poiId: 'hardcoded-bj-3', name: '颐和园（本地）',
            category: '景点', subCategory: '历史',
            longitude: 116.2733, latitude: 39.9996,
            aiSummary: '本地兜底数据：皇家园林博物馆。',
            rating: 4.8,
            isRecommended: true,
          ),
        ],
      );
    }
  }

  Future<List<POIModel>> fetchPOIsByBounds({
    required double minLon,
    required double maxLon,
    required double minLat,
    required double maxLat,
    int zoomLevel = 14,
    String? category,
    String? mbtiType,
    CancelToken? cancelToken,
    bool useFallback = true,
  }) async {
    final result = await fetchPOIsByBoundsWithClusters(
      minLon: minLon, maxLon: maxLon,
      minLat: minLat, maxLat: maxLat,
      zoomLevel: zoomLevel, category: category,
      mbtiType: mbtiType, cancelToken: cancelToken,
      useFallback: useFallback,
    );
    return result.pois;
  }

  Future<List<POIModel>> searchPOIs(String query, {String? category, String? mbtiType}) async {
    try {
      final params = <String, dynamic>{'q': query};
      if (category != null) params['category'] = category;
      if (mbtiType != null) params['mbti_type'] = mbtiType;
      final response = await _dio.get('/api/v1/map/pois/search', queryParameters: params);
      final data = response.data;
      if (data == null || data['pois'] == null) return [];
      final list = data['pois'] as List;
      return list.map((j) => POIModel.fromJson(j as Map<String, dynamic>)).toList();
    } on DioException {
      return [];
    }
  }

  Future<POIDetailModel?> fetchPOIDetail(String poiId, {String? mbtiType}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (mbtiType != null) queryParams['mbti_type'] = mbtiType;

      final response = await _dio.get(
        '/api/v1/map/pois/$poiId',
        queryParameters: queryParams,
      );

      final data = response.data;
      if (data == null) return null;
      return POIDetailModel.fromJson(data as Map<String, dynamic>);
    } on DioException {
      return null;
    }
  }

  Future<Map<String, dynamic>?> geocode(String address) async {
    try {
      final response = await _dio.get(
        '/api/v1/map/geocode',
        queryParameters: {'address': address},
      );
      final data = response.data;
      if (data == null) return null;
      if (data is Map<String, dynamic> && data.containsKey('data')) {
        return data['data'] as Map<String, dynamic>;
      }
      return data as Map<String, dynamic>;
    } on DioException {
      return null;
    }
  }

  Future<bool> uploadMBTI({
    required String mbtiType,
    required String persona,
    required List<String> travelTags,
  }) async {
    try {
      await _dio.put(
        '/api/v1/users/mbti',
        data: {
          'mbti_type': mbtiType,
          'mbti_persona': persona,
          'travel_pref_tags': travelTags,
        },
      );
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        // ignore: avoid_print
        print('[ApiService] 跳过 MBTI 上传：用户未登录');
        return false;
      }
      // ignore: avoid_print
      print('[ApiService] MBTI 上传失败: $e');
      return false;
    }
  }

  Future<bool> syncFootprint({
    required String poiId,
    required double longitude,
    required double latitude,
    String? note,
  }) async {
    try {
      await _dio.post(
        '/api/v1/posts/footprints',
        data: {
          'poi_id': poiId,
          'longitude': longitude,
          'latitude': latitude,
          'check_in_note': note,
        },
      );
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        // ignore: avoid_print
        print('[ApiService] 跳过足迹同步：用户未登录');
        return false;
      }
      // ignore: avoid_print
      print('[ApiService] 足迹同步失败: $e');
      return false;
    }
  }

  Stream<Map<String, dynamic>> streamChat({
    required String message,
    String? conversationId,
    double? longitude,
    double? latitude,
    String? currentPoiId,
    String? mbtiType,
  }) async* {
    try {
      final response = await _dio.post(
        '/api/v1/ai/chat',
        data: {
          'message': message,
          if (conversationId != null) 'conversation_id': conversationId,
          if (longitude != null) 'longitude': longitude,
          if (latitude != null) 'latitude': latitude,
          if (currentPoiId != null) 'current_poi_id': currentPoiId,
          if (mbtiType != null) 'mbti_type': mbtiType,
        },
        options: Options(
          responseType: ResponseType.stream,
          headers: {'Accept': 'text/event-stream'},
        ),
      );

      final stream = response.data.stream as Stream<List<int>>;
      String buffer = '';

      await for (final chunk in stream) {
        buffer += utf8.decode(chunk);
        while (buffer.contains('\n\n')) {
          final idx = buffer.indexOf('\n\n');
          final rawEvent = buffer.substring(0, idx);
          buffer = buffer.substring(idx + 2);

          for (final line in rawEvent.split('\n')) {
            if (line.startsWith('data: ')) {
              final jsonStr = line.substring(6).trim();
              if (jsonStr.isEmpty || jsonStr == '[DONE]') continue;
              try {
                final parsed = json.decode(jsonStr) as Map<String, dynamic>;
                yield parsed;
              } catch (_) {
              }
            }
          }
        }
      }
    } on DioException catch (e) {
      // ignore: avoid_print
      print('[ApiService] AI Chat 流失败: $e');
      yield {'type': 'error', 'content': '网络连接失败，请稍后重试', 'is_complete': true};
    }
  }

  Stream<Map<String, dynamic>> streamRoutePlan({
    required String destination,
    required int days,
    List<String>? preferences,
    String? mbtiType,
    String? pace,
    String? budgetLevel,
  }) async* {
    try {
      final response = await _dio.post(
        '/api/v1/ai/plan-route',
        data: {
          'city': destination,
          'days': days,
          if (preferences != null && preferences.isNotEmpty) 'preferences': preferences,
          if (mbtiType != null) 'mbti_type': mbtiType,
          if (pace != null) 'pace': pace,
          if (budgetLevel != null) 'budget_level': budgetLevel,
        },
        options: Options(
          responseType: ResponseType.stream,
          headers: {'Accept': 'text/event-stream'},
        ),
      );

      final stream = response.data.stream as Stream<List<int>>;
      String buffer = '';

      await for (final chunk in stream) {
        buffer += utf8.decode(chunk);
        while (buffer.contains('\n\n')) {
          final idx = buffer.indexOf('\n\n');
          final rawEvent = buffer.substring(0, idx);
          buffer = buffer.substring(idx + 2);

          for (final line in rawEvent.split('\n')) {
            if (line.startsWith('data: ')) {
              final jsonStr = line.substring(6).trim();
              if (jsonStr.isEmpty || jsonStr == '[DONE]') continue;
              try {
                final parsed = json.decode(jsonStr) as Map<String, dynamic>;
                yield parsed;
              } catch (_) {}
            }
          }
        }
      }
    } on DioException catch (e) {
      // ignore: avoid_print
      print('[ApiService] 行程规划流失败: $e');
      yield {'type': 'error', 'content': '网络连接失败，请稍后重试', 'is_complete': true};
    }
  }

  Future<String?> queryPOI({
    required String poiId,
    required String question,
    String? mbtiType,
  }) async {
    try {
      final response = await _dio.post('/api/v1/ai/poi-query', data: {
        'poi_id': poiId,
        'question': question,
        if (mbtiType != null) 'mbti_type': mbtiType,
      });
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return data['answer'] as String?;
      }
      return null;
    } on DioException catch (e) {
      // ignore: avoid_print
      print('[ApiService] POI 问答失败: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>?> fetchUserPlans() async {
    try {
      final response = await _dio.get('/api/v1/plans');
      final data = response.data;
      if (data is Map<String, dynamic> && data['items'] != null) {
        return (data['items'] as List).cast<Map<String, dynamic>>();
      }
      return [];
    } on DioException catch (e) {
      // ignore: avoid_print
      print('[ApiService] 获取行程列表失败: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchPlanDetail(String planId) async {
    try {
      final response = await _dio.get('/api/v1/plans/$planId');
      return response.data as Map<String, dynamic>?;
    } on DioException catch (e) {
      // ignore: avoid_print
      print('[ApiService] 获取行程详情失败: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> confirmPlanSave({
    required Map<String, dynamic> planData,
    String? planId,
  }) async {
    try {
      final response = await _dio.post(
        '/api/v1/ai/confirm-plan-save',
        data: {
          'plan_data': planData,
          if (planId != null) 'plan_id': planId,
        },
      );
      return response.data as Map<String, dynamic>?;
    } on DioException catch (e) {
      // ignore: avoid_print
      print('[ApiService] 确认保存行程失败: $e');
      return null;
    }
  }

  Future<bool> updatePlanChecklist(String planId, List<Map<String, dynamic>> checklist) async {
    try {
      await _dio.put(
        '/api/v1/plans/$planId/checklist',
        data: {'checklist': checklist},
      );
      return true;
    } on DioException catch (e) {
      // ignore: avoid_print
      print('[ApiService] 更新清单勾选状态失败: $e');
      return false;
    }
  }
  Future<Map<String, dynamic>?> updatePlan(
    String planId,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _dio.put('/api/v1/plans/$planId', data: payload);
      return response.data as Map<String, dynamic>?;
    } on DioException catch (e) {
      // ignore: avoid_print
      print('[ApiService] 更新行程详情失败: $e');
      return null;
    }
  }
}

