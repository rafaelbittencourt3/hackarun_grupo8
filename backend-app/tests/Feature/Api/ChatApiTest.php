<?php

use App\Models\Product;
use App\Models\Store;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Http;

beforeEach(function () {
    config(['services.deepseek.key' => 'test-key']);
    Http::preventStrayRequests();
});

function fakeAssistantAnswer(array $answer): void
{
    Http::fake([
        'api.deepseek.com/*' => Http::response([
            'choices' => [['message' => ['content' => json_encode($answer)]]],
        ]),
    ]);
}

test('the chat replies and returns the recommended store', function () {
    $store = Store::factory()->create(['name' => 'Passo Certo']);
    Product::factory()->for($store)->create(['name' => 'Tênis de corrida']);

    fakeAssistantAnswer(['reply' => 'A Passo Certo tem tênis de corrida.', 'store_id' => $store->id]);

    $this->postJson('/api/v1/chat', ['message' => 'Quero um tênis'])
        ->assertOk()
        ->assertJsonPath('data.reply', 'A Passo Certo tem tênis de corrida.')
        ->assertJsonPath('data.store.id', $store->id)
        ->assertJsonPath('data.store.name', 'Passo Certo');

    Http::assertSent(function (Request $request) {
        $messages = $request['messages'];

        return $request->hasHeader('Authorization', 'Bearer test-key')
            && str_contains($messages[0]['content'], 'Tênis de corrida')
            && end($messages) === ['role' => 'user', 'content' => 'Quero um tênis'];
    });
});

test('the chat tells the assistant the opening hours of each store', function () {
    Store::factory()->create(['name' => 'Cine Estrela', 'opening_hours' => 'Todos os dias, das 12h à meia-noite']);

    fakeAssistantAnswer(['reply' => 'Até a meia-noite.', 'store_id' => null]);

    $this->postJson('/api/v1/chat', ['message' => 'Até que horas posso ficar no cinema?'])->assertOk();

    Http::assertSent(fn (Request $request) => str_contains(
        $request['messages'][0]['content'],
        'Horário: Todos os dias, das 12h à meia-noite',
    ));
});

test('the chat accepts a photo described by its recognized labels', function () {
    fakeAssistantAnswer(['reply' => 'Parece um tênis.', 'store_id' => null]);

    $this->postJson('/api/v1/chat', ['image_labels' => ['Shoe', 'Sneakers']])
        ->assertOk()
        ->assertJsonPath('data.reply', 'Parece um tênis.');

    Http::assertSent(function (Request $request) {
        $question = collect($request['messages'])->last()['content'];

        return str_contains($question, 'foto de um produto') && str_contains($question, 'Shoe, Sneakers');
    });
});

test('the chat rejects a photo without any recognized label', function () {
    $this->postJson('/api/v1/chat', ['image_labels' => []])
        ->assertUnprocessable()
        ->assertJsonValidationErrors('message');

    Http::assertNothingSent();
});

test('the chat answers a multi-item request with a planned route', function () {
    $store = Store::factory()->create(['name' => 'Passo Certo']);
    $content = fn (array $answer) => Http::response([
        'choices' => [['message' => ['content' => json_encode($answer)]]],
    ]);

    Http::fake(['api.deepseek.com/*' => Http::sequence([
        $content(['reply' => 'Vou montar.', 'store_id' => null, 'route_request' => 'Tênis e almoço, R$ 300']),
        $content([
            'summary' => 'Tênis e depois almoço.',
            'stops' => [['store_id' => $store->id, 'item' => 'Tênis', 'price' => 249, 'reason' => 'Promoção.', 'minutes' => 10]],
        ]),
    ])]);

    $this->postJson('/api/v1/chat', ['message' => 'Quero um tênis e almoçar com R$ 300'])
        ->assertOk()
        ->assertJsonPath('data.reply', 'Tênis e depois almoço.')
        ->assertJsonPath('data.store', null)
        ->assertJsonPath('data.route.total_price', 249)
        ->assertJsonPath('data.route.stops.0.store.name', 'Passo Certo');

    Http::assertSent(fn (Request $request) => collect($request['messages'])->last()['content'] === 'Tênis e almoço, R$ 300');
});

test('the chat keeps its own reply when the requested route comes back empty', function () {
    $content = fn (array $answer) => Http::response([
        'choices' => [['message' => ['content' => json_encode($answer)]]],
    ]);

    Http::fake(['api.deepseek.com/*' => Http::sequence([
        $content(['reply' => 'Temos três restaurantes.', 'store_id' => null, 'route_request' => 'Onde comer']),
        $content(['summary' => '', 'stops' => []]),
    ])]);

    $this->postJson('/api/v1/chat', ['message' => 'Onde comer'])
        ->assertOk()
        ->assertJsonPath('data.reply', 'Temos três restaurantes.')
        ->assertJsonPath('data.route', null);
});

test('the chat returns every store the assistant cited', function () {
    $first = Store::factory()->create(['name' => 'Passo Certo']);
    $second = Store::factory()->create(['name' => 'Sport Mania']);

    fakeAssistantAnswer(['reply' => 'Duas opções.', 'store_ids' => [$first->id, $second->id, 999], 'route_request' => null]);

    $this->postJson('/api/v1/chat', ['message' => 'Onde tem tênis?'])
        ->assertOk()
        ->assertJsonCount(2, 'data.stores')
        ->assertJsonPath('data.stores.0.name', 'Passo Certo')
        ->assertJsonPath('data.stores.1.name', 'Sport Mania')
        ->assertJsonPath('data.store.name', 'Passo Certo');
});

