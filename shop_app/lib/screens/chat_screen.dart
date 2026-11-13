import 'dart:io';

import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../photo_search.dart';
import '../theme.dart';
import '../widgets/brand.dart';
import '../widgets/common.dart';
import '../widgets/route_card.dart';
import 'store_detail_screen.dart';

/// Ação que outra tela pede ao guia ao abri-lo.
enum ChatAction { route, photo }

/// A tela inicial grava aqui a ação desejada; o guia executa e limpa.
final chatAction = ValueNotifier<ChatAction?>(null);

class ChatMessage {
  const ChatMessage({
    required this.text,
    required this.fromUser,
    this.stores = const [],
    this.products = const [],
    this.suggestions = const [],
    this.isError = false,
    this.imagePath,
    this.route,
  });

  /// Texto mostrado na conversa e enviado como histórico ao assistente.
  final String text;
  final bool fromUser;

  /// Lojas citadas na resposta; cada uma vira um cartão com a bússola.
  final List<Store> stores;

  /// Produtos citados na resposta, mostrados com foto e preço.
  final List<ChatProduct> products;

  /// Próximas perguntas sugeridas pelo guia.
  final List<String> suggestions;
  final bool isError;

  /// Foto enviada pelo visitante; quando existe, a mensagem mostra a foto.
  final String? imagePath;

  /// Roteiro de compras que acompanha a resposta do assistente.
  final RoutePlan? route;
}

/// Atalho de pergunta pronta: o rótulo aparece na tela e a pergunta completa
/// é o que vai para o assistente.
class _Shortcut {
  const _Shortcut(this.icon, this.label, this.question);

  final IconData icon;
  final String label;
  final String question;
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const _shortcuts = [
    _Shortcut(
      Icons.local_offer_outlined,
      'Promoções de hoje',
      'Quais são as promoções de hoje no shopping?',
    ),
    _Shortcut(
      Icons.restaurant_outlined,
      'Onde comer',
      'Onde posso comer no shopping? Quais são as opções e os preços?',
    ),
    _Shortcut(
      Icons.card_giftcard_outlined,
      'Ideias de presente',
      'Me dê ideias de presente, com loja e preço.',
    ),
  ];

  static const _examples = [
    'Onde tem tênis de corrida até R\$ 300?',
    'O que tem para fazer com criança?',
    'O cinema está aberto agora?',
  ];

  static const _routeExample =
      'Tenho 1 hora e R\$ 300: quero um tênis, um presente para minha mãe e almoçar';

  final _input = TextEditingController();
  final _inputFocus = FocusNode();
  final _scroll = ScrollController();
  final _messages = <ChatMessage>[];
  bool _waiting = false;
  String _waitingLabel = '';

  @override
  void initState() {
    super.initState();
    chatAction.addListener(_runRequestedAction);
  }

  void _runRequestedAction() {
    final action = chatAction.value;
    if (action == null) {
      return;
    }

    chatAction.value = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _waiting) {
        return;
      }

