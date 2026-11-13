<?php

namespace App\Models;

use Database\Factories\StoreFactory;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Str;

class Store extends Model
{
    /** @use HasFactory<StoreFactory> */
    use HasFactory;

    /**
     * The attributes that are mass assignable.
     *
     * @var list<string>
     */
    protected $fillable = [
        'name',
        'category',
        'description',
        'floor',
        'opening_hours',
        'latitude',
        'longitude',
        'whatsapp',
    ];

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'floor' => 'integer',
            'latitude' => 'float',
            'longitude' => 'float',
        ];
    }

    /**
     * Path of the store photo, relative to the public directory.
     */
    public function imagePath(): string
    {
        return 'images/catalog/stores/'.Str::slug($this->name).'.jpg';
    }

    /**
     * Public URL of the store photo, or null when no photo was downloaded yet.
     */
    public function imageUrl(): ?string
    {
        return file_exists(public_path($this->imagePath())) ? asset($this->imagePath()) : null;
    }

    /**
     * @return HasMany<Product, $this>
     */
    public function products(): HasMany
    {
        return $this->hasMany(Product::class);
    }

    /**
     * @return HasMany<Promotion, $this>
     */
    public function promotions(): HasMany
    {
        return $this->hasMany(Promotion::class);
    }

    /**
     * @return HasMany<Promotion, $this>
     */
    public function activePromotions(): HasMany
    {
        return $this->promotions()->active();
    }
}
