# Guia do Shopping

Aplicativo que ajuda o visitante a descobrir lojas, produtos e ofertas dentro de um shopping e o leva até a loja com uma bússola. Projeto do Grupo 8 de Engenharia de Software.

O shopping, as lojas e os preços são fictícios, criados para demonstração.

## O que o app faz

- **Guia em linguagem natural:** responde sobre produtos, preços, horários e serviços do shopping, usando apenas o catálogo cadastrado.
- **Roteiro de compras:** a partir do que o visitante quer, do tempo e do orçamento, monta as paradas em ordem e confere a soma.
- **Bússola até a loja:** seta, distância, aviso de chegada, voz e vibração.
- **Busca por foto:** o celular reconhece o produto fotografado e o guia indica onde encontrar algo parecido.
- **Acessibilidade:** leitor de tela, letras grandes, modo escuro e redução de movimento.

## Estrutura

| Pasta | Conteúdo |
|---|---|
| `backend-app/` | API em Laravel 12 (catálogo, guia, roteiro) e a página inicial do projeto |
| `shop_app/` | Aplicativo em Flutter |

## Como rodar o backend

Requer PHP 8.2 ou mais novo, Composer e MySQL.

```bash
cd backend-app
composer install
cp .env.example .env
php artisan key:generate
```

No `.env`, configure o banco (`DB_*`) e a chave do modelo de linguagem (`DEEPSEEK_API_KEY`). Depois:

```bash
php artisan migrate
php artisan db:seed --class=StoreSeeder
php artisan serve
```

Endpoints principais, todos sob `/api/v1`:

| Endpoint | Função |
|---|---|
| `GET /lojas` | Lista as lojas; aceita `?q=` e `?category=` |
| `GET /lojas/{id}` | Loja com produtos e promoções ativas |
| `GET /promocoes` | Promoções ativas |
| `POST /chat` | Pergunta ao guia (texto ou rótulos de uma foto) |
| `POST /roteiro` | Monta um roteiro de compras |

Testes: `php artisan test`.

## Como rodar o aplicativo

Requer Flutter 3.24.

```bash
cd shop_app
flutter pub get
flutter run --dart-define=API_URL=http://SEU_IP:8000/api/v1
```

Sem o `--dart-define`, o app usa o endereço definido em `lib/config.dart`.

Testes: `flutter test`.

## Créditos

As fotos do catálogo vêm do [Pexels](https://www.pexels.com); os autores estão em `backend-app/public/images/catalog/credits.json`.
