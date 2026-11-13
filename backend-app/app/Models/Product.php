<?php

namespace App\Models;

use Database\Factories\ProductFactory;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Str;

class Product extends Model
{
    /** @use HasFactory<ProductFactory> */
    use HasFactory;

    /**
     * The attributes that are mass assignable.
     *
     * @var list<string>
     */
    protected $fillable = [
        'store_id',
        'name',
        'description',
        'price',
    ];

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'price' => 'float',
        ];
    }

    /**
     * Path of the product photo, relative to the public directory.
     */
    public function imagePath(): string
    {
        return 'images/catalog/products/'.Str::slug($this->name).'.jpg';
    }

    /**
     * Public URL of the product photo, or null when no photo was downloaded yet.
     */
    public function imageUrl(): ?string
    {
        return file_exists(public_path($this->imagePath())) ? asset($this->imagePath()) : null;
    }

    /**
     * @return BelongsTo<Store, $this>
     */
    public function store(): BelongsTo
    {
        return $this->belongsTo(Store::class);
    }
}
