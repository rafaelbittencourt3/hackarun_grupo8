import 'package:flutter/material.dart';

import '../models.dart';
import '../screens/store_detail_screen.dart';
import '../theme.dart';

IconData categoryIcon(String category) {
  return switch (category) {
    'Calçados' => Icons.roller_skating_rounded,
    'Moda' => Icons.checkroom_rounded,
    'Eletrônicos' => Icons.headphones_rounded,
    'Alimentação' => Icons.ramen_dining_rounded,
    'Livros e Papelaria' => Icons.auto_stories_rounded,
    'Brinquedos' => Icons.smart_toy_rounded,
    'Beleza' => Icons.face_retouching_natural_rounded,
    'Farmácia' => Icons.medication_rounded,
    'Ótica' => Icons.remove_red_eye_rounded,
    'Casa e Decoração' => Icons.chair_rounded,
    'Esportes' => Icons.sports_soccer_rounded,
    'Lazer' => Icons.theaters_rounded,
    'Infantil' => Icons.toys_rounded,
    _ => Icons.storefront_rounded,
  };
}

void openStore(BuildContext context, Store store) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => StoreDetailScreen(store: store)),
  );
}

class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar({super.key, required this.category, this.size = 44});

  final String category;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final hue = categoryColor(category);
    final foreground = dark ? Color.lerp(hue, Colors.white, 0.55)! : hue;

    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: hue.withOpacity(dark ? 0.28 : 0.13),
          borderRadius: BorderRadius.circular(size * 0.28),
          border: Border.all(color: hue.withOpacity(dark ? 0.5 : 0.22)),
        ),
        child: Icon(categoryIcon(category), color: foreground, size: size * 0.52),
      ),
    );
  }
}

/// Foto de uma loja ou produto. Enquanto carrega, se falhar ou se não houver
/// foto, mostra o ícone da categoria no lugar.
class CatalogImage extends StatelessWidget {
  const CatalogImage({
    super.key,
    required this.url,
    required this.category,
    this.size = 44,
  });

  final String? url;
  final String category;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = CategoryAvatar(category: category, size: size);
    final url = this.url;

    if (url == null) {
      return fallback;
    }

    // A foto é decorativa: o nome da loja ou do produto vem sempre ao lado,
    // então o leitor de tela não precisa anunciá-la.
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.2 > 16 ? 16 : size * 0.2),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        excludeFromSemantics: true,
        errorBuilder: (context, error, stackTrace) => fallback,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) {
            return child;
          }

          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: frame == null ? fallback : child,
          );
        },
      ),
    );
  }
}

class PromoBadge extends StatelessWidget {
  const PromoBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.tertiaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(color: colors.onTertiaryContainer),
      ),
    );
  }
}

class StoreTile extends StatelessWidget {
  const StoreTile({super.key, required this.store});

  final Store store;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: CatalogImage(url: store.imageUrl, category: store.category, size: 56),
        title: Text(store.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${store.category} · ${store.floorLabel}'),
            if (store.promotions.isNotEmpty) ...[
              const SizedBox(height: 4),
              PromoBadge(label: store.promotions.first.title),
            ],
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => openStore(context, store),
      ),
    );
  }
}

/// Mostra carregamento, erro com botão de tentar de novo, ou o conteúdo.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.future,
    required this.onRetry,
    required this.builder,
  });

  final Future<T> future;
  final VoidCallback onRetry;
  final Widget Function(BuildContext context, T data) builder;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off, size: 40),
                  const SizedBox(height: 12),
                  Text('${snapshot.error}', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: onRetry,
                    child: const Text('Tentar de novo'),
                  ),
                ],
              ),
            ),
          );
        }

        return builder(context, snapshot.data as T);
      },
    );
  }
}
