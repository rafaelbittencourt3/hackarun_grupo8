<?php

use App\Models\Product;
use App\Models\Store;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Facades\Http;

afterEach(function () {
    File::delete([
        public_path('images/catalog/stores/loja-de-teste-xyz.jpg'),
        public_path('images/catalog/products/produto-de-teste-xyz.jpg'),
    ]);
});

test('a store and its products expose their photo url only when the photo exists', function () {
    $store = Store::factory()->create(['name' => 'Loja de Teste XYZ']);
    Product::factory()->for($store)->create(['name' => 'Produto de Teste XYZ']);

    $this->getJson("/api/v1/lojas/{$store->id}")
        ->assertOk()
        ->assertJsonPath('data.image_url', null)
        ->assertJsonPath('data.products.0.image_url', null);

    File::ensureDirectoryExists(public_path('images/catalog/stores'));
    File::ensureDirectoryExists(public_path('images/catalog/products'));
    File::put(public_path('images/catalog/stores/loja-de-teste-xyz.jpg'), 'jpg');
    File::put(public_path('images/catalog/products/produto-de-teste-xyz.jpg'), 'jpg');

    $response = $this->getJson("/api/v1/lojas/{$store->id}")->assertOk();

    expect($response->json('data.image_url'))->toEndWith('/images/catalog/stores/loja-de-teste-xyz.jpg')
        ->and($response->json('data.products.0.image_url'))->toEndWith('/images/catalog/products/produto-de-teste-xyz.jpg');
});

test('the download command refuses to run without a pexels key', function () {
    config(['services.pexels.key' => null]);
    Http::preventStrayRequests();

    $this->artisan('catalog:download-images')->assertFailed();

    Http::assertNothingSent();
});
