<?php

namespace Database\Factories;

use App\Models\Promotion;
use App\Models\Store;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Promotion>
 */
class PromotionFactory extends Factory
{
    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'store_id' => Store::factory(),
            'title' => fake()->sentence(4),
            'description' => fake()->sentence(),
            'price' => fake()->randomFloat(2, 10, 500),
            'ends_at' => today()->addWeek(),
        ];
    }

    /**
     * Indicate that the promotion has already ended.
     */
    public function expired(): static
    {
        return $this->state(fn (array $attributes) => [
            'ends_at' => today()->subDay(),
        ]);
    }
}