      switch (action) {
        case ChatAction.route:
          _suggestRoute();
        case ChatAction.photo:
          _choosePhoto();
      }
    });
  }

  @override
  void dispose() {
    chatAction.removeListener(_runRequestedAction);
    _input.dispose();
    _inputFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String text, {String? shownAs}) async {
    final message = text.trim();
    if (message.isEmpty || _waiting) {
      return;
    }

    _input.clear();
    await _ask(
      ChatMessage(text: shownAs ?? message, fromUser: true),
      message: message,
    );
  }

  /// Preenche o campo com um exemplo de roteiro para o visitante adaptar.
  void _suggestRoute() {
    _input.text = _routeExample;
    _input.selection = TextSelection.collapsed(offset: _input.text.length);
    _inputFocus.requestFocus();
  }

  Future<void> _choosePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tirar foto'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Escolher da galeria'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || _waiting) {
      return;
    }

    final String? path;
    try {
      path = await pickPhoto(source);
    } on Exception {
      _addAssistantError('Não foi possível abrir a câmera ou a galeria.');
      return;
    }
    if (path == null || !mounted) {
      return;
    }

    setState(() {
      _waiting = true;
      _waitingLabel = 'Reconhecendo o produto na foto…';
    });
    _scrollToEnd();

    List<String> labels;
    try {
      labels = await labelPhoto(path);
    } on Exception {
      labels = const [];
    }
    if (!mounted) {
      return;
    }

    if (labels.isEmpty) {
      setState(() {
        _waiting = false;
        _messages.add(ChatMessage(text: 'Foto de um produto', fromUser: true, imagePath: path));
      });
      _addAssistantError(
        'Não consegui identificar o produto na foto. Tente outra foto ou descreva o que procura.',
      );
      return;
    }

    setState(() => _waiting = false);
    await _ask(
      ChatMessage(
        text: 'Foto de um produto (${labels.join(', ')})',
        fromUser: true,
        imagePath: path,
      ),
      imageLabels: labels,
    );
  }

  void _addAssistantError(String text) {
    if (!mounted) {
      return;
    }

    setState(() {
      _messages.add(ChatMessage(text: text, fromUser: false, isError: true));
    });
    _scrollToEnd();
  }

  /// Mostra a mensagem do visitante e pede a resposta ao assistente.
  Future<void> _ask(
    ChatMessage userMessage, {
    String? message,
    List<String> imageLabels = const [],
  }) async {
    final history = _messages
        .where((item) => !item.isError)
        .map((item) => {
              'role': item.fromUser ? 'user' : 'assistant',
              'content': item.text,
            })
        .toList();
    final recent = history.length > 10 ? history.sublist(history.length - 10) : history;

    setState(() {
      _messages.add(userMessage);
      _waiting = true;
      _waitingLabel = 'Consultando lojas e promoções…';
    });
    _scrollToEnd();

    ChatMessage answer;
    try {
      final result = await api.sendChat(
        message,
        history: recent,
        imageLabels: imageLabels,
      );
      answer = ChatMessage(
        text: result.reply,
        fromUser: false,
        stores: result.stores,
        products: result.products,
        suggestions: result.suggestions,
        route: result.route,
      );
    } on ApiException catch (error) {
      answer = ChatMessage(text: error.message, fromUser: false, isError: true);
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _messages.add(answer);
      _waiting = false;
    });
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final started = _messages.isNotEmpty || _waiting;
    final latestHasSuggestions =
        !_waiting && _messages.isNotEmpty && _messages.last.suggestions.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: colors.primary,
              child: CompassMark(size: 24, color: colors.onPrimary, accent: AppColors.mango),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Guia do shopping', style: theme.textTheme.titleMedium),
                Text(
                  'Lojas, ofertas e caminhos',
                  style: theme.textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (started)
            IconButton(
              tooltip: 'Nova conversa',
              onPressed: _waiting ? null : () => setState(_messages.clear),
              icon: const Icon(Icons.add_comment_outlined),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: started ? _buildConversation() : _buildStart(context)),
          if (started && !latestHasSuggestions) _buildShortcutBar(),
          _buildComposer(context),
        ],
      ),
    );
  }

  /// Tela inicial: em vez de uma conversa vazia, mostra o que o guia faz.
  Widget _buildStart(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'O que vamos resolver hoje?',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: colors.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Eu encontro, comparo e levo você até a loja.',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: colors.onPrimaryContainer),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              CompassMark(size: 68, color: colors.primary, accent: colors.tertiary),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _ActionTile(
          icon: Icons.route,
          title: 'Montar um roteiro',
          subtitle: 'Diga o que quer, o tempo e o orçamento. Eu organizo as paradas e guio você.',
          highlighted: true,
          onTap: _suggestRoute,
        ),
        const SizedBox(height: 10),
        _ActionTile(
          icon: Icons.photo_camera_outlined,
          title: 'Buscar por foto',
          subtitle: 'Fotografe um produto e eu digo onde encontrar algo parecido.',
          onTap: _choosePhoto,
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final shortcut in _shortcuts) ...[
                Expanded(
                  child: _MiniTile(
                    icon: shortcut.icon,
                    label: shortcut.label,
                    onTap: () => _send(shortcut.question, shownAs: shortcut.label),
                  ),
                ),
                if (shortcut != _shortcuts.last) const SizedBox(width: 10),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('Experimente perguntar', style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        for (final example in _examples)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Icon(Icons.north_east, size: 18, color: colors.primary),
            title: Text(example, style: theme.textTheme.bodyMedium),
            onTap: () => _send(example),
          ),
      ],
    );
  }

  Widget _buildConversation() {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      itemCount: _messages.length + (_waiting ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length) {
          return _Working(label: _waitingLabel);
        }

        final message = _messages[index];

        if (message.fromUser) {
          return FadeSlideIn(
            key: ValueKey('user-$index'),
            child: _UserMessage(message: message),
          );
        }

        final isLatest = index == _messages.length - 1 && !_waiting;

        return FadeSlideIn(
          key: ValueKey('guide-$index'),
          child: _GuideAnswer(
            message: message,
            onSuggestion: isLatest ? _send : null,
          ),
        );
      },
    );
  }

  Widget _buildShortcutBar() {
    return SizedBox(
      height: 40 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _ShortcutChip(
            icon: Icons.route,
            label: 'Montar um roteiro',
            onPressed: _waiting ? null : _suggestRoute,
          ),
          for (final shortcut in _shortcuts) ...[
            const SizedBox(width: 8),
            _ShortcutChip(
              icon: shortcut.icon,
              label: shortcut.label,
              onPressed: _waiting
                  ? null
                  : () => _send(shortcut.question, shownAs: shortcut.label),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildComposer(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          border: Border.all(color: colors.outlineVariant),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton.filledTonal(
              tooltip: 'Buscar por foto',
              onPressed: _waiting ? null : _choosePhoto,
              icon: const Icon(Icons.photo_camera_outlined),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _input,
                focusNode: _inputFocus,
                minLines: 1,
                maxLines: 4,
                maxLength: 1000,
                textInputAction: TextInputAction.send,
                onSubmitted: _send,
                decoration: const InputDecoration(
                  hintText: 'Pergunte ao guia',
                  hintMaxLines: 1,
                  counterText: '',
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton.filled(
              tooltip: 'Enviar',
              onPressed: _waiting ? null : () => _send(_input.text),
              icon: const Icon(Icons.arrow_upward),
            ),
          ],
        ),
      ),
    );
  }
}

/// Atalho da barra acima do campo de pedido.
class _ShortcutChip extends StatelessWidget {
  const _ShortcutChip({required this.icon, required this.label, required this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ActionChip(
      avatar: Icon(icon, size: 18, color: colors.onSecondaryContainer),
      label: Text(label),
      labelStyle: TextStyle(color: colors.onSecondaryContainer),
      backgroundColor: colors.secondaryContainer,
      side: BorderSide.none,
      shape: const StadiumBorder(),
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
    );
  }
}

/// Cartão grande de ação da tela inicial do guia.
class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final background = highlighted ? colors.primary : colors.secondaryContainer;
    final foreground = highlighted ? colors.onPrimary : colors.onSecondaryContainer;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 32, color: foreground),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium?.copyWith(color: foreground)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: foreground)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward, color: foreground),
            ],
          ),
        ),
      ),
    );
  }
}

