import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../models.dart';
import '../widgets/common.dart';
import 'compass_screen.dart';

void openCompass(BuildContext context, Store store) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => CompassScreen(store: store)),
  );
}

Future<void> openWhatsApp(BuildContext context, Store store) async {
  final messenger = ScaffoldMessenger.of(context);
  final uri = Uri.https('wa.me', '/${store.whatsapp}', {
    'text': 'Olá! Vim pelo app do shopping e gostaria de falar com a ${store.name}.',
  });

  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Não foi possível abrir o WhatsApp.')),
    );
  }
}

class StoreActions extends StatelessWidget {
  const StoreActions({super.key, required this.store});

  final Store store;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: () => openCompass(context, store),
          icon: const Icon(Icons.explore),
          label: const Text('Me leve até a loja'),
        ),
        if (store.whatsapp != null)
          OutlinedButton.icon(
            onPressed: () => openWhatsApp(context, store),
            icon: const Icon(Icons.support_agent),
            label: const Text('Falar com atendente'),
          ),
      ],
    );
  }
}

class StoreDetailScreen extends StatefulWidget {
  const StoreDetailScreen({super.key, required this.store});

  /// Loja vinda de uma lista; produtos e promoções são carregados aqui.
  final Store store;

  @override
  State<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends State<StoreDetailScreen> {
  late Future<Store> _store = api.fetchStore(widget.store.id);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = widget.store;

    return Scaffold(
      appBar: AppBar(title: Text(summary.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (summary.imageUrl != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    summary.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => ColoredBox(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Icon(categoryIcon(summary.category), size: 48),
                    ),
                  ),
                ),
              ),
            ),
          Row(
            children: [
              CategoryAvatar(category: summary.category, size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(summary.name, style: theme.textTheme.titleLarge),
                    Text(
                      '${summary.category} · ${summary.floorLabel}',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(summary.description),
          if (summary.openingHours != null) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.schedule, size: 18, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    summary.openingHours!,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          StoreActions(store: summary),
          const SizedBox(height: 8),
          FutureBuilder<Store>(
            future: _store,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text('${snapshot.error}', textAlign: TextAlign.center),
                      TextButton(
                        onPressed: () => setState(
                          () => _store = api.fetchStore(summary.id),
                        ),
                        child: const Text('Tentar de novo'),
                      ),
                    ],
                  ),
                );
              }

              return _StoreCatalog(store: snapshot.data!);
            },
          ),
        ],
      ),
    );
  }
}

class _StoreCatalog extends StatelessWidget {
  const _StoreCatalog({required this.store});

  final Store store;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (store.promotions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Promoções', style: theme.textTheme.titleMedium),
          for (final promotion in store.promotions)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.local_offer_outlined),
              title: Text(promotion.title),
              subtitle: Text(promotion.description),
            ),
        ],
        const SizedBox(height: 8),
        Text('Produtos', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 12.0;
            final width = (constraints.maxWidth - gap) / 2;

            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final product in store.products)
                  SizedBox(
                    width: width,
                    child: _ProductCard(
                      product: product,
                      category: store.category,
                      imageSize: width,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.category,
    required this.imageSize,
  });

  final Product product;
  final String category;
  final double imageSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CatalogImage(url: product.imageUrl, category: category, size: imageSize),
        const SizedBox(height: 6),
        Text(
          product.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium,
        ),
        Text(formatPrice(product.price), style: theme.textTheme.titleSmall),
      ],
    );
  }
}
