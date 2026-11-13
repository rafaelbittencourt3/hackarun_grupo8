<?php

namespace App\Http\Resources;

use App\Models\Store;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin Store
 */
class StoreResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'category' => $this->category,
            'description' => $this->description,
            'floor' => $this->floor,
            'opening_hours' => $this->opening_hours,
            'latitude' => $this->latitude,
            'longitude' => $this->longitude,
            'whatsapp' => $this->whatsapp,
            'image_url' => $this->imageUrl(),
            'products' => ProductResource::collection($this->whenLoaded('products')),
            'promotions' => PromotionResource::collection($this->whenLoaded('activePromotions')),
        ];
    }
}