/// Atalho pequeno da tela inicial do guia.
class _MiniTile extends StatelessWidget {
  const _MiniTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      color: colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
          child: Column(
            children: [
              Icon(icon, color: colors.primary),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pedido do visitante: um rótulo compacto à direita, ou a foto enviada.
class _UserMessage extends StatelessWidget {
  const _UserMessage({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
        margin: const EdgeInsets.only(top: 10, bottom: 6),
        padding: message.imagePath == null
            ? const EdgeInsets.symmetric(horizontal: 14, vertical: 10)
            : const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: colors.primary,
          borderRadius: BorderRadius.circular(18),
        ),
        child: message.imagePath == null
            ? Text(
                message.text,
                style: TextStyle(color: colors.onPrimary, fontSize: 15, height: 1.35),
              )
            : _PhotoPreview(path: message.imagePath!),
      ),
    );
  }
}

/// Resposta do guia: texto corrido com um marcador, seguido dos cartões de
/// loja ou de roteiro. Não usa balão, para destacar os cartões de ação.
class _GuideAnswer extends StatelessWidget {
  const _GuideAnswer({required this.message, this.onSuggestion});

  final ChatMessage message;

  /// Quando informado, as próximas perguntas sugeridas aparecem como botões.
  final ValueChanged<String>? onSuggestion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: message.isError ? colors.errorContainer : colors.primary,
                child: Icon(
                  message.isError ? Icons.error_outline : Icons.explore,
                  size: 15,
                  color: message.isError ? colors.onErrorContainer : colors.onPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Guia',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: message.isError ? colors.error : colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            message.text,
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.45,
              color: message.isError ? colors.error : colors.onSurface,
            ),
          ),
          if (message.products.isNotEmpty) _ProductStrip(products: message.products),
          if (message.stores.length == 1)
            _StoreCard(store: message.stores.single)
          else if (message.stores.length > 1)
            _StoreList(stores: message.stores),
          if (message.route != null) RouteCard(plan: message.route!),
          if (onSuggestion != null && message.suggestions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final suggestion in message.suggestions)
                    ActionChip(
                      label: Text(suggestion),
                      avatar: Icon(Icons.subdirectory_arrow_right, size: 16, color: colors.primary),
                      shape: const StadiumBorder(),
                      side: BorderSide(color: colors.outlineVariant),
                      onPressed: () => onSuggestion!(suggestion),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Produtos citados na resposta, em uma faixa horizontal com foto e preço.
class _ProductStrip extends StatelessWidget {
  const _ProductStrip({required this.products});

  final List<ChatProduct> products;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SizedBox(
        height: 132 + 76 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.8),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: products.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            final item = products[index];

            return SizedBox(
              width: 132,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => openStore(context, item.store),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CatalogImage(
                      url: item.product.imageUrl,
                      category: item.store.category,
                      size: 132,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.2),
                    ),
                    Text(
                      formatPrice(item.product.price),
                      style: theme.textTheme.titleSmall?.copyWith(color: colors.primary),
                    ),
                    Text(
                      item.store.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Indicador de que o guia está trabalhando, com o que ele está fazendo.
class _Working extends StatelessWidget {
  const _Working({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      liveRegion: true,
      label: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(18),
              ),
              child: TypingDots(color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: ExcludeSemantics(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.file(
        File(path),
        width: 180,
        height: 180,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => SizedBox(
          width: 180,
          height: 56,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image_outlined, color: colors.onPrimary),
              const SizedBox(width: 8),
              Text('Foto de um produto', style: TextStyle(color: colors.onPrimary)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Várias lojas citadas na mesma resposta: uma linha por loja, cada uma com
/// o atalho da bússola.
class _StoreList extends StatelessWidget {
  const _StoreList({required this.stores});

  final List<Store> stores;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          for (final store in stores) ...[
            if (store != stores.first) Divider(height: 1, color: colors.outlineVariant),
            InkWell(
              onTap: () => openStore(context, store),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                child: Row(
                  children: [
                    CatalogImage(url: store.imageUrl, category: store.category, size: 44),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(store.name, style: theme.textTheme.titleSmall),
                          Text(
                            '${store.category} · ${store.floorLabel}',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: colors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    IconButton.filled(
                      tooltip: 'Me leve até a ${store.name}',
                      onPressed: () => openCompass(context, store),
                      icon: const Icon(Icons.explore),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StoreCard extends StatelessWidget {
  const _StoreCard({required this.store});

  final Store store;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant);

    return Container(
      margin: const EdgeInsets.only(top: 10),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => openStore(context, store),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 8, 10),
              child: Row(
                children: [
                  CatalogImage(url: store.imageUrl, category: store.category, size: 52),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(store.name, style: theme.textTheme.titleMedium),
                        Text('${store.category} · ${store.floorLabel}', style: muted),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
                ],
              ),
            ),
          ),
          if (store.promotions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Row(
                children: [
                  Icon(Icons.local_offer, size: 16, color: colors.tertiary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      store.promotions.first.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(color: colors.tertiary),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => openCompass(context, store),
                    icon: const Icon(Icons.explore),
                    label: const Text('Me leve até a loja'),
                  ),
                ),
                if (store.whatsapp != null) ...[
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    tooltip: 'Falar com atendente',
                    onPressed: () => openWhatsApp(context, store),
                    icon: const Icon(Icons.support_agent),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
