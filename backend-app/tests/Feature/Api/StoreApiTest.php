<?php

use App\Models\Product;
use App\Models\Promotion;
use App\Models\Store;

test('stores can be listed', function () {
    Store::factory()->count(3)->create();

    $this->getJson('/api/v1/lojas')
        ->assertOk()
        ->assertJsonCount(3, 'data')
        ->assertJsonStructure(['data' => [['id', 'name', 'category', 'floor', 'latitude', 'longitude', 'promotions']]]);
});

test('stores can be searched by product name', function () {
    $shoeStore = Store::factory()->create(['name' => 'Passo Certo']);
    Product::factory()->for($shoeStore)->create(['name' => 'Tênis de corrida']);
    Store::factory()->create(['name' => 'Café Aroma', 'category' => 'Alimentação', 'description' => 'Cafeteria']);

    $this->getJson('/api/v1/lojas?q=corrida')
        ->assertOk()
        ->assertJsonCount(1, 'data')
        ->assertJsonPath('data.0.name', 'Passo Certo');
});

test('stores can be filtered by category', function () {
    Store::factory()->create(['category' => 'Moda']);
    Store::factory()->create(['category' => 'Esportes']);

    $this->getJson('/api/v1/lojas?category=Esportes')
        ->assertOk()
        ->assertJsonCount(1, 'data')
        ->assertJsonPath('data.0.category', 'Esportes');
});

test('a store shows its products and only its active promotions', function () {
    $store = Store::factory()->create();
    Product::factory()->for($store)->count(2)->create();
    Promotion::factory()->for($store)->create(['title' => 'Oferta válida']);
    Promotion::factory()->for($store)->expired()->create();

    $this->getJson("/api/v1/lojas/{$store->id}")
        ->assertOk()
        ->assertJsonCount(2, 'data.products')
        ->assertJsonCount(1, 'data.promotions')
        ->assertJsonPath('data.promotions.0.title', 'Oferta válida');
});

test('an unknown store returns not found', function () {
    $this->getJson('/api/v1/lojas/999')->assertNotFound();
});

test('only active promotions are listed with their store', function () {
    $store = Store::factory()->create(['name' => 'TechPoint']);
    Promotion::factory()->for($store)->create(['title' => 'Fone em oferta']);
    Promotion::factory()->for($store)->expired()->create();

    $this->getJson('/api/v1/promocoes')
        ->assertOk()
        ->assertJsonCount(1, 'data')
        ->assertJsonPath('data.0.title', 'Fone em oferta')
        ->assertJsonPath('data.0.store.name', 'TechPoint');
});
