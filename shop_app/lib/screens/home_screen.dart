import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/brand.dart';
import '../widgets/common.dart';
import 'chat_screen.dart';
import 'stores_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onOpenChat});

  final VoidCallback onOpenChat;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeData {
  const _HomeData(this.stores, this.categories, this.promotions);

  final List<Store> stores;
  final List<String> categories;
  final List<Promotion> promotions;
}

/// Saudação de acordo com a hora do dia.
String greetingFor(DateTime now) {
  if (now.hour < 12) {
    return 'Bom dia';
  }

  return now.hour < 18 ? 'Boa tarde' : 'Boa noite';
}

/// Situação do shopping agora: segunda a sábado das 10h às 22h, domingo das
/// 14h às 20h.
({bool open, String label}) mallStatusFor(DateTime now) {
  final sunday = now.weekday == DateTime.sunday;
  final opens = sunday ? 14 : 10;
  final closes = sunday ? 20 : 22;

  if (now.hour >= opens && now.hour < closes) {
    return (open: true, label: 'Aberto agora · fecha às ${closes}h');
  }

  if (now.hour < opens) {
    return (open: false, label: 'Fechado · abre hoje às ${opens}h');
  }

  final tomorrowIsSunday = now.weekday == DateTime.saturday;

  return (
    open: false,
    label: 'Fechado · abre amanhã às ${tomorrowIsSunday ? 14 : 10}h'
  );
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<_HomeData> _data = _load();

  Future<_HomeData> _load() async {
    final results =
        await Future.wait([api.fetchStores(), api.fetchPromotions()]);
    final stores = results[0] as List<Store>;
    final categories = stores.map((store) => store.category).toSet().toList()
      ..sort();

    return _HomeData(stores, categories, results[1] as List<Promotion>);
  }

  void _openStores({String? query, String? category}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StoresScreen(
          initialQuery: query,
          initialCategory: category,
          showBackButton: true,
        ),
      ),
    );
  }

  void _openGuide([ChatAction? action]) {
    widget.onOpenChat();
    if (action != null) {
      chatAction.value = action;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: () {
            setState(() => _data = _load());
            return _data;
          },
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _Header(
                onSearch: (query) => _openStores(query: query),
              ),
              Transform.translate(
                offset: const Offset(0, -28),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Material(
                        color: colors.surfaceContainerLowest,
                        elevation: 2,
                        shadowColor: Colors.black26,
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 6),
                          child: Row(
                            children: [
                              _QuickAction(
                                icon: Icons.route,
                                label: 'Montar\nroteiro',
                                onTap: () => _openGuide(ChatAction.route),
                              ),
                              _QuickAction(
                                icon: Icons.photo_camera_outlined,
                                label: 'Buscar\npor foto',
                                onTap: () => _openGuide(ChatAction.photo),
                              ),
                              _QuickAction(
                                icon: Icons.explore_outlined,
                                label: 'Falar com\no guia',
                                onTap: _openGuide,
                              ),
                              _QuickAction(
                                icon: Icons.storefront_outlined,
                                label: 'Todas\nas lojas',
                                onTap: _openStores,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    FutureBuilder<_HomeData>(
                      future: _data,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Padding(
                            padding: EdgeInsets.all(48),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        if (snapshot.hasError) {
                          return Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              children: [
                                const Icon(Icons.cloud_off, size: 40),
                                const SizedBox(height: 12),
                                Text('${snapshot.error}',
                                    textAlign: TextAlign.center),
                                const SizedBox(height: 12),
                                OutlinedButton(
                                  onPressed: () =>
                                      setState(() => _data = _load()),
                                  child: const Text('Tentar de novo'),
                                ),
                              ],
                            ),
                          );
                        }

                        return _buildSections(context, snapshot.data!);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSections(BuildContext context, _HomeData data) {
    // As faixas horizontais crescem junto com o tamanho de fonte do sistema,
    // para o texto não ser cortado quando o visitante usa letras grandes.
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.8);
    final food =
        data.stores.where((store) => store.category == 'Alimentação').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (data.promotions.isNotEmpty) ...[
          const _SectionTitle('Ofertas de hoje'),
          SizedBox(
            height: 190 * scale,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: data.promotions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) =>
                  _OfferCard(promotion: data.promotions[index]),
            ),
          ),
        ],
        const _SectionTitle('Explore por categoria'),
        SizedBox(
          height: 40 * scale,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: data.categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final category = data.categories[index];

              return ActionChip(
                avatar: Icon(categoryIcon(category), size: 18),
                label: Text(category),
                shape: const StadiumBorder(),
                onPressed: () => _openStores(category: category),
              );
            },
          ),
        ),
        _SectionTitle(
          'Lojas do shopping',
          actionLabel: 'Ver todas',
          onAction: _openStores,
        ),
        SizedBox(
          height: 140 + 48 * scale,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: data.stores.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) =>
                _StoreCard(store: data.stores[index]),
          ),
        ),
        if (food.isNotEmpty) ...[
          const _SectionTitle('Bateu a fome?'),
          for (final store in food) StoreTile(store: store),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

/// Topo colorido com saudação, situação do shopping e busca.
class _Header extends StatelessWidget {
  const _Header({required this.onSearch});

  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final now = DateTime.now();
    final status = mallStatusFor(now);

    return Container(
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? const Color(0xFF22327A)
            : AppColors.navy,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.paddingOf(context).top + 20, 20, 52),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CompassMark(
                  size: 26, color: Colors.white, accent: AppColors.mango),
              const SizedBox(width: 8),
              Text(
                'Guia do Shopping',
                style:
                    theme.textTheme.titleMedium?.copyWith(color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            '${greetingFor(now)}!',
            style: theme.textTheme.titleMedium
                ?.copyWith(color: Colors.white.withOpacity(0.85)),
          ),
          Text(
            'Aonde vamos hoje?',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.circle,
                  size: 8,
                  color: status.open
                      ? AppColors.successBright
                      : AppColors.warningBright,
                ),
                const SizedBox(width: 6),
                Text(
                  'Shopping ${status.label.replaceFirst('A', 'a').replaceFirst('F', 'f')}',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            textInputAction: TextInputAction.search,
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                onSearch(value);
              }
            },
            decoration: InputDecoration(
              hintText: 'Buscar loja ou produto',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: colors.surfaceContainerLowest,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction(
      {required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: colors.secondaryContainer,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: colors.onSecondaryContainer),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium?.copyWith(height: 1.2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!))
          else
            const SizedBox(height: 40),
        ],
      ),
    );
  }
}

/// Oferta em destaque: foto da loja ao fundo, com o título e o preço por cima.
class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.promotion});

  final Promotion promotion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final store = promotion.store;
    final endsAt = promotion.endsAt;
    final deadline =
        '${endsAt.day.toString().padLeft(2, '0')}/${endsAt.month.toString().padLeft(2, '0')}';

    return SizedBox(
      width: 270,
      child: Material(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: store == null ? null : () => openStore(context, store),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (store?.imageUrl != null)
                Image.network(
                  store!.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x33000000), Color(0xD9000000)],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: colors.tertiaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            promotion.price != null
                                ? formatPrice(promotion.price!)
                                : 'Oferta',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: colors.onTertiaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'até $deadline',
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      promotion.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                    if (store != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${store.name} · ${store.floorLabel}',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.white70),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Loja na vitrine horizontal: foto em cima, nome e andar embaixo.
class _StoreCard extends StatelessWidget {
  const _StoreCard({required this.store});

  final Store store;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 140,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => openStore(context, store),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CatalogImage(
                url: store.imageUrl, category: store.category, size: 140),
            const SizedBox(height: 6),
            Text(
              store.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall,
            ),
            Text(
              '${store.category} · ${store.floorLabel}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
