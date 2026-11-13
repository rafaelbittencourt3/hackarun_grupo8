import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shop_app/api.dart';
import 'package:shop_app/models.dart';
import 'package:shop_app/photo_search.dart';
import 'package:shop_app/screens/chat_screen.dart';
import 'package:shop_app/screens/compass_screen.dart';
import 'package:shop_app/screens/home_screen.dart';

const _storeJson = {
  'id': 1,
  'name': 'Passo Certo',
  'category': 'Calçados',
  'description': 'Tênis e sapatos.',
  'floor': 2,
  'latitude': -23.55021,
  'longitude': -46.63364,
  'whatsapp': '5511999990000',
};

http.Response _json(Object body, [int status = 200]) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    status,
    headers: {'content-type': 'application/json'},
  );
}

void main() {
  group('relativeAngle', () {
    test('is zero when the phone points at the store', () {
      expect(relativeAngle(90, 90), 0);
    });

    test('takes the shortest turn across north', () {
      expect(relativeAngle(10, 350), 20);
      expect(relativeAngle(350, 10), -20);
    });

    test('handles negative bearings', () {
      expect(relativeAngle(-90, 0), -90);
    });
  });

  group('home header', () {
    test('greets according to the time of day', () {
      expect(greetingFor(DateTime(2026, 11, 13, 9)), 'Bom dia');
      expect(greetingFor(DateTime(2026, 11, 13, 15)), 'Boa tarde');
      expect(greetingFor(DateTime(2026, 11, 13, 21)), 'Boa noite');
    });

    test('tells whether the mall is open', () {
      // 13/11/2026 é sexta-feira; 14 é sábado; 15 é domingo.
      expect(mallStatusFor(DateTime(2026, 11, 13, 15)).label,
          'Aberto agora · fecha às 22h');
      expect(mallStatusFor(DateTime(2026, 11, 13, 8)).label,
          'Fechado · abre hoje às 10h');
      expect(mallStatusFor(DateTime(2026, 11, 13, 23)).label,
          'Fechado · abre amanhã às 10h');
      expect(mallStatusFor(DateTime(2026, 11, 14, 23)).label,
          'Fechado · abre amanhã às 14h');
      expect(mallStatusFor(DateTime(2026, 11, 15, 15)).open, isTrue);
      expect(mallStatusFor(DateTime(2026, 11, 15, 21)).open, isFalse);
    });
  });

  group('directionHint', () {
    test('tells the visitor which way to turn', () {
      expect(directionHint(0, 40), 'Siga em frente');
      expect(directionHint(60, 40), 'Vire à direita');
      expect(directionHint(-60, 40), 'Vire à esquerda');
      expect(directionHint(170, 40), 'A loja está atrás de você');
    });

    test('reports arrival when the store is close', () {
      expect(directionHint(90, 5), 'Você chegou');
    });
  });

  test('a store is parsed with its products and promotions', () {
    final store = Store.fromJson({
      ..._storeJson,
      'products': [
        {'id': 1, 'name': 'Tênis', 'description': null, 'price': 299.9},
      ],
      'promotions': [
        {
          'id': 1,
          'title': 'Oferta',
          'description': 'Desconto',
          'price': null,
          'ends_at': '2026-11-20',
        },
      ],
    });

    expect(store.floorLabel, '2º andar');
    expect(store.products.single.price, 299.9);
    expect(store.promotions.single.price, isNull);
    expect(formatPrice(249), 'R\$ 249,00');
  });

  testWidgets('the chat shows the reply with the recommended store card',
      (tester) async {
    late Map<String, dynamic> sent;
    api = ApiClient(
      baseUrl: 'http://test/api/v1',
      client: MockClient((request) async {
        sent = jsonDecode(request.body) as Map<String, dynamic>;

        return _json({
          'data': {'reply': 'A Passo Certo tem tênis.', 'store': _storeJson},
        });
      }),
    );

    await tester.pumpWidget(const MaterialApp(home: ChatScreen()));
    await tester.enterText(find.byType(TextField), 'Quero um tênis');
    await tester.tap(find.byTooltip('Enviar'));
    await tester.pumpAndSettle();

    expect(sent['message'], 'Quero um tênis');
    expect(find.text('Quero um tênis'), findsOneWidget);
    expect(find.text('A Passo Certo tem tênis.'), findsOneWidget);
    expect(find.text('Passo Certo'), findsOneWidget);
    expect(find.text('Me leve até a loja'), findsOneWidget);
    expect(find.byTooltip('Falar com atendente'), findsOneWidget);
  });

  testWidgets('a photo is sent to the assistant as its recognized labels',
      (tester) async {
    late Map<String, dynamic> sent;
    api = ApiClient(
      baseUrl: 'http://test/api/v1',
      client: MockClient((request) async {
        sent = jsonDecode(request.body) as Map<String, dynamic>;

        return _json({
          'data': {'reply': 'Parece um tênis.', 'store': _storeJson},
        });
      }),
    );
    pickPhoto = (source) async => 'foto-inexistente.jpg';
    labelPhoto = (path) async => ['Shoe', 'Sneakers'];

    await tester.pumpWidget(const MaterialApp(home: ChatScreen()));
    await tester.tap(find.byTooltip('Buscar por foto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Escolher da galeria'));
    await tester.pumpAndSettle();

    expect(sent['image_labels'], ['Shoe', 'Sneakers']);
    expect(sent.containsKey('message'), isFalse);
    expect(find.text('Parece um tênis.'), findsOneWidget);
    expect(find.text('Me leve até a loja'), findsOneWidget);
  });

  testWidgets('the chat explains when nothing is recognized in the photo',
      (tester) async {
    api = ApiClient(
      baseUrl: 'http://test/api/v1',
      client:
          MockClient((request) async => fail('the server must not be called')),
    );
    pickPhoto = (source) async => 'foto-inexistente.jpg';
    labelPhoto = (path) async => [];

    await tester.pumpWidget(const MaterialApp(home: ChatScreen()));
    await tester.tap(find.byTooltip('Buscar por foto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tirar foto'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Não consegui identificar o produto'),
        findsOneWidget);
  });

  testWidgets(
      'the chat shows a planned route and guides the visitor stop by stop',
      (tester) async {
    late Map<String, dynamic> sent;
    api = ApiClient(
      baseUrl: 'http://test/api/v1',
      client: MockClient((request) async {
        sent = jsonDecode(request.body) as Map<String, dynamic>;

        return _json({
          'data': {
            'reply': 'Tênis e depois almoço.',
            'store': null,
            'route': {
              'summary': 'Tênis e depois almoço.',
              'total_price': 288.9,
              'total_minutes': 51,
              'stops': [
                {
                  'store': _storeJson,
                  'item': 'Tênis de corrida Veloz',
                  'price': 249,
                  'reason': 'Está em promoção.',
                  'minutes': 15,
                },
                {
                  'store': {
                    ..._storeJson,
                    'id': 2,
                    'name': 'Burger House',
                    'floor': 3
                  },
                  'item': 'Combo da casa',
                  'price': 39.9,
                  'reason': 'Almoço rápido.',
                  'minutes': 30,
                },
              ],
            },
          },
        });
      }),
    );

    await tester.pumpWidget(const MaterialApp(home: ChatScreen()));
    await tester.enterText(find.byType(TextField), 'Quero um tênis e almoçar');
    await tester.tap(find.byTooltip('Enviar'));
    await tester.pumpAndSettle();

    expect(sent['message'], 'Quero um tênis e almoçar');
    expect(find.text('Tênis e depois almoço.'), findsOneWidget);
    expect(find.text('R\$ 288,90'), findsOneWidget);
    expect(find.text('51 min'), findsOneWidget);
    expect(find.text('Burger House'), findsOneWidget);

    await tester.ensureVisible(find.text('Começar roteiro'));
    await tester.tap(find.text('Começar roteiro'));
    await tester.pumpAndSettle();

    expect(find.text('Parada 1 de 2'), findsOneWidget);
    expect(find.text('Tênis de corrida Veloz'), findsOneWidget);

    await tester.ensureVisible(find.text('Cheguei, próxima parada'));
    await tester.tap(find.text('Cheguei, próxima parada'));
    await tester.pumpAndSettle();

    expect(find.text('Parada 2 de 2'), findsOneWidget);
    expect(find.text('Cheguei, concluir roteiro'), findsOneWidget);

    // As duas lojas do teste ficam no mesmo ponto, então a segunda parada
    // já começa em frente à loja.
    expect(find.text('Você chegou'), findsOneWidget);

    await tester.ensureVisible(find.text('Cheguei, concluir roteiro'));
    await tester.tap(find.text('Cheguei, concluir roteiro'));
    await tester.pumpAndSettle();

    expect(find.text('Roteiro concluído!'), findsOneWidget);
    expect(find.text('R\$ 288,90'), findsOneWidget);
    expect(find.text('Voltar ao guia'), findsOneWidget);
  });

  testWidgets('every store cited in a reply gets its own compass shortcut',
      (tester) async {
    api = ApiClient(
      baseUrl: 'http://test/api/v1',
      client: MockClient((request) async => _json({
            'data': {
              'reply': 'Duas opções de tênis.',
              'stores': [
                _storeJson,
                {..._storeJson, 'id': 2, 'name': 'Sport Mania'},
              ],
              'route': null,
            },
          })),
    );

    await tester.pumpWidget(const MaterialApp(home: ChatScreen()));
    await tester.enterText(find.byType(TextField), 'Onde tem tênis?');
    await tester.tap(find.byTooltip('Enviar'));
    await tester.pumpAndSettle();

    expect(find.text('Passo Certo'), findsOneWidget);
    expect(find.text('Sport Mania'), findsOneWidget);
    expect(find.byTooltip('Me leve até a Passo Certo'), findsOneWidget);
    expect(find.byTooltip('Me leve até a Sport Mania'), findsOneWidget);
  });

  testWidgets(
      'a reply shows the cited products and its follow-up questions can be tapped',
      (tester) async {
    final sent = <String?>[];
    api = ApiClient(
      baseUrl: 'http://test/api/v1',
      client: MockClient((request) async {
        sent.add((jsonDecode(request.body) as Map<String, dynamic>)['message']
            as String?);

        return _json({
          'data': {
            'reply': 'Tem o Tênis de corrida Veloz.',
            'stores': [],
            'products': [
              {
                'id': 1,
                'name': 'Tênis de corrida Veloz',
                'price': 299.9,
                'image_url': null,
                'store': _storeJson,
              },
            ],
            'suggestions': sent.length == 1 ? ['Qual o mais barato?'] : [],
            'route': null,
          },
        });
      }),
    );

    await tester.pumpWidget(const MaterialApp(home: ChatScreen()));
    await tester.enterText(find.byType(TextField), 'Quero um tênis');
    await tester.tap(find.byTooltip('Enviar'));
    await tester.pumpAndSettle();

    expect(find.text('Tênis de corrida Veloz'), findsOneWidget);
    expect(find.text('R\$ 299,90'), findsOneWidget);

    await tester.tap(find.text('Qual o mais barato?'));
    await tester.pumpAndSettle();

    expect(sent, ['Quero um tênis', 'Qual o mais barato?']);
  });

  testWidgets(
      'the compass shows the arrival indicator after the simulated walk',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: CompassScreen(store: Store.fromJson(_storeJson)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Você chegou'), findsNothing);
    expect(find.textContaining('A cerca de'), findsOneWidget);

    await tester.ensureVisible(find.text('Simular caminhada'));
    await tester.tap(find.text('Simular caminhada'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(find.text('Você chegou'), findsOneWidget);
    expect(find.text('A Passo Certo está à sua frente'), findsOneWidget);
    expect(find.text('Simular caminhada'), findsNothing);
  });

  testWidgets('a shortcut sends a complete question and shows its short label',
      (tester) async {
    late Map<String, dynamic> sent;
    api = ApiClient(
      baseUrl: 'http://test/api/v1',
      client: MockClient((request) async {
        sent = jsonDecode(request.body) as Map<String, dynamic>;

        return _json({
          'data': {
            'reply': 'Temos três restaurantes.',
            'store': null,
            'route': null
          },
        });
      }),
    );

    await tester.pumpWidget(const MaterialApp(home: ChatScreen()));
    expect(find.text('O que vamos resolver hoje?'), findsOneWidget);

    await tester.tap(find.text('Onde comer'));
    await tester.pumpAndSettle();

    expect(sent['message'],
        'Onde posso comer no shopping? Quais são as opções e os preços?');
    expect(find.text('Temos três restaurantes.'), findsOneWidget);
    expect(find.text('O que vamos resolver hoje?'), findsNothing);
  });

  testWidgets('the chat shows a friendly message when the server fails',
      (tester) async {
    api = ApiClient(
      baseUrl: 'http://test/api/v1',
      client: MockClient(
        (request) async => _json(
            {'message': 'O assistente está indisponível no momento.'}, 503),
      ),
    );

    await tester.pumpWidget(const MaterialApp(home: ChatScreen()));
    await tester.enterText(find.byType(TextField), 'Oi');
    await tester.tap(find.byTooltip('Enviar'));
    await tester.pumpAndSettle();

    expect(find.text('O assistente está indisponível no momento.'),
        findsOneWidget);
    expect(find.text('Me leve até a loja'), findsNothing);
  });
}
