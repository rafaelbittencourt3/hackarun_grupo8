<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\ChatRequest;
use App\Http\Resources\RoutePlanResource;
use App\Http\Resources\StoreResource;
use App\Services\ShoppingAssistant;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\Client\RequestException;
use Illuminate\Http\JsonResponse;

class ChatController extends Controller
{
    /**
     * Answer a visitor's message with the shopping assistant.
     */
    public function __invoke(ChatRequest $request, ShoppingAssistant $assistant): JsonResponse
    {
        try {
            $answer = $assistant->reply(
                $request->validated('message'),
                $request->validated('history', []),
                $request->validated('image_labels', []),
            );
        } catch (ConnectionException|RequestException $exception) {
            report($exception);

            return response()->json([
                'message' => 'O assistente está indisponível no momento. Tente de novo em instantes.',
            ], 503);
        }

        return response()->json([
            'data' => [
                'reply' => $answer['reply'],
                'store' => $answer['stores'] === [] ? null : new StoreResource($answer['stores'][0]),
                'stores' => StoreResource::collection($answer['stores']),
                'products' => array_map(fn (array $match) => [
                    'id' => $match['product']->id,
                    'name' => $match['product']->name,
                    'price' => $match['product']->price,
                    'image_url' => $match['product']->imageUrl(),
                    'store' => new StoreResource($match['store']->withoutRelations()),
                ], $answer['products']),
                'suggestions' => $answer['suggestions'],
                'route' => $answer['route'] ? new RoutePlanResource($answer['route']) : null,
            ],
        ]);
    }
}