test('products named in the reply are returned with their store and the follow-up suggestions', function () {
    $store = Store::factory()->create(['name' => 'Passo Certo']);
    Product::factory()->for($store)->create(['name' => 'Tênis de corrida Veloz', 'price' => 299.9]);
    Product::factory()->for($store)->create(['name' => 'Chinelo Conforto']);

    fakeAssistantAnswer([
        'reply' => 'Tem o Tênis de corrida Veloz na Passo Certo.',
        'store_ids' => [$store->id],
        'route_request' => null,
        'suggestions' => ['Qual o mais barato?', '', 'Tem promoção?', 42],
    ]);

    $this->postJson('/api/v1/chat', ['message' => 'Quero um tênis'])
        ->assertOk()
        ->assertJsonCount(1, 'data.products')
        ->assertJsonPath('data.products.0.name', 'Tênis de corrida Veloz')
        ->assertJsonPath('data.products.0.price', 299.9)
        ->assertJsonPath('data.products.0.store.name', 'Passo Certo')
        ->assertJsonPath('data.suggestions', ['Qual o mais barato?', 'Tem promoção?']);
});

test('a store named in the reply is returned even when the assistant forgets its id', function () {
    Store::factory()->create(['name' => 'Café Aroma']);
    Store::factory()->create(['name' => 'Outra Loja']);

    fakeAssistantAnswer(['reply' => 'No Café Aroma tem bolo.', 'store_ids' => [], 'route_request' => null]);

    $this->postJson('/api/v1/chat', ['message' => 'Quero um doce'])
        ->assertOk()
        ->assertJsonCount(1, 'data.stores')
        ->assertJsonPath('data.stores.0.name', 'Café Aroma');
});

test('past assistant turns are sent in the json format the model answers in', function () {
    fakeAssistantAnswer(['reply' => 'Ok.', 'store_ids' => [], 'route_request' => null]);

    $this->postJson('/api/v1/chat', [
        'message' => 'E para crianças?',
        'history' => [
            ['role' => 'user', 'content' => 'Oi'],
            ['role' => 'assistant', 'content' => 'Olá!'],
        ],
    ])->assertOk();

    Http::assertSent(function (Request $request) {
        $turn = $request['messages'][2];

        return $turn['role'] === 'assistant' && json_decode($turn['content'], true)['reply'] === 'Olá!';
    });
});

test('an empty answer from the assistant is asked again', function () {
    $content = fn (string $text) => Http::response(['choices' => [['message' => ['content' => $text]]]]);

    Http::fake(['api.deepseek.com/*' => Http::sequence([
        $content('     '),
        $content(json_encode(['reply' => 'Agora sim.', 'store_ids' => [], 'route_request' => null])),
    ])]);

    $this->postJson('/api/v1/chat', ['message' => 'Oi'])
        ->assertOk()
        ->assertJsonPath('data.reply', 'Agora sim.');
});

test('a simple chat question has no route', function () {
    fakeAssistantAnswer(['reply' => 'Abre às 10h.', 'store_id' => null, 'route_request' => null]);

    $this->postJson('/api/v1/chat', ['message' => 'Que horas abre?'])
        ->assertOk()
        ->assertJsonPath('data.route', null);

    Http::assertSentCount(1);
});

test('the chat sends the conversation history to the assistant', function () {
    fakeAssistantAnswer(['reply' => 'Claro!', 'store_id' => null]);

    $history = [
        ['role' => 'user', 'content' => 'Oi'],
        ['role' => 'assistant', 'content' => 'Olá! Como posso ajudar?'],
    ];

    $this->postJson('/api/v1/chat', ['message' => 'Tem cinema?', 'history' => $history])
        ->assertOk()
        ->assertJsonPath('data.store', null);

    Http::assertSent(fn (Request $request) => count($request['messages']) === 4
        && $request['messages'][1] === $history[0]
        && str_contains($request['messages'][2]['content'], 'Olá! Como posso ajudar?'));
});

test('the chat ignores a store the assistant made up', function () {
    fakeAssistantAnswer(['reply' => 'Vá até a loja.', 'store_id' => 999]);

    $this->postJson('/api/v1/chat', ['message' => 'Onde compro?'])
        ->assertOk()
        ->assertJsonPath('data.reply', 'Vá até a loja.')
        ->assertJsonPath('data.store', null);
});

test('the chat falls back when the assistant answer is not valid json', function () {
    Http::fake([
        'api.deepseek.com/*' => Http::response([
            'choices' => [['message' => ['content' => 'texto solto']]],
        ]),
    ]);

    $this->postJson('/api/v1/chat', ['message' => 'Oi'])
        ->assertOk()
        ->assertJsonPath('data.store', null)
        ->assertJsonStructure(['data' => ['reply']]);
});

test('the chat reports the assistant as unavailable when the provider fails', function () {
    Http::fake(['api.deepseek.com/*' => Http::response(['error' => 'down'], 500)]);

    $this->postJson('/api/v1/chat', ['message' => 'Oi'])
        ->assertStatus(503)
        ->assertJsonStructure(['message']);
});

test('the chat requires a message', function () {
    $this->postJson('/api/v1/chat', [])
        ->assertUnprocessable()
        ->assertJsonValidationErrors('message');

    Http::assertNothingSent();
});
