<?php

namespace Database\Seeders;

use App\Models\Store;
use Illuminate\Database\Seeder;

class StoreSeeder extends Seeder
{
    /**
     * Seed the fictional shopping mall with its stores, products and promotions.
     */
    public function run(): void
    {
        foreach ($this->stores() as $data) {
            $store = Store::updateOrCreate(['name' => $data['name']], [
                'category' => $data['category'],
                'description' => $data['description'],
                'floor' => $data['floor'],
                'opening_hours' => $this->openingHours($data['name'], $data['category']),
                'latitude' => $data['latitude'],
                'longitude' => $data['longitude'],
                'whatsapp' => '5511999990000',
            ]);

            $store->products()->delete();
            $store->promotions()->delete();

            foreach ($data['products'] as [$name, $price]) {
                $store->products()->create(['name' => $name, 'price' => $price]);
            }

            foreach ($data['promotions'] ?? [] as [$title, $description, $price, $days]) {
                $store->promotions()->create([
                    'title' => $title,
                    'description' => $description,
                    'price' => $price,
                    'ends_at' => today()->addDays($days),
                ]);
            }
        }
    }

    /**
     * Opening hours follow the mall, except for food, the pharmacy and the cinema.
     */
    private function openingHours(string $name, string $category): string
    {
        return match (true) {
            $name === 'Cine Estrela' => 'Todos os dias, das 12h à meia-noite; a última sessão começa às 22h',
            $category === 'Alimentação' => 'Todos os dias, das 11h às 23h',
            $category === 'Farmácia' => 'Todos os dias, das 8h às 22h',
            default => 'Segunda a sábado, das 10h às 22h; domingo, das 14h às 20h',
        };
    }

