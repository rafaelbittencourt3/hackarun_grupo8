import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../theme.dart';
import '../voice.dart';
import '../widgets/brand.dart';

/// Conclusão do roteiro: comemora, resume o que foi feito e devolve o
/// visitante ao guia.
class RouteDoneScreen extends StatefulWidget {
  const RouteDoneScreen({super.key, required this.stops});

  final List<RouteStop> stops;

  @override
  State<RouteDoneScreen> createState() => _RouteDoneScreenState();
}

class _RouteDoneScreenState extends State<RouteDoneScreen> {
  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
    Voice.say('Roteiro concluído. Boas compras!');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final stops = widget.stops;
    final total = stops.fold<double>(0, (sum, stop) => sum + (stop.price ?? 0));
    final minutes = stops.fold<int>(0, (sum, stop) => sum + stop.minutes);

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      children: [
                        const SizedBox(height: 16),
                        Center(
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: reduceMotion(context) ? 1 : 0, end: 1),
                            duration: const Duration(milliseconds: 700),
                            curve: Curves.elasticOut,
                            builder: (context, value, child) =>
                                Transform.scale(scale: value, child: child),
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: const BoxDecoration(
                                color: AppColors.success,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check_rounded, size: 76, color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Roteiro concluído!',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Você passou por todas as paradas. Boas compras!',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            _Stat(
                              icon: Icons.place_rounded,
                              value: '${stops.length}',
                              label: stops.length == 1 ? 'parada' : 'paradas',
                            ),
                            const SizedBox(width: 10),
                            _Stat(
                              icon: Icons.payments_rounded,
                              value: formatPrice(total),
                              label: 'em compras',
                            ),
                            const SizedBox(width: 10),
                            _Stat(
                              icon: Icons.schedule_rounded,
                              value: '$minutes min',
                              label: 'nas lojas',
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        for (var index = 0; index < stops.length; index++)
                          FadeSlideIn(
                            delay: Duration(milliseconds: 250 + index * 120),
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const CircleAvatar(
                                backgroundColor: AppColors.success,
                                child: Icon(Icons.check_rounded, color: Colors.white),
                              ),
                              title: Text(stops[index].store.name),
                              subtitle: Text(stops[index].item),
                              trailing: stops[index].price == null
                                  ? null
                                  : Text(
                                      formatPrice(stops[index].price!),
                                      style: theme.textTheme.titleSmall,
                                    ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.explore_rounded),
                      label: const Text('Voltar ao guia'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: ConfettiBurst(
              colors: [
                AppColors.mango,
                colors.tertiary,
                AppColors.success,
                colors.primary,
                const Color(0xFF7048E8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Expanded(
      child: Semantics(
        label: '$value $label',
        child: ExcludeSemantics(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            decoration: BoxDecoration(
              color: colors.secondaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(icon, color: colors.onSecondaryContainer),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: colors.onSecondaryContainer),
                  ),
                ),
                Text(
                  label,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: colors.onSecondaryContainer),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
