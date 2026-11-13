<?php

use App\Models\Store;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Http;

beforeEach(function () {
    config(['services.deepseek.key' => 'test-key']);
    Http::preventStrayRequests();
});

function fakeRoutePlan(array $plan): void
{
    Http::fake([
        'api.deepseek.com/*' => Http::response([
            'choices' => [['message' => ['content' => json_encode($plan)]]],
        ]),
    ]);
}

test('a route is planned with its stops and totals', function () {
    $shoes = Store::factory()->create(['name' => 'Passo Certo', 'floor' => 2]);
    $food = Store::factory()->create(['name' => 'Burger House', 'floor' => 3]);

    fakeRoutePlan([
        'summary' => 'Tênis e depois almoço.',
        'stops' => [
            ['store_id' => $shoes->id, 'item' => 'Tênis de corrida', 'price' => 249, 'reason' => 'Está em promoção.', 'minutes' => 15],
            ['store_id' => $food->id, 'item' => 'Combo da casa', 'price' => 39.9, 'reason' => 'Almoço rápido.', 'minutes' => 30],
        ],
    ]);

    $this->postJson('/api/v1/roteiro', ['request' => 'Quero um tênis e almoçar com R$ 300'])
        ->assertOk()
        ->assertJsonPath('data.summary', 'Tênis e depois almoço.')
        ->assertJsonPath('data.total_price', 288.9)
        ->assertJsonPath('data.total_minutes', 51)
        ->assertJsonCount(2, 'data.stops')
        ->assertJsonPath('data.stops.0.store.name', 'Passo Certo')
        ->assertJsonPath('data.stops.0.item', 'Tênis de corrida')
        ->assertJsonPath('data.stops.1.store.floor', 3);

    Http::assertSent(fn (Request $request) => collect($request['messages'])->last() === [
        'role' => 'user',
        'content' => 'Quero um tênis e almoçar com R$ 300',
    ]);
});

test('a route over the budget is sent back to the assistant to be fixed', function () {
    $store = Store::factory()->create();
    $answer = fn (float $price) => Http::response([
        'choices' => [['message' => ['content' => json_encode([
            'budget' => 100,
            'time_limit' => null,
            'summary' => 'Roteiro.',
            'stops' => [['store_id' => $store->id, 'item' => 'Item', 'price' => $price, 'reason' => 'x', 'minutes' => 10]],
        ])]]],
    ]);

    Http::fake(['api.deepseek.com/*' => Http::sequence([$answer(150), $answer(90)])]);

    $this->postJson('/api/v1/roteiro', ['request' => 'Tenho R$ 100'])
        ->assertOk()
        ->assertJsonPath('data.total_price', 90)
        ->assertJsonPath('data.summary', 'Roteiro.');

    Http::assertSentCount(2);
});

test('a route still over the budget after the fix says so in the summary', function () {
    $store = Store::factory()->create();

    fakeRoutePlan([
        'budget' => 100,
        'summary' => 'Roteiro.',
        'stops' => [['store_id' => $store->id, 'item' => 'Item', 'price' => 150, 'reason' => 'x', 'minutes' => 10]],
    ]);

    $response = $this->postJson('/api/v1/roteiro', ['request' => 'Tenho R$ 100'])->assertOk();

    expect($response->json('data.summary'))->toContain('acima do orçamento de R$ 100,00');
});

test('stops in stores the assistant made up are dropped from the route', function () {
    $store = Store::factory()->create();

    fakeRoutePlan([
        'summary' => 'Duas paradas.',
        'stops' => [
            ['store_id' => 999, 'item' => 'Algo', 'price' => 10, 'reason' => 'x', 'minutes' => 10],
            ['store_id' => $store->id, 'item' => 'Livro', 'price' => 50, 'reason' => 'y', 'minutes' => 10],
        ],
    ]);

    $this->postJson('/api/v1/roteiro', ['request' => 'Quero um livro'])
        ->assertOk()
        ->assertJsonCount(1, 'data.stops')
        ->assertJsonPath('data.stops.0.store.id', $store->id)
        ->assertJsonPath('data.total_price', 50);
});

test('an unusable answer returns an empty route with an explanation', function () {
    Http::fake([
        'api.deepseek.com/*' => Http::response([
            'choices' => [['message' => ['content' => 'texto solto']]],
        ]),
    ]);

    $this->postJson('/api/v1/roteiro', ['request' => 'Qualquer coisa'])
        ->assertOk()
        ->assertJsonCount(0, 'data.stops')
        ->assertJsonPath('data.total_minutes', 0)
        ->assertJsonStructure(['data' => ['summary']]);

    Http::assertSentCount(2);
});

test('the route reports the assistant as unavailable when the provider fails', function () {
    Http::fake(['api.deepseek.com/*' => Http::response(['error' => 'down'], 500)]);

    $this->postJson('/api/v1/roteiro', ['request' => 'Quero um tênis'])
        ->assertStatus(503)
        ->assertJsonStructure(['message']);
});

test('the route requires a request', function () {
    $this->postJson('/api/v1/roteiro', [])
        ->assertUnprocessable()
        ->assertJsonValidationErrors('request');

    Http::assertNothingSent();
});
