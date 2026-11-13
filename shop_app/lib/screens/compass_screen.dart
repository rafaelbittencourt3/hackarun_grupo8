import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';

import '../config.dart';
import '../models.dart';
import '../theme.dart';
import '../voice.dart';
import '../widgets/brand.dart';
import '../widgets/common.dart';
import 'route_done_screen.dart';

/// Distância, em metros, a partir da qual o visitante está em frente à loja.
const double arrivalDistance = 8;

/// Distância, em metros, a partir da qual o app avisa que falta pouco.
const double nearDistance = 20;

/// Diferença entre a direção da loja e a direção para onde o celular aponta,
/// em graus, normalizada para o intervalo de -180 a 180.
double relativeAngle(double bearing, double heading) {
  final angle = (bearing - heading) % 360;

  return angle > 180 ? angle - 360 : angle;
}

String directionHint(double angle, double distance) {
  if (distance < arrivalDistance) {
    return 'Você chegou';
  }
  if (angle.abs() < 20) {
    return 'Siga em frente';
  }
  if (angle.abs() > 150) {
    return 'A loja está atrás de você';
  }

  return angle > 0 ? 'Vire à direita' : 'Vire à esquerda';
}

class CompassScreen extends StatefulWidget {
  /// Bússola para uma única loja.
  const CompassScreen({super.key, required Store store})
      : singleStore = store,
        route = const [],
        stopIndex = 0;

  /// Bússola guiando uma parada de um roteiro.
  const CompassScreen.forRoute({
    super.key,
    required this.route,
    required this.stopIndex,
  }) : singleStore = null;

  final Store? singleStore;
  final List<RouteStop> route;
  final int stopIndex;

  bool get isRoute => route.isNotEmpty;

  Store get store => singleStore ?? route[stopIndex].store;

  bool get isLastStop => stopIndex == route.length - 1;

  /// No modo demonstração, o visitante parte da entrada do shopping ou,
  /// em um roteiro, da parada anterior.
  ({double latitude, double longitude}) get demoStart {
    if (isRoute && stopIndex > 0) {
      final previous = route[stopIndex - 1].store;

      return (latitude: previous.latitude, longitude: previous.longitude);
    }

    return (latitude: mallEntranceLatitude, longitude: mallEntranceLongitude);
  }

  @override
  State<CompassScreen> createState() => _CompassScreenState();
}

class _CompassScreenState extends State<CompassScreen> with SingleTickerProviderStateMixin {
  StreamSubscription<CompassEvent>? _compass;
  StreamSubscription<Position>? _gps;

  /// Caminhada simulada do modo demonstração, do ponto de partida até a loja.
  late final AnimationController _walk;

  bool _demoMode = true;
  bool _hasCompass = true;
  bool _voiceOn = true;
  double _heading = 0;
  late double _latitude = widget.demoStart.latitude;
  late double _longitude = widget.demoStart.longitude;
  String? _gpsMessage;

  /// Rotação acumulada da seta, em voltas, para ela girar pelo caminho curto.
  double _arrowTurns = 0;
  double? _lastAngle;

  double? _startDistance;
  String? _lastSpokenHint;
  DateTime _lastSpokenAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _nearAnnounced = false;
  bool _arrivalAnnounced = false;

  Store get _store => widget.store;

  @override
  void initState() {
    super.initState();
    _walk = AnimationController(vsync: this, duration: const Duration(seconds: 7))
      ..addListener(_onWalkTick);
    _listenToCompass();
    WidgetsBinding.instance.addPostFrameCallback((_) => _react());
  }

  @override
  void dispose() {
    _compass?.cancel();
    _gps?.cancel();
    _walk.dispose();
    Voice.stop();
    super.dispose();
  }

  double get _distance => Geolocator.distanceBetween(
        _latitude,
        _longitude,
        _store.latitude,
        _store.longitude,
      );

  double get _angle => relativeAngle(
        Geolocator.bearingBetween(_latitude, _longitude, _store.latitude, _store.longitude),
        _heading,
      );

  void _listenToCompass() {
    final events = FlutterCompass.events;
    if (events == null) {
      _hasCompass = false;
      return;
    }

    _compass = events.listen(
      (event) {
        final heading = event.heading;
        if (heading != null && mounted) {
          setState(() {
            _hasCompass = true;
            _heading = heading;
          });
          _react();
        }
      },
      onError: (Object _) {
        if (mounted) {
          setState(() => _hasCompass = false);
        }
      },
    );
  }

  void _onWalkTick() {
    final start = widget.demoStart;
    final progress = Curves.easeInOut.transform(_walk.value);

    setState(() {
      _latitude = lerpDouble(start.latitude, _store.latitude, progress)!;
      _longitude = lerpDouble(start.longitude, _store.longitude, progress)!;
    });
    _react();
  }

