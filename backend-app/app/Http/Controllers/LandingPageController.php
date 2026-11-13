<?php

namespace App\Http\Controllers;

use App\Models\Product;
use App\Models\Promotion;
use App\Models\Store;
use Illuminate\Contracts\View\View;

class LandingPageController extends Controller
{
    /**
     * Show the project landing page, with the Android download when the APK was published.
     */
    public function __invoke(): View
    {
        $apkPath = config('services.mobile_app.apk');
        $apkFile = public_path($apkPath);

        return view('landing', [
            'apk' => is_file($apkFile)
                ? ['url' => asset($apkPath), 'size' => $this->readableSize(filesize($apkFile))]
                : null,
            'stats' => [
                'stores' => Store::count(),
                'products' => Product::count(),
                'promotions' => Promotion::active()->count(),
            ],
        ]);
    }

    /**
     * Format a file size the way it is written in Brazil, such as "24,3 MB".
     */
    private function readableSize(int $bytes): string
    {
        return $bytes >= 1024 * 1024
            ? number_format($bytes / (1024 * 1024), 1, ',', '.').' MB'
            : number_format($bytes / 1024, 0, ',', '.').' KB';
    }
}
