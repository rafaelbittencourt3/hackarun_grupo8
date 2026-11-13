import 'package:flutter/material.dart';

import '../models.dart';
import '../screens/compass_screen.dart';
import 'common.dart';

/// Roteiro de compras mostrado dentro do chat: totais, paradas em ordem e o
/// botão que inicia a navegação parada por parada.
class RouteCard extends StatelessWidget {
  const RouteCard({super.key, required this.plan});

  final RoutePlan plan;

  Future<void> _start(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final finished = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CompassScreen.forRoute(route: plan.stops, stopIndex: 0),
      ),
    );

    if (finished == true) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Roteiro concluído. Boas compras!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.route, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text('Seu roteiro', style: theme.textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _Total(
                icon: Icons.payments_outlined,
                label: 'Total',
                value: formatPrice(plan.totalPrice),
              ),
              const SizedBox(width: 8),
              _Total(
                icon: Icons.schedule,
                label: 'Tempo',
                value: '${plan.totalMinutes} min',
              ),
              const SizedBox(width: 8),
              _Total(
                icon: Icons.place_outlined,
                label: 'Paradas',
                value: '${plan.stops.length}',
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (var index = 0; index < plan.stops.length; index++)
            _Stop(
              number: index + 1,
              stop: plan.stops[index],
              isLast: index == plan.stops.length - 1,
            ),
          const SizedBox(height: 4),
          FilledButton.icon(
            onPressed: () => _start(context),
            icon: const Icon(Icons.explore),
            label: const Text('Começar roteiro'),
          ),
        ],
      ),
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: theme.textTheme.titleSmall),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stop extends StatelessWidget {
  const _Stop({required this.number, required this.stop, required this.isLast});

  final int number;
  final RouteStop stop;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: colors.primary,
                child: Text(
                  '$number',
                  style: TextStyle(color: colors.onPrimary, fontSize: 12),
                ),
              ),
              if (!isLast)
                Expanded(child: Container(width: 2, color: colors.outlineVariant)),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: () => openStore(context, stop.store),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(stop.store.name, style: theme.textTheme.titleSmall),
                        ),
                        if (stop.price != null)
                          Text(formatPrice(stop.price!), style: theme.textTheme.titleSmall),
                      ],
                    ),
                    Text('${stop.store.floorLabel} · ${stop.minutes} min', style: muted),
                    const SizedBox(height: 4),
                    Text(stop.item, style: theme.textTheme.bodyMedium),
                    if (stop.reason.isNotEmpty) Text(stop.reason, style: muted),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
