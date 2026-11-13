<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\RoutePlanResource;
use App\Services\ShoppingAssistant;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\Client\RequestException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class RoutePlanController extends Controller
{
    /**
     * Plan an ordered shopping route for what the visitor wants to buy or do.
     */
    public function __invoke(Request $request, ShoppingAssistant $assistant): JsonResponse
    {
        $validated = $request->validate([
            'request' => ['required', 'string', 'max:1000'],
        ]);

        try {
            $plan = $assistant->planRoute($validated['request']);
        } catch (ConnectionException|RequestException $exception) {
            report($exception);

            return response()->json([
                'message' => 'O assistente está indisponível no momento. Tente de novo em instantes.',
            ], 503);
        }

        return response()->json(['data' => new RoutePlanResource($plan)]);
    }
}
