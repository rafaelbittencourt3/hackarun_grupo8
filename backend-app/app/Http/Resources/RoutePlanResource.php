<?php

namespace App\Http\Resources;

use App\Models\Store;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Wraps the route plan array built by the shopping assistant.
 *
 * @property array{
 *     summary: string,
 *     total_price: float,
 *     total_minutes: int,
 *     stops: list<array{store: Store, item: string, price: float|null, reason: string, minutes: int}>
 * } $resource
 */
class RoutePlanResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'summary' => $this->resource['summary'],
            'total_price' => $this->resource['total_price'],
            'total_minutes' => $this->resource['total_minutes'],
            'stops' => array_map(fn (array $stop) => [
                'store' => new StoreResource($stop['store']),
                'item' => $stop['item'],
                'price' => $stop['price'],
                'reason' => $stop['reason'],
                'minutes' => $stop['minutes'],
            ], $this->resource['stops']),
        ];
    }
}
