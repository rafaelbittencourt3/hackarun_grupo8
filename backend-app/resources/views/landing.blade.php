<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Guia do Shopping · o guia que leva você até a loja</title>
    <meta name="description" content="Aplicativo que encontra lojas, produtos e ofertas no shopping, monta um roteiro de compras e guia você até a loja com uma bússola.">
    <meta name="theme-color" content="#172554">
    <style>
        :root {
            --navy: #172554;
            --navy-soft: #22327a;
            --mango: #f59e0b;
            --mango-soft: #ffe8b8;
            --coral: #c2410c;
            --cream: #fbf8f3;
            --paper: #ffffff;
            --ink: #1c1b19;
            --muted: #4d4a44;
            --line: #d5cec2;
            --success: #1f7a4d;
        }

        * { box-sizing: border-box; }

        html { scroll-behavior: smooth; }

        body {
            margin: 0;
            background: var(--cream);
            color: var(--ink);
            font-family: system-ui, -apple-system, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            font-size: 17px;
            line-height: 1.6;
        }

        a { color: inherit; }

        :focus-visible { outline: 3px solid var(--mango); outline-offset: 3px; border-radius: 6px; }

        .wrap { width: 100%; max-width: 1080px; margin: 0 auto; padding: 0 20px; }

        .skip { position: absolute; left: -999px; top: 8px; background: var(--paper); padding: 8px 14px; border-radius: 8px; }
        .skip:focus { left: 8px; z-index: 10; }

        /* Topo */
        .hero { background: var(--navy); color: #fff; border-radius: 0 0 40px 40px; padding-bottom: 72px; overflow: hidden; }

        .nav { display: flex; align-items: center; justify-content: space-between; padding: 22px 0; }
        .brand { display: flex; align-items: center; gap: 10px; font-weight: 700; font-size: 18px; text-decoration: none; }
        .nav-links { display: flex; gap: 22px; font-size: 15px; }
        .nav-links a { text-decoration: none; opacity: .85; }
        .nav-links a:hover { opacity: 1; text-decoration: underline; }

        .hero-grid { display: grid; grid-template-columns: 1.15fr .85fr; gap: 40px; align-items: center; padding-top: 36px; }

        .eyebrow { display: inline-flex; align-items: center; gap: 8px; background: rgba(255, 255, 255, .14); padding: 6px 14px; border-radius: 999px; font-size: 14px; font-weight: 600; }
        .eyebrow i { width: 8px; height: 8px; border-radius: 50%; background: var(--mango); display: inline-block; }

        h1 { font-size: clamp(36px, 6vw, 58px); line-height: 1.05; letter-spacing: -1.5px; margin: 18px 0 16px; font-weight: 800; }
        h1 em { font-style: normal; color: var(--mango); }

        .lead { font-size: 19px; max-width: 34em; color: rgba(255, 255, 255, .88); margin: 0 0 28px; }

        .actions { display: flex; flex-wrap: wrap; gap: 12px; align-items: center; }

        .btn { display: inline-flex; align-items: center; gap: 10px; padding: 15px 24px; border-radius: 16px; font-weight: 700; font-size: 17px; text-decoration: none; border: 2px solid transparent; transition: transform .15s ease, box-shadow .15s ease; }
        .btn:hover { transform: translateY(-2px); }
        .btn-primary { background: var(--mango); color: #2a1800; box-shadow: 0 10px 24px rgba(245, 158, 11, .35); }
        .btn-ghost { border-color: rgba(255, 255, 255, .45); color: #fff; }
        .btn-soon { background: rgba(255, 255, 255, .14); color: #fff; cursor: default; }
        .btn-soon:hover { transform: none; }

        .apk-note { font-size: 14px; color: rgba(255, 255, 255, .75); margin-top: 14px; }

        /* Celular ilustrado */
        .phone { justify-self: center; width: 250px; border-radius: 38px; background: #0d1330; padding: 12px; box-shadow: 0 30px 60px rgba(0, 0, 0, .35); transform: rotate(4deg); }
        .screen { background: var(--cream); border-radius: 28px; padding: 22px 16px 18px; color: var(--ink); text-align: center; }
        .screen small { color: var(--muted); font-size: 12px; }
        .screen strong { display: block; font-size: 17px; margin-top: 2px; }
        .dial { width: 170px; height: 170px; margin: 16px auto 12px; }
        .needle { transform-origin: 85px 85px; animation: seek 5s ease-in-out infinite; }
        .hint { font-size: 20px; font-weight: 800; letter-spacing: -.4px; }
        .bar { height: 8px; border-radius: 8px; background: #e3dcd1; margin: 10px 14px 0; overflow: hidden; }
        .bar span { display: block; height: 100%; width: 68%; background: var(--mango); border-radius: 8px; }

        @keyframes seek {
            0%, 100% { transform: rotate(-38deg); }
            45%, 60% { transform: rotate(8deg); }
        }

        /* Números */
        .stats { display: grid; grid-template-columns: repeat(3, 1fr); gap: 14px; margin-top: -38px; position: relative; }
        .stat { background: var(--paper); border: 1px solid var(--line); border-radius: 22px; padding: 20px; text-align: center; }
        .stat b { display: block; font-size: 34px; line-height: 1.1; color: var(--navy); letter-spacing: -1px; }
        .stat span { color: var(--muted); font-size: 15px; }

        section { padding: 72px 0 0; }

        h2 { font-size: clamp(28px, 4vw, 38px); letter-spacing: -1px; line-height: 1.15; margin: 0 0 10px; }
        .sub { color: var(--muted); max-width: 40em; margin: 0 0 32px; }

        .grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 16px; }

        .card { background: var(--paper); border: 1px solid var(--line); border-radius: 22px; padding: 24px; }
        .card h3 { margin: 14px 0 6px; font-size: 19px; letter-spacing: -.2px; }
        .card p { margin: 0; color: var(--muted); font-size: 16px; }
        .icon { width: 48px; height: 48px; border-radius: 15px; display: grid; place-items: center; }
        .icon svg { width: 26px; height: 26px; }

        .steps { counter-reset: step; display: grid; grid-template-columns: repeat(3, 1fr); gap: 16px; padding: 0; margin: 0; list-style: none; }
        .steps li { counter-increment: step; background: var(--navy); color: #fff; border-radius: 22px; padding: 24px; }
        .steps li::before { content: counter(step); display: grid; place-items: center; width: 38px; height: 38px; border-radius: 50%; background: var(--mango); color: #2a1800; font-weight: 800; margin-bottom: 14px; }
        .steps b { display: block; font-size: 18px; margin-bottom: 4px; }
        .steps span { color: rgba(255, 255, 255, .82); font-size: 16px; }

        .chips { display: flex; flex-wrap: wrap; gap: 10px; padding: 0; margin: 0; list-style: none; }
        .chips li { background: var(--mango-soft); color: #4a2c00; padding: 8px 16px; border-radius: 999px; font-weight: 600; font-size: 15px; }

        .install { background: var(--paper); border: 1px solid var(--line); border-radius: 28px; padding: 32px; display: grid; grid-template-columns: 1fr auto; gap: 28px; align-items: center; }
        .install ol { margin: 0; padding-left: 20px; color: var(--muted); }
        .install .btn-primary { box-shadow: none; }

        code { background: #efe9df; padding: 2px 7px; border-radius: 7px; font-size: .9em; }

        footer { margin-top: 80px; padding: 28px 0 40px; border-top: 1px solid var(--line); color: var(--muted); font-size: 15px; display: flex; flex-wrap: wrap; gap: 8px 24px; justify-content: space-between; }

        @media (max-width: 820px) {
            .hero-grid, .grid, .steps, .install { grid-template-columns: 1fr; }
            .phone { transform: none; margin-top: 8px; }
            .nav-links { display: none; }
            .stats { grid-template-columns: repeat(3, 1fr); gap: 8px; }
            .stat { padding: 14px 8px; }
            .stat b { font-size: 26px; }
            .stat span { font-size: 13px; }
        }

        @media (prefers-reduced-motion: reduce) {
            html { scroll-behavior: auto; }
            .needle { animation: none; transform: rotate(8deg); }
            .btn { transition: none; }
        }
    </style>
</head>
<body>
    <a class="skip" href="#conteudo">Pular para o conteúdo</a>

    <header class="hero">
        <div class="wrap">
            <nav class="nav" aria-label="Principal">
                <a class="brand" href="/">
                    <svg width="30" height="30" viewBox="0 0 48 48" aria-hidden="true">
                        <circle cx="24" cy="24" r="21" fill="none" stroke="#fff" stroke-width="3.2"/>
                        <path d="M24 38 20 24h8zM10 24l14-4v8zM38 24l-14 4v-8z" fill="#fff"/>
                        <path d="M24 7 19.5 24h9z" fill="#f59e0b"/>
                        <circle cx="24" cy="24" r="2.4" fill="#f59e0b"/>
                    </svg>
                    Guia do Shopping
                </a>
                <div class="nav-links">
                    <a href="#recursos">Recursos</a>
                    <a href="#como-funciona">Como funciona</a>
                    <a href="#instalar">Instalar</a>
                    <a href="{{ url('/api/v1/lojas') }}">API</a>
                </div>
            </nav>

            <div class="hero-grid">
                <div>
                    <span class="eyebrow"><i></i> Projeto do Grupo 8 · Engenharia de Software</span>
                    <h1>O guia que <em>leva você</em> até a loja.</h1>
                    <p class="lead">
                        Pergunte o que procura, fotografe um produto ou peça um roteiro.
                        O aplicativo encontra a loja, mostra a oferta e aponta o caminho com uma bússola que fala.
                    </p>

                    <div class="actions">
                        @if ($apk)
                            <a class="btn btn-primary" href="{{ $apk['url'] }}" download>
                                <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 3v12m0 0-5-5m5 5 5-5M5 21h14"/></svg>
                                Baixar para Android
                            </a>
                        @else
                            <span class="btn btn-soon" role="status">Aplicativo para Android em breve</span>
                        @endif
                        <a class="btn btn-ghost" href="#recursos">Conhecer o projeto</a>
                    </div>

                    @if ($apk)
                        <p class="apk-note">Arquivo APK · {{ $apk['size'] }} · Android 5.0 ou mais novo</p>
                    @endif
                </div>

                <div class="phone" aria-hidden="true">
                    <div class="screen">
                        <small>Parada 1 de 3</small>
                        <strong>Passo Certo</strong>
                        <svg class="dial" viewBox="0 0 170 170">
                            <circle cx="85" cy="85" r="82" fill="#eae3d9"/>
                            <g stroke="#7c776e" stroke-width="2" stroke-linecap="round">
                                <path d="M85 8v9M162 85h-9M85 162v-9M8 85h9M139 31l-6 6M139 139l-6-6M31 139l6-6M31 31l6 6"/>
                            </g>
                            <text x="85" y="36" text-anchor="middle" font-size="14" font-weight="800" fill="#c2410c">N</text>
                            <circle cx="85" cy="85" r="50" fill="#172554"/>
                            <path class="needle" d="M85 46 66 112l19-10 19 10z" fill="#fff"/>
                        </svg>
                        <div class="hint">Siga em frente</div>
                        <small>A cerca de 35 m</small>
                        <div class="bar"><span></span></div>
                    </div>
                </div>
            </div>
        </div>
    </header>

    <main id="conteudo">
        <div class="wrap">
            <div class="stats" aria-label="O catálogo de demonstração">
                <div class="stat"><b>{{ $stats['stores'] }}</b><span>lojas e espaços</span></div>
                <div class="stat"><b>{{ $stats['products'] }}</b><span>produtos com foto</span></div>
                <div class="stat"><b>{{ $stats['promotions'] }}</b><span>ofertas ativas</span></div>
            </div>
        </div>

        <section id="recursos">
            <div class="wrap">
                <h2>Não é mais um chat. É um guia.</h2>
                <p class="sub">
                    Responder perguntas qualquer assistente faz. Este entende o que você quer resolver
                    na visita e leva você até lá, parada por parada.
                </p>

                <div class="grid">
                    <article class="card">
                        <div class="icon" style="background:#dce4ff;color:#172554">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M21 12a8 8 0 0 1-11.5 7.2L4 21l1.8-5.5A8 8 0 1 1 21 12Z"/></svg>
                        </div>
                        <h3>Guia que conhece o shopping</h3>
                        <p>Pergunte do seu jeito: produtos, preços, horários, banheiros, estacionamento. Ele responde só com o que existe no catálogo.</p>
                    </article>

                    <article class="card">
                        <div class="icon" style="background:#ffe8b8;color:#4a2c00">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="6" cy="18" r="2.5"/><circle cx="18" cy="6" r="2.5"/><path d="M8.5 18H15a3 3 0 0 0 0-6H9a3 3 0 0 1 0-6h6.5"/></svg>
                        </div>
                        <h3>Roteiro de compras</h3>
                        <p>Diga o que quer, o tempo e o orçamento. O guia organiza as paradas por andar e confere a conta para caber no bolso.</p>
                    </article>

                    <article class="card">
                        <div class="icon" style="background:#ffdbcb;color:#5a1800">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="9"/><path d="m15.5 8.5-2 5-5 2 2-5z"/></svg>
                        </div>
                        <h3>Bússola até a loja</h3>
                        <p>Uma seta grande aponta o caminho, mostra quantos metros faltam e avisa quando você está em frente à loja.</p>
                    </article>

                    <article class="card">
                        <div class="icon" style="background:#e5dbff;color:#3b1f9e">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M4 8h3l2-3h6l2 3h3v11H4z"/><circle cx="12" cy="13" r="3.5"/></svg>
                        </div>
                        <h3>Busca por foto</h3>
                        <p>Viu um produto com alguém? Fotografe. O celular reconhece o que é e o guia mostra onde encontrar algo parecido.</p>
                    </article>

                    <article class="card">
                        <div class="icon" style="background:#d3f5e3;color:#145c39">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="4.5" r="2"/><path d="M5 9h14M12 9v6m0 0-3 6m3-6 3 6"/></svg>
                        </div>
                        <h3>Feito para todos</h3>
                        <p>Instruções por voz, vibração ao chegar, suporte a leitor de tela, letras grandes, modo escuro e contraste conferido.</p>
                    </article>

                    <article class="card">
                        <div class="icon" style="background:#ffe3ec;color:#8a1c46">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M3 12 12 3h8v8l-9 9z"/><circle cx="16" cy="8" r="1.4"/></svg>
                        </div>
                        <h3>Ofertas do dia</h3>
                        <p>As promoções ativas aparecem na tela inicial e nas respostas do guia, com o preço e o prazo de cada uma.</p>
                    </article>
                </div>
            </div>
        </section>

        <section id="como-funciona">
            <div class="wrap">
                <h2>Como funciona</h2>
                <p class="sub">Três passos, do pedido até a porta da loja.</p>

                <ol class="steps">
                    <li><b>Você pede</b><span>“Tenho 1 hora e R$ 300: quero um tênis, um presente e almoçar.”</span></li>
                    <li><b>O guia planeja</b><span>Escolhe os produtos, soma os preços e ordena as lojas para você andar menos.</span></li>
                    <li><b>A bússola leva</b><span>Siga a seta e a voz. Ao chegar, o app avisa e passa para a próxima parada.</span></li>
                </ol>
            </div>
        </section>

        <section id="tecnologia">
            <div class="wrap">
                <h2>Por baixo do capô</h2>
                <p class="sub">
                    O aplicativo consome esta API. Ela guarda o catálogo e conversa com o modelo de linguagem;
                    o reconhecimento de imagem e a voz rodam no próprio celular.
                </p>

                <ul class="chips">
                    <li>Flutter</li>
                    <li>Laravel 12</li>
                    <li>MySQL</li>
                    <li>DeepSeek</li>
                    <li>Google ML Kit</li>
                    <li>Bússola e GPS do aparelho</li>
                    <li>Fotos: Pexels</li>
                </ul>

                <p class="sub" style="margin-top:22px">
                    Experimente a API:
                    <a href="{{ url('/api/v1/lojas') }}"><code>/api/v1/lojas</code></a>
                    <a href="{{ url('/api/v1/promocoes') }}"><code>/api/v1/promocoes</code></a>
                </p>
            </div>
        </section>

        <section id="instalar">
            <div class="wrap">
                <div class="install">
                    <div>
                        <h2>Instale no seu Android</h2>
                        <ol>
                            <li>Baixe o arquivo APK pelo botão ao lado.</li>
                            <li>Abra o arquivo e, se o Android pedir, permita instalar aplicativos desta fonte.</li>
                            <li>Abra o Guia do Shopping e toque em “Simular caminhada” para ver a bússola em ação.</li>
                        </ol>
                    </div>
                    <div>
                        @if ($apk)
                            <a class="btn btn-primary" href="{{ $apk['url'] }}" download>Baixar APK · {{ $apk['size'] }}</a>
                        @else
                            <span class="btn" style="background:#efe9df;color:#4d4a44" role="status">Download em breve</span>
                        @endif
                    </div>
                </div>
            </div>
        </section>

        <div class="wrap">
            <footer>
                <span>Guia do Shopping · Grupo 8 · {{ date('Y') }}</span>
                <span>Shopping, lojas e preços fictícios, criados para demonstração.</span>
            </footer>
        </div>
    </main>
</body>
</html>
