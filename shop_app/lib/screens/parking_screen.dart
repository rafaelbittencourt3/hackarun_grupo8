import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../config.dart';
import '../models.dart';
import '../parking.dart';
import '../theme.dart';
import '../widgets/brand.dart';
import 'compass_screen.dart';

/// "Onde estacionei": o visitante marca a vaga ao chegar e, na saída, a
/// bússola o leva de volta ao carro.
class ParkingScreen extends StatefulWidget {
  const ParkingScreen({super.key});

  @override
  State<ParkingScreen> createState() => _ParkingScreenState();
}

class _ParkingScreenState extends State<ParkingScreen> {
  final _note = TextEditingController();
  ParkingSpot? _spot;
  bool _loading = true;
  bool _saving = false;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _clock?.cancel();
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final spot = await ParkingStorage.load();
    if (!mounted) {
      return;
    }

    setState(() {
      _spot = spot;
      _loading = false;
    });
    _watchClock();
  }

  /// Atualiza o "há quanto tempo" a cada meio minuto enquanto houver vaga.
  void _watchClock() {
    _clock?.cancel();
    if (_spot != null) {
      _clock = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  Future<Position?> _currentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _mark({required bool useGps}) async {
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    final messenger = ScaffoldMessenger.of(context);
    final position = useGps ? await _currentPosition() : null;
    final spot = ParkingSpot(
      latitude: position?.latitude ?? mallParkingLatitude,
      longitude: position?.longitude ?? mallParkingLongitude,
      savedAt: DateTime.now(),
      fromGps: position != null,
      note: _note.text.trim(),
    );
    await ParkingStorage.save(spot);
    if (!mounted) {
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _spot = spot;
      _saving = false;
    });
    _watchClock();

    if (useGps && position == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Sem sinal de GPS: marquei a vaga no estacionamento de demonstração.'),
        ),
      );
    }
  }

  Future<void> _release() async {
    await ParkingStorage.clear();
    if (!mounted) {
      return;
    }

    setState(() {
      _spot = null;
      _note.clear();
    });
    _watchClock();
  }

  void _goToCar(ParkingSpot spot) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CompassScreen.toCar(
          startWithGps: spot.fromGps,
          car: Store(
            id: 0,
            name: 'Seu carro',
            category: 'Estacionamento',
            description: spot.note.isEmpty ? 'Vaga marcada ${parkedFor(_elapsed(spot))}' : spot.note,
            floor: 0,
            latitude: spot.latitude,
            longitude: spot.longitude,
          ),
        ),
      ),
    );
  }

  Duration _elapsed(ParkingSpot spot) => DateTime.now().difference(spot.savedAt);

  @override
  Widget build(BuildContext context) {
    final spot = _spot;

    return Scaffold(
      appBar: AppBar(title: const Text('Onde estacionei')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: spot == null ? _buildEmpty(context) : _buildSaved(context, spot),
            ),
    );
  }

  List<Widget> _buildEmpty(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return [
      const SizedBox(height: 12),
      const Center(child: _ParkingBadge(size: 112)),
      const SizedBox(height: 20),
      Text(
        'Estacionou? Marque a vaga.',
        textAlign: TextAlign.center,
        style: theme.textTheme.headlineSmall,
      ),
      const SizedBox(height: 6),
      Text(
        'Na hora de ir embora, a bússola leva você de volta ao carro.',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
      ),
      const SizedBox(height: 24),
      TextField(
        controller: _note,
        enabled: !_saving,
        maxLength: 40,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(
          labelText: 'Andar e vaga (opcional)',
          hintText: 'G2, vaga B14',
          prefixIcon: Icon(Icons.edit_location_alt_outlined),
          counterText: '',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
      ),
      const SizedBox(height: 14),
      FilledButton.icon(
        onPressed: _saving ? null : () => _mark(useGps: true),
        icon: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.my_location_rounded),
        label: Text(_saving ? 'Marcando a vaga…' : 'Marcar minha vaga aqui'),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: _saving ? null : () => _mark(useGps: false),
        icon: const Icon(Icons.science_outlined),
        label: const Text('Usar vaga de demonstração'),
      ),
      const SizedBox(height: 18),
      Text(
        'A vaga fica guardada só neste aparelho.',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
      ),
    ];
  }

  List<Widget> _buildSaved(BuildContext context, ParkingSpot spot) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final elapsed = _elapsed(spot);
    final overFlatRate = elapsed.inHours >= parkingFlatRateHours;
    final hour = spot.savedAt.hour.toString().padLeft(2, '0');
    final minute = spot.savedAt.minute.toString().padLeft(2, '0');

    return [
      FadeSlideIn(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              const _ParkingBadge(size: 72),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spot.note.isEmpty ? 'Vaga marcada' : spot.note,
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(color: colors.onPrimaryContainer),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Estacionado ${parkedFor(elapsed)}, desde $hour:$minute',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: colors.onPrimaryContainer),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: overFlatRate ? colors.tertiaryContainer : colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              overFlatRate ? Icons.warning_amber_rounded : Icons.payments_outlined,
              color: overFlatRate ? colors.onTertiaryContainer : colors.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                overFlatRate
                    ? 'Você passou das $parkingFlatRateHours horas da tarifa única de R\$ 12. Confira o valor no caixa.'
                    : 'R\$ 12 pelas primeiras $parkingFlatRateHours horas. Grátis com compras acima de R\$ 150.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: overFlatRate ? colors.onTertiaryContainer : colors.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
      if (!spot.fromGps)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(
            'Vaga de demonstração, no estacionamento do shopping.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
        ),
      const SizedBox(height: 20),
      FilledButton.icon(
        onPressed: () => _goToCar(spot),
        icon: const Icon(Icons.explore_rounded),
        label: const Text('Me leve até o carro'),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: _release,
        icon: const Icon(Icons.logout_rounded),
        label: const Text('Liberar vaga'),
      ),
    ];
  }
}

/// Selo de estacionamento: um "P" dentro de um quadrado arredondado.
class _ParkingBadge extends StatelessWidget {
  const _ParkingBadge({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.navy,
          borderRadius: BorderRadius.circular(size * 0.28),
          border: Border.all(color: AppColors.mango, width: size * 0.05),
        ),
        child: Icon(Icons.local_parking_rounded, color: Colors.white, size: size * 0.62),
      ),
    );
  }
}
