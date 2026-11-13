<?php

namespace App\Services;

use App\Models\Product;
use App\Models\Store;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\Client\RequestException;
use Illuminate\Support\Facades\Http;

class ShoppingAssistant
{
    /**
     * Minutes the visitor is assumed to spend walking to each stop of a route.
     */
    private const WALKING_MINUTES_PER_STOP = 3;

    /**
     * Ask the assistant a question about the shopping mall.
     *
     * @param  list<array{role: string, content: string}>  $history
     * @param  list<string>  $imageLabels  Labels an image recognizer found in a photo the visitor sent.
     * @return array{
     *     reply: string,
     *     stores: list<Store>,
     *     products: list<array{product: Product, store: Store}>,
     *     suggestions: list<string>,
     *     route: array<string, mixed>|null
     * }
     *
     * @throws ConnectionException
     * @throws RequestException
     */
    public function reply(?string $message, array $history = [], array $imageLabels = []): array
    {
        if ($imageLabels !== []) {
            $message = $this->describePhoto($imageLabels, $message);
        }

        $stores = $this->stores();

        $messages = [
            ['role' => 'system', 'content' => $this->chatPrompt($stores)],
            ...$this->historyAsJson($history),
            ['role' => 'user', 'content' => $message],
        ];

        $answer = $this->ask($messages);

        if ($answer === []) {
            $answer = $this->ask($messages);
        }

        $hasReply = is_string($answer['reply'] ?? null) && $answer['reply'] !== '';

        if (is_string($answer['route_request'] ?? null) && trim($answer['route_request']) !== '') {
            $route = $this->planRoute($answer['route_request']);

            if ($route['stops'] !== [] || ! $hasReply) {
                return [
                    'reply' => $route['summary'],
                    'stores' => [],
                    'products' => [],
                    'suggestions' => [],
                    'route' => $route['stops'] === [] ? null : $route,
                ];
            }
        }

        if (! $hasReply) {
            return [
                'reply' => 'Não consegui entender a resposta agora. Pode perguntar de outro jeito?',
                'stores' => [],
                'products' => [],
                'suggestions' => [],
                'route' => null,
            ];
        }

        $storeIds = is_array($answer['store_ids'] ?? null)
            ? $answer['store_ids']
            : [$answer['store_id'] ?? null];

        $reply = $answer['reply'];

        $chosen = collect($storeIds)
            ->filter(fn ($id) => is_int($id) || (is_string($id) && ctype_digit($id)))
            ->map(fn ($id) => $stores->find((int) $id))
            ->filter();

        if ($chosen->isEmpty()) {
            $chosen = $stores
                ->filter(fn (Store $store) => mb_stripos($reply, $store->name) !== false)
                ->sortBy(fn (Store $store) => mb_stripos($reply, $store->name));
        }

        $productsInReply = $stores
            ->flatMap(fn (Store $store) => $store->products->map(fn ($product) => [
                'product' => $product,
                'store' => $store,
                'position' => mb_stripos($reply, $product->name),
            ]))
            ->filter(fn (array $match) => $match['position'] !== false)
            ->sortBy('position')
            ->take(4)
            ->map(fn (array $match) => ['product' => $match['product'], 'store' => $match['store']])
            ->values()
            ->all();

        $suggestions = collect(is_array($answer['suggestions'] ?? null) ? $answer['suggestions'] : [])
            ->filter(fn ($suggestion) => is_string($suggestion) && trim($suggestion) !== '' && mb_strlen($suggestion) <= 60)
            ->map(fn (string $suggestion) => trim($suggestion))
            ->unique()
            ->take(3)
            ->values()
            ->all();

        return [
            'reply' => $reply,
            'stores' => $chosen
                ->unique('id')
                ->take(3)
                ->values()
                ->all(),
            'products' => $productsInReply,
            'suggestions' => $suggestions,
            'route' => null,
        ];
    }

