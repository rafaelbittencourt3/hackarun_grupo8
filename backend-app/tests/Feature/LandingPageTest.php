<?php

use App\Models\Promotion;
use App\Models\Store;
use Illuminate\Support\Facades\File;

beforeEach(function () {
    config(['services.mobile_app.apk' => 'downloads/teste-landing-xyz.apk']);
});

afterEach(function () {
    File::delete(public_path('downloads/teste-landing-xyz.apk'));
});

test('the landing page presents the project and the catalog numbers', function () {
    $store = Store::factory()->create();
    Promotion::factory()->for($store)->create();
    Promotion::factory()->for($store)->expired()->create();

    $this->get('/')
        ->assertOk()
        ->assertSee('O guia que')
        ->assertSee('Roteiro de compras')
        ->assertSeeInOrder(['<b>1</b>', 'lojas e espaços', '<b>0</b>', 'produtos com foto', '<b>1</b>', 'ofertas ativas'], false);
});

test('the download button is replaced by a notice while the apk is not published', function () {
    $this->get('/')
        ->assertOk()
        ->assertSee('Aplicativo para Android em breve')
        ->assertDontSee('Baixar para Android');
});

test('the download button points to the published apk', function () {
    File::ensureDirectoryExists(public_path('downloads'));
    File::put(public_path('downloads/teste-landing-xyz.apk'), str_repeat('a', 2048));

    $this->get('/')
        ->assertOk()
        ->assertSee('Baixar para Android')
        ->assertSee('downloads/teste-landing-xyz.apk')
        ->assertSee('2 KB')
        ->assertDontSee('em breve');
});
