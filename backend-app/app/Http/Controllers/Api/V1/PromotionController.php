<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\PromotionResource;
use App\Models\Promotion;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class PromotionController extends Controller
{
    /**
     * List the promotions that have not ended yet, soonest to end first.
     */
    public function index(): AnonymousResourceCollection
    {
        $promotions = Promotion::query()
            ->active()
            ->with('store')
            ->orderBy('ends_at')
            ->get();

        return PromotionResource::collection($promotions);
    }
}
