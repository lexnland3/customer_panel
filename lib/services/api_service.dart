import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Api {
  static const base = 'http://localhost:5000/api';

  // ── Prefs helpers ─────────────────────────────────────────────
  static Future<String?> getToken() async {
    final p = await SharedPreferences.getInstance();
    return p.getString('customer_token');
  }

  static Future<void> saveToken(String t) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('customer_token', t);
  }

  static Future<void> saveUser(Map<String, dynamic> u) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('customer_user', jsonEncode(u));
  }

  static Future<Map<String, dynamic>?> getUser() async {
    final p = await SharedPreferences.getInstance();
    final d = p.getString('customer_user');
    return d != null ? jsonDecode(d) as Map<String, dynamic> : null;
  }

  static Future<void> logout() async {
    final p = await SharedPreferences.getInstance();
    await p.remove('customer_token');
    await p.remove('customer_user');
  }

  // ── Internal helpers ──────────────────────────────────────────
  static Future<Map<String, String>> _headers({bool auth = true}) async {
    final h = <String, String>{'Content-Type': 'application/json'};
    if (auth) {
      final t = await getToken();
      if (t != null) h['Authorization'] = 'Bearer $t';
    }
    return h;
  }

  static Map<String, dynamic> _handle(http.Response res) {
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw Exception(body['message'] ?? 'Request failed (${res.statusCode})');
  }

  // ── AUTH ─────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('$base/customers/register'),
      headers: await _headers(auth: false),
      body: jsonEncode({'name': name, 'email': email, 'phone': phone, 'password': password}),
    );
    final data = _handle(res);
    if (data['token'] != null) {
      await saveToken(data['token'] as String);
      if (data['customer'] != null) await saveUser(data['customer'] as Map<String, dynamic>);
    }
    return data;
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('$base/customers/login'),
      headers: await _headers(auth: false),
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = _handle(res);
    if (data['token'] != null) {
      await saveToken(data['token'] as String);
      if (data['customer'] != null) await saveUser(data['customer'] as Map<String, dynamic>);
    }
    return data;
  }

  static Future<Map<String, dynamic>> googleSignIn(String idToken) async {
    final res = await http.post(
      Uri.parse('$base/customers/google'),
      headers: await _headers(auth: false),
      body: jsonEncode({'idToken': idToken}),
    );
    final data = _handle(res);
    if (data['token'] != null) {
      await saveToken(data['token'] as String);
      if (data['customer'] != null) await saveUser(data['customer'] as Map<String, dynamic>);
    }
    return data;
  }

  static Future<Map<String, dynamic>> getMe() async {
    final res = await http.get(
      Uri.parse('$base/customers/me'),
      headers: await _headers(),
    );
    return _handle(res);
  }

  // ── PLOTS ─────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getPlots({
    String? search,
    String? facing,
    String? plotType,
    int? minPrice,
    int? maxPrice,
    int page = 1,
  }) async {
    final params = <String, String>{'page': '$page', 'limit': '10'};
    if (search   != null && search.isNotEmpty)  params['search']   = search;
    if (facing   != null && facing != 'Any')    params['facing']   = facing;
    if (plotType != null && plotType != 'Any')  params['plotType'] = plotType;
    if (minPrice != null)                       params['minPrice'] = '$minPrice';
    if (maxPrice != null)                       params['maxPrice'] = '$maxPrice';

    final uri = Uri.parse('$base/customers/plots').replace(queryParameters: params);
    final res = await http.get(uri, headers: await _headers(auth: false));
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getPlotById(String id) async {
    final res = await http.get(
      Uri.parse('$base/customers/plots/$id'),
      headers: await _headers(auth: false),
    );
    return _handle(res);
  }

  // ── VISIT BOOKING ─────────────────────────────────────────────
  static Future<Map<String, dynamic>> bookVisit({
    required String plotId,
    required String visitorName,
    required String visitorPhone,
    required String visitDate,
    required String visitTime,
    String requirement = '',
  }) async {
    final res = await http.post(
      Uri.parse('$base/customers/visits'),
      headers: await _headers(),
      body: jsonEncode({
        'propertyId':   plotId,
        'visitorName':  visitorName,
        'visitorPhone': visitorPhone,
        'visitDate':    visitDate,
        'visitTime':    visitTime,
        'requirement':  requirement,
      }),
    );
    return _handle(res);
  }

  // ── CHAT ─────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getOrCreateChat({
    required String plotId,
    required String ownerId,
  }) async {
    final res = await http.post(
      Uri.parse('$base/customers/chats'),
      headers: await _headers(),
      body: jsonEncode({'plotId': plotId, 'ownerId': ownerId}),
    );
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getMyChats() async {
    final res = await http.get(
      Uri.parse('$base/customers/chats'),
      headers: await _headers(),
    );
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getChatMessages(
    String chatId, {
    int page = 1,
  }) async {
    final uri = Uri.parse('$base/customers/chats/$chatId/messages')
        .replace(queryParameters: {'page': '$page', 'limit': '30'});
    final res = await http.get(uri, headers: await _headers());
    return _handle(res);
  }

  static Future<Map<String, dynamic>> sendMessage({
    required String chatId,
    required String text,
    String? imageUrl,
    String? linkUrl,
  }) async {
    final res = await http.post(
      Uri.parse('$base/customers/chats/$chatId/messages'),
      headers: await _headers(),
      body: jsonEncode({
        'text': text,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (linkUrl  != null) 'linkUrl':  linkUrl,
      }),
    );
    return _handle(res);
  }

  static Future<Map<String, dynamic>> pollMessages(
    String chatId,
    String since,
  ) async {
    final uri = Uri.parse('$base/customers/chats/$chatId/poll')
        .replace(queryParameters: {'since': since});
    final res = await http.get(uri, headers: await _headers());
    return _handle(res);
  }

  // ── VISITS ─────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getMyVisits() async {
    final res = await http.get(Uri.parse('$base/customers/visits'), headers: await _headers());
    return _handle(res);
  }

  static Future<Map<String, dynamic>> uploadChatAudio({
    required String chatId,
    required List<int> bytes,
    required String fileName,
  }) async {
    final uri = Uri.parse('$base/customers/chats/$chatId/upload-audio');
    final req  = http.MultipartRequest('POST', uri);
    req.headers.addAll(await _headers());
    req.files.add(http.MultipartFile.fromBytes('audio', bytes,
        filename: fileName,
        contentType: MediaType('audio', 'webm')));
    final streamed = await req.send();
    final res      = await http.Response.fromStream(streamed);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> cancelVisit(String id) async {
    final res = await http.patch(Uri.parse('$base/customers/visits/$id/cancel'), headers: await _headers());
    return _handle(res);
  }

  // Customer edits visit date/time directly (sends updated card to chat, resets to pending)
  static Future<Map<String, dynamic>> editVisit(
    String id, {
    required String visitDate,
    required String visitTime,
  }) async {
    final res = await http.patch(
      Uri.parse('$base/customers/visits/$id/edit'),
      headers: await _headers(),
      body: jsonEncode({'visitDate': visitDate, 'visitTime': visitTime}),
    );
    return _handle(res);
  }

  // Customer accepts owner's edit
  static Future<Map<String, dynamic>> acceptVisit(String id) async {
    final res = await http.patch(
      Uri.parse('$base/customers/visits/$id/accept'),
      headers: await _headers(),
    );
    return _handle(res);
  }

  // ── MESSAGE ACTIONS ──────────────────────────────────────
  static Future<Map<String, dynamic>> uploadChatPhoto({
    required String chatId,
    required List<int> bytes,
    required String fileName,
  }) async {
    final token   = await getToken();
    final request = http.MultipartRequest(
        'POST', Uri.parse('$base/customers/chats/$chatId/upload'));
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.files.add(http.MultipartFile.fromBytes('photo', bytes,
        filename: fileName));
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> editMessage({
    required String chatId,
    required String msgId,
    required String newText,
  }) async {
    final res = await http.patch(
      Uri.parse('$base/customers/chats/$chatId/messages/$msgId'),
      headers: await _headers(),
      body: jsonEncode({'text': newText}),
    );
    return _handle(res);
  }

  static Future<Map<String, dynamic>> deleteMessage({
    required String chatId,
    required String msgId,
    required String scope, // 'me' or 'everyone'
  }) async {
    final req = http.Request('DELETE',
        Uri.parse('$base/customers/chats/$chatId/messages/$msgId'));
    req.headers.addAll(await _headers());
    req.body = jsonEncode({'scope': scope});
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    return _handle(res);
  }


  // ── FAVOURITES ────────────────────────────────────────────
  static Future<Map<String, dynamic>> getFavourites() async {
    final res = await http.get(Uri.parse('$base/customers/favourites'), headers: await _headers());
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getFavouriteIds() async {
    final res = await http.get(Uri.parse('$base/customers/favourites/ids'), headers: await _headers());
    return _handle(res);
  }

  static Future<Map<String, dynamic>> addFavourite(String plotId) async {
    final res = await http.post(Uri.parse('$base/customers/favourites/$plotId'), headers: await _headers());
    return _handle(res);
  }

  static Future<Map<String, dynamic>> removeFavourite(String plotId) async {
    final req = http.Request('DELETE', Uri.parse('$base/customers/favourites/$plotId'));
    req.headers.addAll(await _headers());
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> toggleFavourite(String plotId, bool currentlyFav) async {
    if (currentlyFav) return removeFavourite(plotId);
    return addFavourite(plotId);
  }
}