    /**
     * Plan an ordered shopping route through the mall for what the visitor wants to do.
     *
     * @return array{
     *     summary: string,
     *     total_price: float,
     *     total_minutes: int,
     *     stops: list<array{store: Store, item: string, price: float|null, reason: string, minutes: int}>
     * }
     *
     * @throws ConnectionException
     * @throws RequestException
     */
    public function planRoute(string $request): array
    {
        $stores = $this->stores();

        $messages = [
            ['role' => 'system', 'content' => $this->routePrompt($stores)],
            ['role' => 'user', 'content' => $request],
        ];

        $answer = $this->ask($messages);

        if (! is_array($answer['stops'] ?? null)) {
            $answer = $this->ask($messages);
        }

        $plan = $this->readRoutePlan($answer, $stores);

        if ($plan['problem'] !== null) {
            $plan = $this->readRoutePlan($this->ask([
                ...$messages,
                ['role' => 'assistant', 'content' => json_encode($plan['answer'], JSON_UNESCAPED_UNICODE)],
                ['role' => 'user', 'content' => $plan['problem'].' Refaça o roteiro trocando ou removendo itens até caber. Responda com o JSON completo.'],
            ]), $stores);
        }

        if ($plan['problem'] !== null) {
            $plan['summary'] .= ' Atenção: '.$plan['problem'];
        }

        return [
            'summary' => $plan['summary'],
            'total_price' => $plan['total_price'],
            'total_minutes' => $plan['total_minutes'],
            'stops' => $plan['stops'],
        ];
    }

    /**
     * Validate a route answer from the model and check it against the visitor's limits.
     *
     * @param  array<string, mixed>  $answer
     * @param  Collection<int, Store>  $stores
     * @return array{
     *     answer: array<string, mixed>,
     *     summary: string,
     *     total_price: float,
     *     total_minutes: int,
     *     stops: list<array{store: Store, item: string, price: float|null, reason: string, minutes: int}>,
     *     problem: string|null
     * }
     */
    private function readRoutePlan(array $answer, Collection $stores): array
    {
        $stops = collect(is_array($answer['stops'] ?? null) ? $answer['stops'] : [])
            ->filter(fn ($stop) => is_array($stop) && $stores->find($stop['store_id'] ?? null) !== null)
            ->map(fn (array $stop) => [
                'store' => $stores->find($stop['store_id']),
                'item' => is_string($stop['item'] ?? null) ? $stop['item'] : '',
                'price' => is_numeric($stop['price'] ?? null) ? (float) $stop['price'] : null,
                'reason' => is_string($stop['reason'] ?? null) ? $stop['reason'] : '',
                'minutes' => is_numeric($stop['minutes'] ?? null) ? max(1, (int) $stop['minutes']) : 10,
            ])
            ->values();

        $summary = is_string($answer['summary'] ?? null) && $answer['summary'] !== ''
            ? $answer['summary']
            : ($stops->isEmpty()
                ? 'Não consegui montar um roteiro com esse pedido. Tente descrever o que você quer comprar ou fazer.'
                : 'Aqui está o seu roteiro.');

        $totalPrice = round((float) $stops->sum('price'), 2);
        $totalMinutes = (int) $stops->sum('minutes') + $stops->count() * self::WALKING_MINUTES_PER_STOP;

        $budget = is_numeric($answer['budget'] ?? null) ? (float) $answer['budget'] : null;
        $timeLimit = is_numeric($answer['time_limit'] ?? null) ? (int) $answer['time_limit'] : null;

        $problem = match (true) {
            $budget !== null && $totalPrice > $budget => sprintf(
                'a soma dos preços deu R$ %s, acima do orçamento de R$ %s.',
                number_format($totalPrice, 2, ',', '.'),
                number_format($budget, 2, ',', '.'),
            ),
            $timeLimit !== null && $totalMinutes > $timeLimit => sprintf(
                'o roteiro leva %d minutos contando %d minutos de caminhada por parada, acima dos %d minutos disponíveis.',
                $totalMinutes,
                self::WALKING_MINUTES_PER_STOP,
                $timeLimit,
            ),
            default => null,
        };

        return [
            'answer' => $answer,
            'summary' => $summary,
            'total_price' => $totalPrice,
            'total_minutes' => $totalMinutes,
            'stops' => $stops->all(),
            'problem' => $problem,
        ];
    }

