import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';

import '../api.dart';
import '../config.dart';
import '../models.dart';
import '../settings.dart';
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

/// Distância, em metros, a partir da qual uma loja com promoção é oferecida
/// ao visitante que passa por perto.
const double offerRadius = 16;

/// Promoção da loja mais próxima do visitante, entre as que ainda não foram
/// mostradas, ou `null` se nenhuma estiver dentro do raio.
Promotion? nearbyOffer({
  required double latitude,
  required double longitude,
  required List<Promotion> offers,
  required Set<int> seenStoreIds,
  int? destinationStoreId,
  double radius = offerRadius,
}) {
  Promotion? closest;
  var closestDistance = radius;

  for (final offer in offers) {
    final store = offer.store;
    if (store == null || store.id == destinationStoreId || seenStoreIds.contains(store.id)) {
      continue;
    }

    final distance = Geolocator.distanceBetween(
      latitude,
      longitude,
      store.latitude,
      store.longitude,
    );
    if (distance <= closestDistance) {
      closest = offer;
      closestDistance = distance;
    }
  }

  return closest;
}

class CompassScreen extends StatefulWidget {
  /// Bússola para uma única loja.
  const CompassScreen({super.key, required Store store})
      : singleStore = store,
        route = const [],
        stopIndex = 0,
        isCar = false,
        startWithGps = false;

  /// Bússola guiando uma parada de um roteiro.
  const CompassScreen.forRoute({
    super.key,
    required this.route,
    required this.stopIndex,
  })  : singleStore = null,
        isCar = false,
        startWithGps = false;

  /// Bússola de volta à vaga onde o visitante estacionou. A vaga é passada
  /// como uma "loja" que guarda só o nome, a anotação e as coordenadas.
  const CompassScreen.toCar({
    super.key,
    required Store car,
    this.startWithGps = false,
  })  : singleStore = car,
        route = const [],
        stopIndex = 0,
        isCar = true;

  final Store? singleStore;
  final List<RouteStop> route;
  final int stopIndex;

  /// Verdadeiro quando o destino é o carro do visitante, e não uma loja.
  final bool isCar;

  /// Abre já usando o GPS do aparelho em vez do modo demonstração.
  final bool startWithGps;

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

  /// Promoções ativas do shopping, para avisar quando o visitante passa
  /// perto de uma loja com oferta.
  bool _offersOn = false;
  List<Promotion> _offers = const [];
  final Set<int> _offeredStoreIds = {};
  Promotion? _currentOffer;
  Timer? _offerTimer;

  Store get _store => widget.store;

  /// Frase de chegada: "A Passo Certo está à sua frente" ou, para o carro,
  /// "Seu carro está por aqui".
  String get _arrivalPhrase =>
      widget.isCar ? 'Seu carro está por aqui' : 'A ${_store.name} está à sua frente';

  @override
  void initState() {
    super.initState();
    _walk = AnimationController(vsync: this, duration: const Duration(seconds: 7))
      ..addListener(_onWalkTick);
    _listenToCompass();
    _loadOffers();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.startWithGps) {
        _setDemoMode(false);
      }
      _react();
    });
  }

  Future<void> _loadOffers() async {
    final enabled = await Settings.offersOnTheWay();
    if (!mounted) {
      return;
    }
    setState(() => _offersOn = enabled);

    try {
      final offers = await api.fetchPromotions();
      if (mounted) {
        _offers = offers;
        _react();
      }
    } catch (_) {
      // Sem as promoções, a bússola segue funcionando só com a navegação.
    }
  }

  void _setOffersOn(bool enabled) {
    setState(() {
      _offersOn = enabled;
      if (!enabled) {
        _currentOffer = null;
      }
    });
    Settings.setOffersOnTheWay(enabled);
    if (enabled) {
      _react();
    }
  }

  /// Mostra a oferta de uma loja pela qual o visitante está passando, se
  /// ele escolheu receber esses avisos.
  void _checkOffers() {
    if (!_offersOn) {
      return;
    }

    final offer = nearbyOffer(
      latitude: _latitude,
      longitude: _longitude,
      offers: _offers,
      seenStoreIds: _offeredStoreIds,
      destinationStoreId: widget.isCar ? null : _store.id,
    );
    final store = offer?.store;
    if (offer == null || store == null) {
      return;
    }

    _offeredStoreIds.add(store.id);
    _offerTimer?.cancel();
    _offerTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) {
        setState(() => _currentOffer = null);
      }
    });

    // O aviso é discreto de propósito: um cartão e uma vibração leve, sem
    // interromper as instruções de voz da navegação.
    setState(() => _currentOffer = offer);
    HapticFeedback.lightImpact();
  }

  @override
  void dispose() {
    _compass?.cancel();
    _gps?.cancel();
    _offerTimer?.cancel();
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
        final message = 'Você chegou. $_arrivalPhrase.';
        SemanticsService.announce(message, TextDirection.ltr);
        _say(message, force: true);
      }
      return;
    }

    if (distance < nearDistance && !_nearAnnounced) {
      _nearAnnounced = true;
      HapticFeedback.mediumImpact();
      _say(
        widget.isCar
            ? 'Falta pouco. Seu carro está a ${distance.round()} metros.'
            : 'Falta pouco. A ${_store.name} está a ${distance.round()} metros.',
        force: true,
      );
      return;
    }

    _checkOffers();

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
              : widget.isCar
                  ? 'Voltar ao carro'
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
                    widget.isCar ? store.description : '${store.category} · ${store.floorLabel}',
                    textAlign: TextAlign.center,
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
                        ? 'Você chegou. $_arrivalPhrase'
                        : '$hint. Faltam $distanceLabel.',
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
                              _arrivalPhrase,
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
              if (store.floor > 1 && !widget.isCar)
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
            if (_currentOffer != null && !arrived)
              _OfferBanner(
                key: ValueKey(_currentOffer!.id),
                offer: _currentOffer!,
                onDismiss: () => setState(() => _currentOffer = null),
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
              dense: true,
              title: const Text('Ofertas no caminho'),
              subtitle: const Text(
                'Avisa ao passar por uma loja em promoção',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              value: _offersOn,
              onChanged: _setOffersOn,
            ),
            SwitchListTile(
              dense: true,
              title: const Text('Modo demonstração'),
              subtitle: Text(
                widget.isRoute && widget.stopIndex > 0
                    ? 'Usa a parada anterior como sua posição'
                    : 'Usa a entrada principal como sua posição',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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

/// Aviso de que o visitante está passando por uma loja com promoção.
class _OfferBanner extends StatelessWidget {
  const _OfferBanner({super.key, required this.offer, required this.onDismiss});

  final Promotion offer;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final store = offer.store!;
    final price = offer.price;

    return FadeSlideIn(
      child: Semantics(
        liveRegion: true,
        container: true,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          decoration: BoxDecoration(
            color: colors.tertiaryContainer,
            borderRadius: BorderRadius.circular(18),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => openStore(context, store),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
              child: Row(
                children: [
                  CatalogImage(url: store.imageUrl, category: store.category, size: 52),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.local_offer_rounded, size: 14, color: colors.tertiary),
                            const SizedBox(width: 4),
                            Text(
                              'Oferta no caminho',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colors.tertiary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          offer.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(color: colors.onTertiaryContainer),
                        ),
                        Text(
                          [
                            store.name,
                            store.floorLabel,
                            if (price != null) formatPrice(price),
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: colors.onTertiaryContainer),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Dispensar oferta',
                    onPressed: onDismiss,
                    icon: Icon(Icons.close_rounded, color: colors.onTertiaryContainer),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
