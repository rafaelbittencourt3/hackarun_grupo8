import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'config.dart';
import 'models.dart';

/// Erro com uma mensagem pronta para ser mostrada ao visitante.
class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Cliente usado pelas telas; os testes trocam por um cliente falso.
ApiClient api = ApiClient();

class ApiClient {
  ApiClient({http.Client? client, this.baseUrl = apiUrl})
      : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;

  Future<List<Store>> fetchStores({String? query, String? category}) async {
    final params = <String, String>{
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      if (category != null) 'category': category,
    };
    final json = await _send(() => _client.get(_uri('/lojas', params)));

    return (json['data'] as List)
        .map((item) => Store.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Store> fetchStore(int id) async {
    final json = await _send(() => _client.get(_uri('/lojas/$id')));

    return Store.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<List<Promotion>> fetchPromotions() async {
    final json = await _send(() => _client.get(_uri('/promocoes')));

    return (json['data'] as List)
        .map((item) => Promotion.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Envia uma pergunta em texto, os rótulos reconhecidos em uma foto, ou os dois.
  Future<ChatAnswer> sendChat(
    String? message, {
    List<Map<String, String>> history = const [],
    List<String> imageLabels = const [],
  }) async {
    final json = await _send(
      () => _client.post(
        _uri('/chat'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          if (message != null) 'message': message,
          if (imageLabels.isNotEmpty) 'image_labels': imageLabels,
          'history': history,
        }),
      ),
      timeout: const Duration(seconds: 120),
    );
    final data = json['data'] as Map<String, dynamic>;

    return ChatAnswer(
      reply: data['reply'] as String,
      products: [
        if (data['products'] is List)
          for (final item in data['products'] as List)
            ChatProduct.fromJson(item as Map<String, dynamic>),
      ],
      suggestions: [
        if (data['suggestions'] is List)
          for (final item in data['suggestions'] as List) item as String,
      ],
      route: data['route'] == null
          ? null
          : RoutePlan.fromJson(data['route'] as Map<String, dynamic>),
      stores: [
        if (data['stores'] is List)
          for (final item in data['stores'] as List)
            Store.fromJson(item as Map<String, dynamic>)
        else if (data['store'] != null)
          Store.fromJson(data['store'] as Map<String, dynamic>),
      ],
    );
  }

  /// Pede um roteiro de compras para o que o visitante quer comprar ou fazer.
  Future<RoutePlan> planRoute(String request) async {
    final json = await _send(
      () => _client.post(
        _uri('/roteiro'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'request': request}),
      ),
      timeout: const Duration(seconds: 90),
    );

    return RoutePlan.fromJson(json['data'] as Map<String, dynamic>);
  }

  Uri _uri(String path, [Map<String, String>? params]) {
    final uri = Uri.parse('$baseUrl$path');

    return params == null || params.isEmpty
        ? uri
        : uri.replace(queryParameters: params);
  }

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() request, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final http.Response response;

    try {
      response = await request().timeout(timeout);
    } on TimeoutException {
      throw const ApiException('O servidor demorou para responder. Tente de novo.');
    } on SocketException {
      throw const ApiException('Sem conexão com o servidor. Verifique sua internet.');
    } on http.ClientException {
      throw const ApiException('Sem conexão com o servidor. Verifique sua internet.');
    }

    final Object? body;
    try {
      body = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const ApiException('O servidor respondeu de um jeito inesperado.');
    }

    if (response.statusCode == 429) {
      throw const ApiException('Muitas mensagens em pouco tempo. Aguarde um minuto.');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = body is Map<String, dynamic> ? body['message'] : null;
      throw ApiException(
        message is String && response.statusCode == 503
            ? message
            : 'Não foi possível carregar os dados (erro ${response.statusCode}).',
      );
    }

    if (body is! Map<String, dynamic>) {
      throw const ApiException('O servidor respondeu de um jeito inesperado.');
    }

    return body;
  }
}