    /**
     * Rewrite past assistant messages in the JSON format the model must answer in.
     *
     * The model answers in JSON mode; when earlier assistant turns are plain text
     * it tends to return an empty answer, so the history has to match the format.
     *
     * @param  list<array{role: string, content: string}>  $history
     * @return list<array{role: string, content: string}>
     */
    private function historyAsJson(array $history): array
    {
        return array_map(fn (array $turn) => $turn['role'] !== 'assistant' ? $turn : [
            'role' => 'assistant',
            'content' => json_encode(
                ['reply' => $turn['content'], 'store_ids' => [], 'route_request' => null],
                JSON_UNESCAPED_UNICODE,
            ),
        ], $history);
    }

    private function walkingMinutes(): int
    {
        return self::WALKING_MINUTES_PER_STOP;
    }

    /**
     * @return Collection<int, Store>
     */
    private function stores(): Collection
    {
        return Store::query()->with(['products', 'activePromotions'])->orderBy('name')->get();
    }

    /**
     * Send the conversation to the model and decode its JSON answer.
     *
     * @param  list<array{role: string, content: string|null}>  $messages
     * @return array<string, mixed>
     *
     * @throws ConnectionException
     * @throws RequestException
     */
    private function ask(array $messages): array
    {
        $response = Http::baseUrl(config('services.deepseek.base_url'))
            ->withToken(config('services.deepseek.key'))
            ->connectTimeout(5)
            ->timeout(40)
            ->post('/chat/completions', [
                'model' => config('services.deepseek.model'),
                'response_format' => ['type' => 'json_object'],
                'temperature' => 0.2,
                'messages' => $messages,
            ])
            ->throw();

        $answer = json_decode((string) $response->json('choices.0.message.content'), true);

        return is_array($answer) ? $answer : [];
    }

    /**
     * Turn the labels recognized in a visitor's photo into a question for the model.
     *
     * @param  list<string>  $imageLabels
     */
    private function describePhoto(array $imageLabels, ?string $message): string
    {
        $question = sprintf(
            'O visitante enviou a foto de um produto. O reconhecimento de imagem identificou estes rótulos, em inglês, do mais provável ao menos provável: %s.',
            implode(', ', $imageLabels),
        );

        if (filled($message)) {
            $question .= ' Ele também escreveu: "'.$message.'".';
        }

        return $question.' Diga em uma frase o que o produto parece ser e indique as lojas do catálogo que vendem algo parecido.';
    }

    /**
     * Date, time and opening hours shared by every prompt.
     */
    private function mallContext(): string
    {
        $now = now('America/Sao_Paulo')->locale('pt_BR')->isoFormat('dddd, D [de] MMMM [de] YYYY, HH:mm');

        return <<<CONTEXT
        Agora são: {$now}.
        Horário do shopping: segunda a sábado, das 10h às 22h; domingo, das 14h às 20h. Alimentação, farmácia e cinema têm horário próprio, indicado em cada loja.
        O shopping tem três andares. A entrada principal fica no 1º andar.

        Serviços e espaços do shopping (não são lojas e não têm id):
        - Banheiros: em todos os andares, ao lado das escadas rolantes. Banheiro família e fraldário no 2º andar.
        - Praça de alimentação: 3º andar, com Sabor da Praça e Burger House. O Café Aroma fica no 1º andar.
        - Balcão de informações e achados e perdidos: 1º andar, na entrada principal.
        - Caixas eletrônicos: 1º andar, ao lado da Farmácia Vida.
        - Estacionamento: subsolo, R$ 12 pelas primeiras 3 horas; grátis com compras acima de R$ 150.
        - Wi-Fi gratuito: rede "Shopping-Visitante", sem senha.
        - Elevadores e acessibilidade: elevadores ao lado das escadas rolantes, cadeiras de rodas no balcão de informações.
        CONTEXT;
    }

