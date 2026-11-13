<?php

namespace App\Console\Commands;

use App\Models\Product;
use App\Models\Store;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Facades\Http;
use Throwable;

class DownloadCatalogImages extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'catalog:download-images {--force : Download again the images that already exist}';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Download a free Pexels photo for every store and product of the catalog';

    /**
     * English search terms for each store and product, keyed by its name.
     * Anything missing here is searched by its own name.
     *
     * @var array<string, string>
     */
    private const SEARCH_TERMS = [
        // Stores
        'Passo Certo' => 'shoe store shelves',
        'Estilo Urbano' => 'clothing store casual',
        'Bella Moda' => 'women fashion boutique',
        'TechPoint' => 'electronics store gadgets',
        'GameZone' => 'video game store',
        'Sabor da Praça' => 'brazilian restaurant food',
        'Burger House' => 'burger restaurant',
        'Café Aroma' => 'coffee shop counter',
        'Livraria Página Um' => 'bookstore shelves',
        'Mundo Kids' => 'colorful toys',
        'Espaço Kids' => 'kids indoor playground',
        'Beleza Pura' => 'cosmetics store',
        'Farmácia Vida' => 'pharmacy shelves',
        'Ótica Visão' => 'eyeglasses store display',
        'Casa e Conforto' => 'home decor cushions living room',
        'Sport Mania' => 'sporting goods store',
        'Cine Estrela' => 'movie theater seats',

        // Products
        'Tênis de corrida Veloz' => 'running shoes',
        'Tênis casual Urbano' => 'white sneakers closeup',
        'Sapato social de couro' => 'leather dress shoes',
        'Chinelo Conforto' => 'flip flops',
        'Calça jeans slim' => 'blue jeans',
        'Camiseta básica algodão' => 'plain t-shirt',
        'Jaqueta jeans' => 'denim jacket',
        'Vestido midi floral' => 'floral dress',
        'Vestido de festa longo' => 'evening gown',
        'Blazer feminino' => 'women blazer',
        'Blusa de seda' => 'silk blouse',
        'Bolsa transversal' => 'crossbody bag',
        'Fone de ouvido bluetooth' => 'wireless headphones',
        'Smartphone Galaxy A' => 'smartphone',
        'Carregador portátil 10000 mAh' => 'power bank',
        'Capinha para celular' => 'phone case',
        'Notebook 15 polegadas' => 'laptop computer',
        'Controle sem fio' => 'game controller',
        'Headset gamer' => 'gaming headphones',
        'Jogo de futebol 2026' => 'video game console soccer',
        'Mouse gamer RGB' => 'gaming mouse',
        'Prato feito com frango grelhado' => 'grilled chicken rice beans plate',
        'Feijoada completa' => 'black beans stew',
        'Salada completa' => 'salad bowl',
        'Suco natural 500 ml' => 'orange juice glass',
        'Hambúrguer clássico' => 'cheeseburger',
        'Hambúrguer duplo com bacon' => 'double bacon burger',
        'Batata frita grande' => 'french fries',
        'Milk-shake de chocolate' => 'chocolate milkshake',
        'Café expresso' => 'espresso cup',
        'Cappuccino' => 'cappuccino',
        'Fatia de bolo de cenoura' => 'carrot cake slice',
        'Pão de queijo' => 'cheese bread balls',
        'Romance best-seller' => 'novel book',
        'Livro infantil ilustrado' => 'kids book',
        'Caderno universitário' => 'spiral notebook',
        'Kit de canetas coloridas' => 'colorful markers',
        'Blocos de montar 500 peças' => 'lego bricks',
        'Boneca articulada' => 'doll',
        'Carrinho de controle remoto' => 'rc car',
        'Jogo de tabuleiro família' => 'board game',
        'Recreação com monitores, 30 minutos' => 'children playing ball pit',
        'Recreação com monitores, 1 hora' => 'kids playing playground indoor',
        'Perfume floral 50 ml' => 'perfume bottle',
        'Base líquida' => 'liquid foundation makeup',
        'Protetor solar FPS 50' => 'sunscreen bottle',
        'Kit shampoo e condicionador' => 'shampoo bottles',
        'Vitamina C 60 comprimidos' => 'vitamin pills bottle',
        'Analgésico 20 comprimidos' => 'pills blister pack',
        'Creme hidratante corporal' => 'body lotion',
        'Escova de dentes' => 'toothbrush',
        'Óculos de sol aviador' => 'aviator sunglasses',
        'Armação de grau acetato' => 'eyeglasses',
        'Lentes de contato mensais' => 'contact lens case',
        'Jogo de cama casal' => 'bed linen bedroom',
        'Jogo de toalhas 4 peças' => 'folded towels',
        'Luminária de mesa' => 'desk lamp',
        'Conjunto de panelas 5 peças' => 'cooking pots set',
        'Camisa de time oficial' => 'soccer jersey',
        'Bola de futebol society' => 'soccer ball',
        'Mochila esportiva' => 'sports backpack',
        'Garrafa térmica 1 litro' => 'thermos bottle',
        'Tênis de corrida Maratona' => 'running sneakers closeup',
        'Ingresso inteira' => 'ticket stub',
        'Ingresso meia' => 'movie tickets',
        'Combo pipoca e refrigerante' => 'popcorn bucket',
    ];

    /**
     * Pexels photo ids already used, so two items never share a photo.
     *
     * @var array<int, true>
     */
    private array $usedPhotoIds = [];

    /**
     * Execute the console command.
     */
    public function handle(): int
    {
        if (blank(config('services.pexels.key'))) {
            $this->error('Defina PEXELS_API_KEY no arquivo .env (chave gratuita em https://www.pexels.com/api/).');

            return self::FAILURE;
        }

        $creditsPath = public_path('images/catalog/credits.json');
        $credits = File::exists($creditsPath) ? File::json($creditsPath) : [];

        foreach ($credits as $credit) {
            $this->usedPhotoIds[$credit['photo_id']] = true;
        }

        $items = Store::query()->orderBy('name')->get()
            ->map(fn (Store $store) => ['name' => $store->name, 'path' => $store->imagePath(), 'size' => 'large'])
            ->concat(Product::query()->orderBy('name')->get()
                ->map(fn (Product $product) => ['name' => $product->name, 'path' => $product->imagePath(), 'size' => 'medium']));

        $downloaded = 0;
        $failed = [];

        foreach ($items as $item) {
            $file = public_path($item['path']);

            if (File::exists($file) && ! $this->option('force')) {
                continue;
            }

            try {
                $photo = $this->findPhoto(self::SEARCH_TERMS[$item['name']] ?? $item['name']);

                if ($photo === null) {
                    $failed[] = $item['name'];

                    continue;
                }

                File::ensureDirectoryExists(dirname($file));
                File::put($file, Http::timeout(30)->retry(4, 2500)->get($photo['src'][$item['size']])->throw()->body());

                $credits[$item['path']] = [
                    'photo_id' => $photo['id'],
                    'photographer' => $photo['photographer'],
                    'url' => $photo['url'],
                ];
                $downloaded++;

                $this->line("ok  {$item['name']}");
            } catch (Throwable $exception) {
                $failed[] = $item['name'];
                $this->warn("falhou  {$item['name']}: {$exception->getMessage()}");
            }

            usleep(900_000);
        }

        File::ensureDirectoryExists(dirname($creditsPath));
        File::put($creditsPath, json_encode($credits, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES));

        $this->info("{$downloaded} imagens baixadas. Créditos em public/images/catalog/credits.json.");

        if ($failed !== []) {
            $this->warn('Sem imagem: '.implode(', ', $failed));
        }

        return self::SUCCESS;
    }

    /**
     * Find the first Pexels photo for the search term that is not in use yet.
     *
     * @return array{id: int, photographer: string, url: string, src: array<string, string>}|null
     */
    private function findPhoto(string $term): ?array
    {
        $photos = Http::withHeaders(['Authorization' => config('services.pexels.key')])
            ->connectTimeout(5)
            ->timeout(20)
            ->retry(4, 2500)
            ->get('https://api.pexels.com/v1/search', [
                'query' => $term,
                'per_page' => 10,
                'orientation' => 'square',
            ])
            ->throw()
            ->json('photos', []);

        foreach ($photos as $photo) {
            if (! isset($this->usedPhotoIds[$photo['id']])) {
                $this->usedPhotoIds[$photo['id']] = true;

                return $photo;
            }
        }

        return null;
    }
}