    /**
     * @return list<array{
     *     name: string,
     *     category: string,
     *     description: string,
     *     floor: int,
     *     latitude: float,
     *     longitude: float,
     *     products: list<array{0: string, 1: float}>,
     *     promotions?: list<array{0: string, 1: string, 2: float|null, 3: int}>
     * }>
     */
    private function stores(): array
    {
        return [
            [
                'name' => 'Passo Certo',
                'category' => 'Calçados',
                'description' => 'Tênis esportivos, casuais e sapatos sociais para toda a família.',
                'floor' => 2,
                'latitude' => -23.5502100,
                'longitude' => -46.6336400,
                'products' => [
                    ['Tênis de corrida Veloz', 299.90],
                    ['Tênis casual Urbano', 219.90],
                    ['Sapato social de couro', 349.90],
                    ['Chinelo Conforto', 59.90],
                ],
                'promotions' => [
                    ['Tênis de corrida com desconto', 'Tênis de corrida Veloz de R$ 299,90 por R$ 249,00.', 249.00, 7],
                ],
            ],
            [
                'name' => 'Estilo Urbano',
                'category' => 'Moda',
                'description' => 'Moda masculina e feminina casual: jeans, camisetas e jaquetas.',
                'floor' => 1,
                'latitude' => -23.5504300,
                'longitude' => -46.6331200,
                'products' => [
                    ['Calça jeans slim', 189.90],
                    ['Camiseta básica algodão', 59.90],
                    ['Jaqueta jeans', 259.90],
                    ['Vestido midi floral', 199.90],
                ],
                'promotions' => [
                    ['Leve 3 camisetas, pague 2', 'Na compra de três camisetas básicas, a de menor valor sai de graça.', null, 10],
                ],
            ],
            [
                'name' => 'Bella Moda',
                'category' => 'Moda',
                'description' => 'Moda feminina para festas e trabalho, com vestidos, blusas e acessórios.',
                'floor' => 2,
                'latitude' => -23.5507800,
                'longitude' => -46.6337900,
                'products' => [
                    ['Vestido de festa longo', 459.90],
                    ['Blazer feminino', 329.90],
                    ['Blusa de seda', 179.90],
                    ['Bolsa transversal', 149.90],
                ],
            ],
            [
                'name' => 'TechPoint',
                'category' => 'Eletrônicos',
                'description' => 'Celulares, fones de ouvido, notebooks e acessórios de tecnologia.',
                'floor' => 3,
                'latitude' => -23.5501400,
                'longitude' => -46.6332700,
                'products' => [
                    ['Fone de ouvido bluetooth', 199.90],
                    ['Smartphone Galaxy A', 1499.00],
                    ['Carregador portátil 10000 mAh', 129.90],
                    ['Capinha para celular', 39.90],
                    ['Notebook 15 polegadas', 3299.00],
                ],
                'promotions' => [
                    ['Fone bluetooth em oferta', 'Fone de ouvido bluetooth de R$ 199,90 por R$ 149,90.', 149.90, 5],
                ],
            ],
            [
                'name' => 'GameZone',
                'category' => 'Eletrônicos',
                'description' => 'Consoles, jogos e acessórios para videogame e PC gamer.',
                'floor' => 3,
                'latitude' => -23.5508600,
                'longitude' => -46.6333500,
                'products' => [
                    ['Controle sem fio', 349.90],
                    ['Headset gamer', 279.90],
                    ['Jogo de futebol 2026', 299.90],
                    ['Mouse gamer RGB', 159.90],
                ],
            ],
            [
                'name' => 'Sabor da Praça',
                'category' => 'Alimentação',
                'description' => 'Restaurante de comida brasileira com prato feito, grelhados e saladas.',
                'floor' => 3,
                'latitude' => -23.5505900,
                'longitude' => -46.6339100,
                'products' => [
                    ['Prato feito com frango grelhado', 32.90],
                    ['Feijoada completa', 44.90],
                    ['Salada completa', 27.90],
                    ['Suco natural 500 ml', 12.90],
                ],
                'promotions' => [
                    ['Almoço executivo', 'Prato feito com suco natural por R$ 36,90, de segunda a sexta.', 36.90, 14],
                ],
            ],
            [
                'name' => 'Burger House',
                'category' => 'Alimentação',
                'description' => 'Hambúrgueres artesanais, batatas fritas e milk-shakes.',
                'floor' => 3,
                'latitude' => -23.5503200,
                'longitude' => -46.6338800,
                'products' => [
                    ['Hambúrguer clássico', 28.90],
                    ['Hambúrguer duplo com bacon', 38.90],
                    ['Batata frita grande', 18.90],
                    ['Milk-shake de chocolate', 19.90],
                ],
                'promotions' => [
                    ['Combo da casa', 'Hambúrguer clássico, batata e refrigerante por R$ 39,90.', 39.90, 7],
                ],
            ],
            [
                'name' => 'Café Aroma',
                'category' => 'Alimentação',
                'description' => 'Cafeteria com cafés especiais, bolos, salgados e doces.',
                'floor' => 1,
                'latitude' => -23.5506500,
                'longitude' => -46.6330600,
                'products' => [
                    ['Café expresso', 7.90],
                    ['Cappuccino', 13.90],
                    ['Fatia de bolo de cenoura', 12.90],
                    ['Pão de queijo', 6.90],
                ],
            ],
            [
                'name' => 'Livraria Página Um',
                'category' => 'Livros e Papelaria',
                'description' => 'Livros, quadrinhos, cadernos e material de papelaria.',
                'floor' => 2,
                'latitude' => -23.5500900,
                'longitude' => -46.6334100,
                'products' => [
                    ['Romance best-seller', 54.90],
                    ['Livro infantil ilustrado', 39.90],
                    ['Caderno universitário', 29.90],
                    ['Kit de canetas coloridas', 24.90],
                ],
                'promotions' => [
                    ['Semana do livro', 'Todos os romances com 20% de desconto.', null, 6],
                ],
            ],
            [
                'name' => 'Mundo Kids',
                'category' => 'Brinquedos',
                'description' => 'Brinquedos, jogos de tabuleiro e presentes para crianças.',
                'floor' => 2,
                'latitude' => -23.5509200,
                'longitude' => -46.6335800,
                'products' => [
                    ['Blocos de montar 500 peças', 189.90],
                    ['Boneca articulada', 99.90],
                    ['Carrinho de controle remoto', 149.90],
                    ['Jogo de tabuleiro família', 119.90],
                ],
                'promotions' => [
                    ['Brinquedos com 30% de desconto', 'Jogos de tabuleiro e blocos de montar com 30% de desconto.', null, 9],
                ],
            ],
            [
                'name' => 'Espaço Kids',
                'category' => 'Infantil',
                'description' => 'Área de brincar com monitores para crianças de 3 a 10 anos, ao lado da Mundo Kids.',
                'floor' => 2,
                'latitude' => -23.5509500,
                'longitude' => -46.6336600,
                'products' => [
                    ['Recreação com monitores, 30 minutos', 30.00],
                    ['Recreação com monitores, 1 hora', 50.00],
                ],
            ],
            [
                'name' => 'Beleza Pura',
                'category' => 'Beleza',
                'description' => 'Perfumes, maquiagem e produtos para cuidados com a pele e o cabelo.',
                'floor' => 1,
                'latitude' => -23.5502700,
                'longitude' => -46.6330200,
                'products' => [
                    ['Perfume floral 50 ml', 229.90],
                    ['Base líquida', 79.90],
                    ['Protetor solar FPS 50', 64.90],
                    ['Kit shampoo e condicionador', 89.90],
                ],
                'promotions' => [
                    ['Kit presente', 'Perfume floral com hidratante de brinde por R$ 229,90.', 229.90, 12],
                ],
            ],
            [
                'name' => 'Farmácia Vida',
                'category' => 'Farmácia',
                'description' => 'Medicamentos, higiene pessoal, vitaminas e dermocosméticos.',
                'floor' => 1,
                'latitude' => -23.5508100,
                'longitude' => -46.6331700,
                'products' => [
                    ['Vitamina C 60 comprimidos', 34.90],
                    ['Analgésico 20 comprimidos', 14.90],
                    ['Creme hidratante corporal', 29.90],
                    ['Escova de dentes', 12.90],
                ],
            ],
            [
                'name' => 'Ótica Visão',
                'category' => 'Ótica',
                'description' => 'Óculos de grau, óculos de sol e lentes de contato.',
                'floor' => 1,
                'latitude' => -23.5500600,
                'longitude' => -46.6337200,
                'products' => [
                    ['Óculos de sol aviador', 249.90],
                    ['Armação de grau acetato', 329.90],
                    ['Lentes de contato mensais', 119.90],
                ],
                'promotions' => [
                    ['Segundo par pela metade', 'Na compra de um óculos, o segundo sai com 50% de desconto.', null, 15],
                ],
            ],
            [
                'name' => 'Casa e Conforto',
                'category' => 'Casa e Decoração',
                'description' => 'Decoração, cama, mesa, banho e utilidades domésticas.',
                'floor' => 2,
                'latitude' => -23.5504900,
                'longitude' => -46.6339600,
                'products' => [
                    ['Jogo de cama casal', 199.90],
                    ['Jogo de toalhas 4 peças', 129.90],
                    ['Luminária de mesa', 159.90],
                    ['Conjunto de panelas 5 peças', 389.90],
                ],
            ],
            [
                'name' => 'Sport Mania',
                'category' => 'Esportes',
                'description' => 'Roupas esportivas, bolas, mochilas e equipamentos para academia.',
                'floor' => 2,
                'latitude' => -23.5506900,
                'longitude' => -46.6334700,
                'products' => [
                    ['Camisa de time oficial', 249.90],
                    ['Bola de futebol society', 119.90],
                    ['Mochila esportiva', 149.90],
                    ['Garrafa térmica 1 litro', 69.90],
                    ['Tênis de corrida Maratona', 279.90],
                ],
                'promotions' => [
                    ['Volta aos treinos', 'Mochila esportiva de R$ 149,90 por R$ 109,90.', 109.90, 8],
                ],
            ],
            [
                'name' => 'Cine Estrela',
                'category' => 'Lazer',
                'description' => 'Cinema com cinco salas, sessões 2D e 3D e bomboniere.',
                'floor' => 3,
                'latitude' => -23.5509700,
                'longitude' => -46.6338300,
                'products' => [
                    ['Ingresso inteira', 36.00],
                    ['Ingresso meia', 18.00],
                    ['Combo pipoca e refrigerante', 32.00],
                ],
                'promotions' => [
                    ['Quarta do cinema', 'Todos os ingressos por R$ 15,00 às quartas-feiras.', 15.00, 20],
                ],
            ],
        ];
    }
}