    /**
     * Describe every store, with its products and promotions, for the model.
     *
     * @param  Collection<int, Store>  $stores
     */
    private function catalog(Collection $stores): string
    {
        return $stores->map(function (Store $store): string {
            $products = $store->products
                ->map(fn ($product) => sprintf('%s (R$ %s)', $product->name, number_format($product->price, 2, ',', '.')))
                ->implode('; ');

            $promotions = $store->activePromotions
                ->map(fn ($promotion) => sprintf('%s: %s', $promotion->title, $promotion->description))
                ->implode(' | ');

            return sprintf(
                "[id %d] %s — %s, %dº andar. %s\nHorário: %s\nProdutos: %s\nPromoções: %s",
                $store->id,
                $store->name,
                $store->category,
                $store->floor,
                $store->description,
                $store->opening_hours,
                $products ?: 'nenhum cadastrado',
                $promotions ?: 'nenhuma no momento',
            );
        })->implode("\n\n");
    }

    /**
     * Build the instructions and the mall catalog the chat answers from.
     *
     * @param  Collection<int, Store>  $stores
     */
    private function chatPrompt(Collection $stores): string
    {
        return <<<PROMPT
        Você é o assistente virtual de um shopping center. Ajude o visitante com lojas, produtos, promoções, horários de funcionamento e localização dentro do shopping.

        {$this->mallContext()}

        Regras:
        - Responda sempre em português do Brasil, de forma curta e simpática (no máximo 3 frases).
        - Use somente as lojas, produtos, preços, horários e promoções do catálogo abaixo. Nunca invente lojas, produtos, preços ou horários.
        - O visitante escreve de modo informal. Interprete a intenção: "até que horas posso ficar no cinema" é uma pergunta sobre o horário do cinema.
        - Perguntas sobre horário, se algo está aberto agora ou até quando fica aberto devem ser respondidas com o horário da loja e a hora atual.
        - Se o que o visitante procura não existir no catálogo, diga isso e sugira a alternativa mais próxima, se houver. Nunca apresente um produto de outro tipo como se fosse o pedido (chinelo não é tênis).
        - Perguntas sobre banheiro, estacionamento, Wi-Fi e outros serviços devem ser respondidas com a lista de serviços do shopping.
        - Em "store_ids" entram só os lugares para onde o visitante deve ir. Uma loja citada apenas como referência ("ao lado da Mundo Kids") não entra.
        - Quando o visitante informar um valor máximo, sugira apenas produtos com preço igual ou menor que esse valor.
        - Use a conversa anterior para entender mensagens como "qual o mais barato?", "e no 2º andar?" ou "me leva lá".
        - O aplicativo tem uma bússola que guia o visitante até a loja: cada loja listada em "store_ids" aparece para ele com o botão "Me leve até a loja". Quando ele pedir para ser levado ou perguntar como chegar, coloque a loja em "store_ids" e diga para tocar em "Me leve até a loja". Nunca diga que não pode levá-lo. Se não estiver claro qual loja, pergunte qual.
        - Se a pergunta não tiver relação com o shopping, diga educadamente que só pode ajudar com assuntos do shopping.
        - Quando recomendar ou citar uma loja, informe o andar.
        - Você também monta roteiros de compras. Quando o visitante quiser resolver duas ou mais coisas na mesma visita (por exemplo "quero um tênis, um presente e almoçar"), ou pedir um roteiro já dizendo o que quer, preencha "route_request" com o pedido completo: tudo o que ele quer comprar ou fazer, o orçamento e o tempo disponível, juntando o que foi dito nas mensagens anteriores. Outro sistema monta o roteiro a partir desse texto.
        - Se o visitante pedir um roteiro sem dizer o que quer comprar ou fazer, deixe "route_request" como null e pergunte o que ele procura, quanto tempo tem e quanto quer gastar.
        - Para uma pergunta sobre uma única coisa (um produto, uma loja, um horário) ou um pedido genérico ("promoções de hoje", "onde comer", "ideias de presente"), deixe "route_request" como null e responda normalmente, citando as opções do catálogo.
        - O campo "reply" nunca pode ficar vazio, mesmo quando "route_request" estiver preenchido.
        - Mensagens curtas ou incompletas também merecem resposta: entenda como uma busca no catálogo e responda com o que for mais provável.

        Responda exclusivamente com um objeto JSON neste formato:
        {"reply": "texto da resposta ao visitante", "store_ids": [1, 4], "route_request": null, "suggestions": ["Qual é o mais barato?", "Tem promoção?"]}
        Ao citar um produto, escreva o nome exatamente como está no catálogo. Em "suggestions" coloque de 2 a 3 perguntas curtas (até 6 palavras) que o visitante provavelmente faria em seguida, escritas na voz dele e ligadas à sua resposta. Em "store_ids" coloque os ids das lojas que você citou na resposta, da mais relevante para a menos, no máximo 3; use lista vazia quando não citar nenhuma loja. Em "route_request" coloque o pedido de roteiro em texto, ou null.

        Catálogo do shopping:

        {$this->catalog($stores)}

        Antes de responder, confira:
        1. Cada produto que você citou é do tipo que o visitante pediu? Quem pede tênis quer um produto com "Tênis" no nome; chinelo, sapato social e sandália não servem.
        2. Cada sugestão faz sentido para a situação? Presente é algo que se dá a alguém com gosto (livro, perfume, bolsa, jogo, fone, brinquedo, acessório); itens de higiene, remédios e comida do dia a dia não são presentes.
        3. Toda loja citada em "reply" está em "store_ids"?
        4. Os preços respeitam o valor máximo informado?
        PROMPT;
    }