  /// Fala, vibra e anuncia conforme o visitante vira ou se aproxima da loja.
  void _react() {
    if (!mounted) {
      return;
    }

    final distance = _distance;
    final hint = directionHint(_angle, distance);

    if (distance < arrivalDistance) {
      if (!_arrivalAnnounced) {
        _arrivalAnnounced = true;
        HapticFeedback.heavyImpact();
        final message = 'Você chegou. A ${_store.name} está à sua frente.';
        SemanticsService.announce(message, TextDirection.ltr);
        _say(message, force: true);
      }
      return;
    }

    if (distance < nearDistance && !_nearAnnounced) {
      _nearAnnounced = true;
      HapticFeedback.mediumImpact();
      _say('Falta pouco. A ${_store.name} está a ${distance.round()} metros.', force: true);
      return;
    }

    if (hint != _lastSpokenHint) {
      if (hint == 'Siga em frente') {
        HapticFeedback.selectionClick();
      }
      _say(hint == 'Siga em frente' ? '$hint, ${distance.round()} metros' : hint, hint: hint);
    }
  }

  void _say(String text, {String? hint, bool force = false}) {
    final now = DateTime.now();
    if (!force && now.difference(_lastSpokenAt) < const Duration(milliseconds: 2500)) {
      return;
    }

    _lastSpokenHint = hint ?? _lastSpokenHint;
    _lastSpokenAt = now;
    if (_voiceOn) {
      Voice.say(text);
    }
  }

