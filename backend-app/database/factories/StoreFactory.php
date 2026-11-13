<?php

namespace Database\Factories;

use App\Models\Store;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Store>
 */
class StoreFactory extends Factory
{
    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'name' => fake()->unique()->company(),
            'category' => fake()->randomElement(['Moda', 'Calçados', 'Eletrônicos', 'Alimentação']),
            'description' => fake()->sentence(),
            'floor' => fake()->numberBetween(1, 3),
            'opening_hours' => 'Segunda a sábado, das 10h às 22h; domingo, das 14h às 20h',
            'latitude' => fake()->latitude(-23.5510, -23.5500),
            'longitude' => fake()->longitude(-46.6340, -46.6330),
            'whatsapp' => fake()->numerify('55119########'),
        ];
    }
}