    /**
     * Build the instructions and the mall catalog a shopping route is planned from.
     *
     * @param  Collection<int, Store>  $stores
     */
    private function routePrompt(Collection $stores): string
    {
        return <<<PROMPT
        Você planeja roteiros de compras dentro de um shopping center. O visitante descreve o que quer comprar ou fazer, e às vezes quanto tempo e dinheiro tem. Monte um roteiro com as paradas em ordem.

        {$this->mallContext()}

        Regras:
        - Use somente lojas, produtos e preços do catálogo abaixo. Nunca invente lojas, produtos ou preços.
        - Cada parada atende a um desejo do visitante, com um produto específico do catálogo. Use o preço promocional quando houver promoção ativa para o produto.
        - Se o visitante informar um orçamento, a soma dos preços não pode ultrapassá-lo. Prefira manter todos os desejos escolhendo opções mais baratas de cada um, em vez de gastar quase tudo em um só item.
        - Se o visitante informar o tempo disponível, o roteiro precisa caber nele. Estime os minutos gastos em cada parada (uma compra simples leva 10 minutos; uma refeição, de 20 a 40; um filme, 120) e some {$this->walkingMinutes()} minutos de caminhada por parada.
        - Um presente pode ser qualquer produto adequado à pessoa, de qualquer loja (livro, cosmético, bolsa, brinquedo, acessório). Considere as opções mais baratas de todas as lojas antes de desistir de um desejo.
        - Respeite o desejo exato: se o visitante pediu um tênis, não troque por chinelo. Se não couber, diga isso no resumo.
        - Antes de responder, faça as contas no campo "calculation", em no máximo 4 frases: some os preços e os minutos e compare com os limites.
        - Ordene as paradas para o visitante andar menos: ele começa na entrada, no 1º andar, e sobe um andar por vez. Agrupe as paradas do mesmo andar. Deixe refeição e cinema para o fim, a menos que o visitante peça outra ordem.
        - No máximo 6 paradas, sem repetir loja.
        - Se algum desejo não puder ser atendido pelo catálogo, pelo orçamento ou pelo tempo, explique isso no resumo.
        - No resumo, não cite o total em reais nem o total de minutos: o aplicativo calcula e mostra esses totais.
        - Escreva em português do Brasil.

        Responda exclusivamente com um objeto JSON neste formato:
        {"budget": 300, "time_limit": 60, "calculation": "229,90 + 59,90 = 289,80; 10 + 10 + 6 = 26 min", "summary": "resumo do roteiro em até 2 frases", "stops": [{"store_id": 1, "item": "nome do produto", "price": 99.90, "reason": "por que esta parada, em uma frase curta", "minutes": 15}]}
        Em "budget" coloque o orçamento do visitante em reais e em "time_limit" o tempo disponível em minutos, ou null quando ele não informar. Em "price" coloque o preço do item como número, ou null quando não houver compra na parada. Se não for possível montar nenhum roteiro, devolva "stops" como lista vazia.

        Catálogo do shopping:

        {$this->catalog($stores)}
        PROMPT;
    }
}