  Future<void> _setDemoMode(bool demo) async {
    await _gps?.cancel();
    _gps = null;
    _walk.stop();

    if (demo) {
      setState(() {
        _demoMode = true;
        _gpsMessage = null;
        _latitude = widget.demoStart.latitude;
        _longitude = widget.demoStart.longitude;
        _startDistance = null;
      });
      return;
    }

    final problem = await _locationProblem();
    if (!mounted) {
      return;
    }
    if (problem != null) {
      setState(() => _gpsMessage = problem);
      return;
    }

    setState(() {
      _demoMode = false;
      _gpsMessage = 'Procurando sua localização…';
      _startDistance = null;
    });

    _gps = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 1,
      ),
    ).listen(
      (position) {
        if (mounted) {
          setState(() {
            _gpsMessage = null;
            _latitude = position.latitude;
            _longitude = position.longitude;
          });
          _react();
        }
      },
      onError: (Object _) {
        if (mounted) {
          setState(() => _gpsMessage = 'Não foi possível obter sua localização.');
        }
      },
    );
  }

  Future<String?> _locationProblem() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return 'Ative a localização do celular para usar o GPS.';
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return 'Permita o acesso à localização para usar o GPS.';
      }
    } on Exception {
      return 'O GPS não está disponível neste aparelho.';
    }

    return null;
  }

  void _goToNextStop() {
    if (widget.isLastStop) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => RouteDoneScreen(stops: widget.route)),
      );
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => CompassScreen.forRoute(
          route: widget.route,
          stopIndex: widget.stopIndex + 1,
        ),
      ),
    );
  }

  void _toggleVoice() {
    setState(() => _voiceOn = !_voiceOn);
    if (_voiceOn) {
      Voice.say('Voz ligada');
    } else {
      Voice.stop();
    }
  }

  /// Soma à rotação da seta só a menor diferença, para ela não dar a volta
  /// inteira ao cruzar o norte.
  double _turnsFor(double angle) {
    final last = _lastAngle;
    if (last != null) {
      var delta = (angle - last) % 360;
      if (delta > 180) {
        delta -= 360;
      }
      _arrowTurns += delta / 360;
    } else {
      _arrowTurns = angle / 360;
    }
    _lastAngle = angle;

    return _arrowTurns;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final store = _store;
    final distance = _distance;
    final angle = _angle;
    final arrived = distance < arrivalDistance;
    final near = distance < nearDistance;
    final hint = directionHint(angle, distance);
    final startDistance = _startDistance ??= math.max(distance, 1);
    final progress = (1 - distance / startDistance).clamp(0.0, 1.0);
    final distanceLabel = distance >= 1000
        ? '${(distance / 1000).toStringAsFixed(1).replaceAll('.', ',')} km'
        : '${distance.round()} m';
    final quick = reduceMotion(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isRoute
              ? 'Parada ${widget.stopIndex + 1} de ${widget.route.length}'
              : 'Me leve até a loja',
        ),
        actions: [
          IconButton(
            tooltip: _voiceOn ? 'Desligar a voz' : 'Ligar a voz',
            onPressed: _toggleVoice,
            icon: Icon(_voiceOn ? Icons.volume_up_rounded : Icons.volume_off_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (widget.isRoute)
              LinearProgressIndicator(
                value: (widget.stopIndex + 1) / widget.route.length,
                semanticsLabel: 'Progresso do roteiro',
              ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Text(
                    store.name,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                  if (widget.isRoute)
                    Text(
                      widget.route[widget.stopIndex].item,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleSmall?.copyWith(color: colors.secondary),
                    ),
                  Text(
                    '${store.category} · ${store.floorLabel}',
                    style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Semantics(
                    liveRegion: true,
                    label: arrived
                        ? 'Você está em frente à ${store.name}'
                        : '$hint. A loja está a $distanceLabel.',
                    child: ExcludeSemantics(
                      child: AnimatedSwitcher(
                        duration: Duration(milliseconds: quick ? 0 : 450),
                        switchInCurve: Curves.easeOutBack,
                        child: arrived
                            ? ArrivalPulse(
                                key: const ValueKey('arrived'),
                                size: 290,
                                color: AppColors.success,
                                child: CatalogImage(
                                  url: store.imageUrl,
                                  category: store.category,
                                  size: 180,
                                ),
                              )
                            : SizedBox.square(
                                key: const ValueKey('dial'),
                                dimension: 290,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    AnimatedRotation(
                                      turns: -_heading / 360,
                                      duration: Duration(milliseconds: quick ? 0 : 250),
                                      child: CompassDial(
                                        size: 290,
                                        ringColor: colors.surfaceContainerHigh,
                                        tickColor: colors.outline,
                                        labelColor: colors.onSurfaceVariant,
                                        northColor: colors.tertiary,
                                      ),
                                    ),
                                    AnimatedContainer(
                                      duration: Duration(milliseconds: quick ? 0 : 300),
                                      width: 176,
                                      height: 176,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: near
                                            ? AppColors.success
                                            : hint == 'Siga em frente'
                                                ? colors.primary
                                                : colors.primaryContainer,
                                      ),
                                    ),
                                    AnimatedRotation(
                                      turns: _turnsFor(angle),
                                      duration: Duration(milliseconds: quick ? 0 : 280),
                                      curve: Curves.easeOut,
                                      child: Icon(
                                        Icons.navigation_rounded,
                                        size: 132,
                                        color: near || hint == 'Siga em frente'
                                            ? Colors.white
                                            : colors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (arrived)
              FadeSlideIn(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.where_to_vote_rounded, color: Colors.white, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Você chegou',
                              style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
                            ),
                            Text(
                              'A ${store.name} está à sua frente',
                              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              Text(hint, textAlign: TextAlign.center, style: theme.textTheme.headlineMedium),
              const SizedBox(height: 2),
              Text(
                near ? 'Falta pouco: $distanceLabel' : 'A cerca de $distanceLabel',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: near ? AppColors.success : colors.onSurfaceVariant,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(40, 10, 40, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    color: near ? AppColors.success : colors.secondary,
                    backgroundColor: colors.surfaceContainerHighest,
                    semanticsLabel: 'Proximidade da loja',
                  ),
                ),
              ),
              if (store.floor > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Chip(
                    avatar: const Icon(Icons.escalator, size: 18),
                    label: Text('Suba até o ${store.floorLabel}'),
                  ),
                ),
            ],
            if (!_hasCompass && !arrived)
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 10, 24, 0),
                child: Text(
                  'Este aparelho não tem sensor de bússola. A seta vale com o topo do celular apontado para o norte.',
                  textAlign: TextAlign.center,
                ),
              ),
            if (_gpsMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                child: Text(_gpsMessage!, textAlign: TextAlign.center),
              ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.isRoute)
                    FilledButton.icon(
                      onPressed: _goToNextStop,
                      icon: Icon(
                        widget.isLastStop ? Icons.flag_rounded : Icons.arrow_forward_rounded,
                      ),
                      label: Text(
                        widget.isLastStop ? 'Cheguei, concluir roteiro' : 'Cheguei, próxima parada',
                      ),
                    ),
                  if (_demoMode && !arrived && !_walk.isAnimating)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: OutlinedButton.icon(
                        onPressed: () => _walk.forward(from: 0),
                        icon: const Icon(Icons.directions_walk_rounded),
                        label: const Text('Simular caminhada'),
                      ),
                    ),
                ],
              ),
            ),
            SwitchListTile(
              title: const Text('Modo demonstração'),
              subtitle: Text(
                widget.isRoute && widget.stopIndex > 0
                    ? 'Usa a parada anterior como sua posição'
                    : 'Usa a entrada principal como sua posição',
              ),
              value: _demoMode,
              onChanged: _setDemoMode,
            ),
          ],
        ),
      ),
    );
  }
}
