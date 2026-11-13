<?php

use App\Http\Controllers\Api\V1\ChatController;
use App\Http\Controllers\Api\V1\PromotionController;
use App\Http\Controllers\Api\V1\RoutePlanController;
use App\Http\Controllers\Api\V1\StoreController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->name('api.v1.')->group(function () {
    Route::get('lojas', [StoreController::class, 'index'])->name('stores.index');
    Route::get('lojas/{store}', [StoreController::class, 'show'])->name('stores.show');
    Route::get('promocoes', [PromotionController::class, 'index'])->name('promotions.index');
    Route::post('chat', ChatController::class)->middleware('throttle:20,1')->name('chat');
    Route::post('roteiro', RoutePlanController::class)->middleware('throttle:10,1')->name('route-plan');
});
