<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\StoreResource;
use App\Models\Store;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class StoreController extends Controller
{
    /**
     * List the stores, optionally filtered by a search term or a category.
     */
    public function index(Request $request): AnonymousResourceCollection
    {
        $filters = $request->validate([
            'q' => ['nullable', 'string', 'max:100'],
            'category' => ['nullable', 'string', 'max:100'],
        ]);

        $search = $filters['q'] ?? null;
        $category = $filters['category'] ?? null;

        $stores = Store::query()
            ->with('activePromotions')
            ->when($category, fn (Builder $query) => $query->where('category', $category))
            ->when($search, function (Builder $query) use ($search): void {
                $term = '%'.$search.'%';

                $query->where(function (Builder $query) use ($term): void {
                    $query->where('name', 'like', $term)
                        ->orWhere('category', 'like', $term)
                        ->orWhere('description', 'like', $term)
                        ->orWhereHas('products', fn (Builder $query) => $query->where('name', 'like', $term));
                });
            })
            ->orderBy('name')
            ->get();

        return StoreResource::collection($stores);
    }

    /**
     * Show a store with its products and active promotions.
     */
    public function show(Store $store): StoreResource
    {
        return new StoreResource($store->load(['products', 'activePromotions']));
    }
}
