import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:guidewire_gig_ins/services/api_service.dart';

/// Service that fetches live weather, AQI, and traffic from 3rd-party APIs.
/// Replaces the local backend /environment endpoint.
class EnvironmentService {
  static const Duration _timeout = Duration(seconds: 45);

  // ── API Keys ────────────────────────────────────────────────────────────────
  static const String _aqiApiKey = '258d64580bceb19f1efcb0a62fb81af6';
  static const String _orsApiKey =
      'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6IjhiNjUyZGY1YzMzODQyODA5MWFlMWFmZTFlZDM5ZDMzIiwiaCI6Im11cm11cjY0In0=';

  // ── Endpoints ───────────────────────────────────────────────────────────────
  static const String _weatherBase = 'https://api.open-meteo.com/v1/forecast';
  static const String _aqiBase =
      'http://api.openweathermap.org/data/2.5/air_pollution';
  static const String _orsDirections =
      'https://api.openrouteservice.org/v2/directions/driving-car';

  /// Fetches and assembles the full [EnvironmentModel] from 3 live APIs.
  static Future<EnvironmentModel> getEnvironment(
      double lat, double lon) async {
    final results = await Future.wait([
      _fetchWeather(lat, lon),
      _fetchAqi(lat, lon),
      _fetchTraffic(lat, lon),
    ]);

    final weather = results[0] as WeatherData;
    final aqi = results[1] as AqiData;
    final traffic = results[2] as TrafficData;
    final now = DateTime.now();

    return EnvironmentModel(
      weather: weather,
      aqi: aqi,
      traffic: traffic,
      context: ContextData(
        hour: now.hour,
        dayType: (now.weekday == DateTime.saturday ||
                now.weekday == DateTime.sunday)
            ? 'weekend'
            : 'weekday',
      ),
    );
  }

  // ── 1. Weather — Open-Meteo (free, no key) ─────────────────────────────────
  static Future<WeatherData> _fetchWeather(double lat, double lon) async {
    final uri = Uri.parse(
      '$_weatherBase'
      '?latitude=$lat&longitude=$lon'
      '&current=temperature_2m,wind_speed_10m,precipitation'
      '&hourly=relative_humidity_2m,precipitation'
      '&forecast_days=1',
    );

    try {
      final response = await http.get(uri).timeout(_timeout);
      if (response.statusCode != 200) {
        throw Exception(
            'Weather API failed (${response.statusCode})');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final current = json['current'] as Map<String, dynamic>;
      final hourly = json['hourly'] as Map<String, dynamic>;

      // Derive humidity from hourly array at current hour
      final now = DateTime.now();
      final hourlyTimes = (hourly['time'] as List).cast<String>();
      int hourIndex = 0;
      for (int i = 0; i < hourlyTimes.length; i++) {
        if (DateTime.tryParse(hourlyTimes[i])?.hour == now.hour) {
          hourIndex = i;
          break;
        }
      }

      final humidity = (hourly['relative_humidity_2m'] as List)
          .elementAtOrNull(hourIndex);
      final precipitation = (hourly['precipitation'] as List)
          .elementAtOrNull(hourIndex);

      return WeatherData(
        temperature: (current['temperature_2m'] as num).toDouble(),
        humidity: humidity != null ? (humidity as num).toDouble() : 0.0,
        windSpeed: (current['wind_speed_10m'] as num).toDouble(),
        rainfall: precipitation != null ? (precipitation as num).toDouble() : 0.0,
      );
    } catch (e) {
      // Graceful fallback if weather API is unreachable
      return WeatherData(
          temperature: 30.0, humidity: 65.0, windSpeed: 10.0, rainfall: 0.0);
    }
  }

  // ── 2. AQI — OpenWeatherMap ─────────────────────────────────────────────────
  static Future<AqiData> _fetchAqi(double lat, double lon) async {
    final uri = Uri.parse(
        '$_aqiBase?lat=$lat&lon=$lon&appid=$_aqiApiKey');

    try {
      final response = await http.get(uri).timeout(_timeout);
      if (response.statusCode != 200) {
        throw Exception('AQI API failed (${response.statusCode})');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final list = json['list'] as List;
      if (list.isEmpty) throw Exception('Empty AQI response');

      final entry = list[0] as Map<String, dynamic>;
      final main = entry['main'] as Map<String, dynamic>;
      final components = entry['components'] as Map<String, dynamic>;

      // OWM AQI scale: 1=Good, 2=Fair, 3=Moderate, 4=Poor, 5=Very Poor
      return AqiData(
        aqi: (main['aqi'] as num).toInt(),
        pm25: (components['pm2_5'] as num).toDouble(),
        pm10: (components['pm10'] as num).toDouble(),
      );
    } catch (e) {
      return AqiData(aqi: 2, pm25: 25.0, pm10: 50.0);
    }
  }

  // ── 3. Traffic — OpenRouteService Directions  ───────────────────────────────
  /// We compute a ~1km route from user location to a point slightly north.
  /// Compare actual travel time vs. expected free-flow time to derive congestion.
  static Future<TrafficData> _fetchTraffic(double lat, double lon) async {
    // Offset ~1 km north (1 degree lat ≈ 111 km → 0.009° ≈ 1 km)
    final destLat = lat + 0.009;
    final destLon = lon;

    final body = jsonEncode({
      'coordinates': [
        [lon, lat],       // ORS uses [lon, lat] order
        [destLon, destLat],
      ]
    });

    try {
      final response = await http
          .post(
            Uri.parse(_orsDirections),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json',
              'Authorization': _orsApiKey,
            },
            body: body,
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        throw Exception('Traffic API failed (${response.statusCode})');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = json['routes'] as List?;
      if (routes == null || routes.isEmpty) throw Exception('No routes returned');

      final summary =
          (routes[0] as Map<String, dynamic>)['summary'] as Map<String, dynamic>;
      final durationSecs = (summary['duration'] as num).toDouble();
      final distanceM = (summary['distance'] as num).toDouble();

      // Free-flow speed ≈ 60 km/h = 16.67 m/s
      // Score = actual_time / expected_time
      final expectedSecs = distanceM / 16.67;
      final trafficScore = expectedSecs > 0 ? durationSecs / expectedSecs : 1.0;

      String trafficLevel;
      if (trafficScore < 1.3) {
        trafficLevel = 'LOW';
      } else if (trafficScore < 1.8) {
        trafficLevel = 'MEDIUM';
      } else {
        trafficLevel = 'HIGH';
      }

      return TrafficData(
        trafficScore: double.parse(trafficScore.toStringAsFixed(2)),
        trafficLevel: trafficLevel,
      );
    } catch (e) {
      // Fallback: use time-of-day heuristic if API fails
      return _trafficFallback();
    }
  }

  /// Time-of-day fallback when ORS is unavailable
  static TrafficData _trafficFallback() {
    final h = DateTime.now().hour;
    // Peak hours: 8–10 AM, 5–8 PM
    if ((h >= 8 && h <= 10) || (h >= 17 && h <= 20)) {
      return TrafficData(trafficScore: 2.1, trafficLevel: 'HIGH');
    } else if ((h >= 7 && h < 8) || (h >= 11 && h <= 14) || (h >= 21)) {
      return TrafficData(trafficScore: 1.4, trafficLevel: 'MEDIUM');
    }
    return TrafficData(trafficScore: 1.0, trafficLevel: 'LOW');
  }
}
