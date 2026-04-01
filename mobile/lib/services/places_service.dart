import 'dart:async';
import 'package:dio/dio.dart';
import '../config.dart';

class PlacePrediction {
  final String placeId;
  final String description;

  const PlacePrediction({required this.placeId, required this.description});
}

class PlaceDetail {
  final String address;
  final double lat;
  final double lng;

  const PlaceDetail(
      {required this.address, required this.lat, required this.lng});
}

// Pesqueira-PE — centro do município
const double _pesqueiraLat = -8.3619;
const double _pesqueiraLng = -36.6957;
const double _pesqueiraRadius = 15000.0; // 15 km cobre o município inteiro

/// Serviço para chamadas à Places API (New) do Google.
/// Endpoint base: https://places.googleapis.com/v1
class PlacesService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://places.googleapis.com/v1',
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
  ));

  Timer? _debounce;

  /// Cancela o debounce pendente (chamar no dispose do widget).
  void dispose() => _debounce?.cancel();

  /// Retorna sugestões priorizando Pesqueira-PE (locationBias, não bloqueia vizinhos).
  Future<List<PlacePrediction>> autocomplete(String input) async {
    if (input.trim().isEmpty) return [];
    _debounce?.cancel();
    final completer = Completer<List<PlacePrediction>>();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final response = await _dio.post(
          '/places:autocomplete',
          options: Options(headers: {'X-Goog-Api-Key': kGoogleMapsApiKey}),
          data: {
            'input': input,
            'languageCode': 'pt-BR',
            'regionCode': 'BR',
            'locationBias': {
              'circle': {
                'center': {
                  'latitude': _pesqueiraLat,
                  'longitude': _pesqueiraLng,
                },
                'radius': _pesqueiraRadius,
              },
            },
          },
        );
        // ignore: avoid_print
        print('[PlacesService] response: ${response.data}');
        final suggestions =
            (response.data['suggestions'] as List<dynamic>? ?? []);
        final predictions =
            suggestions.where((s) => s['placePrediction'] != null).map((s) {
          final p = s['placePrediction'] as Map<String, dynamic>;
          final text =
              (p['text'] as Map<String, dynamic>?)?['text'] as String? ??
                  (p['structuredFormat'] as Map<String, dynamic>?)?['mainText']
                      ?['text'] as String? ??
                  '';
          return PlacePrediction(
            placeId: p['placeId'] as String,
            description: text,
          );
        }).toList();
        completer.complete(predictions);
      } on DioException catch (e) {
        // ignore: avoid_print
        print('[PlacesService] autocomplete error: ${e.message} — '
            '${e.response?.data}');
        completer.complete([]);
      } catch (e) {
        // ignore: avoid_print
        print('[PlacesService] autocomplete unexpected error: $e');
        completer.complete([]);
      }
    });
    return completer.future;
  }

  /// Retorna detalhes (endereço + lat/lng) de um place pelo [placeId].
  Future<PlaceDetail?> getDetails(String placeId) async {
    try {
      final response = await _dio.get(
        '/places/$placeId',
        options: Options(headers: {
          'X-Goog-Api-Key': kGoogleMapsApiKey,
          'X-Goog-FieldMask': 'id,formattedAddress,location',
        }),
      );
      final data = response.data as Map<String, dynamic>;
      final loc = data['location'] as Map<String, dynamic>?;
      // ignore: avoid_print
      print('[PlacesService] getDetails response: $data');
      if (loc == null) return null;
      return PlaceDetail(
        address: data['formattedAddress'] as String? ?? '',
        lat: (loc['latitude'] as num).toDouble(),
        lng: (loc['longitude'] as num).toDouble(),
      );
    } on DioException catch (e) {
      // ignore: avoid_print
      print('[PlacesService] getDetails error: ${e.message} — '
          '${e.response?.data}');
      return null;
    } catch (e) {
      // ignore: avoid_print
      print('[PlacesService] getDetails unexpected error: $e');
      return null;
    }
  }
}
