/// Endereço base da API do shopping.
///
/// Para apontar para outro servidor sem alterar o código, rode com
/// `--dart-define=API_URL=http://192.168.0.10:8000/api/v1`.
const String apiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'https://hackarun8.safra.dev/api/v1',
);

/// Entrada principal do shopping fictício, usada como posição do visitante
/// no modo demonstração da bússola.
const double mallEntranceLatitude = -23.5505;
const double mallEntranceLongitude = -46.6335;

/// Estacionamento do shopping fictício, usado como vaga quando o aparelho
/// não tem GPS disponível.
const double mallParkingLatitude = -23.55082;
const double mallParkingLongitude = -46.63318;
