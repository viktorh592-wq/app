/// GPX service — parse and export GPX / KML files
/// (FR-008 — Import/Export GPX, V2 ROUTES_IMPORT.md §1).
/// Imported data receive new local UUIDs (UUID_Policy.md).
///
/// V3 Sprint 5 (FIX_PLAN S5-T6) — added KML parser + dispatcher by extension.
/// FIT format is intentionally not supported (V2 spec lists it, but the
/// format is proprietary binary; rejected with a clear localized message in
/// the routes tab — see activity_route_tab.dart).
import 'package:xml/xml.dart';

import 'package:pokatuha/core/errors/app_error.dart';
import 'package:pokatuha/database/collections/embedded/geo_point.dart';

class GpxService {
  /// Parse a GPX document into a list of [GeoPoint] track / route points.
  List<GeoPoint> parse(String gpxContent) {
    try {
      final document = XmlDocument.parse(gpxContent);
      final points = <GeoPoint>[];
      for (final node in document.findAllElements('trkpt').followedBy(document
          .findAllElements('rtept')
          .followedBy(document.findAllElements('wpt')))) {
        final lat = double.tryParse(node.getAttribute('lat') ?? '');
        final lng = double.tryParse(node.getAttribute('lon') ?? '');
        if (lat == null || lng == null) continue;
        final eleNode = _firstOrNull(node.findElements('ele'));
        final timeNode = _firstOrNull(node.findElements('time'));
        final elevation = double.tryParse(eleNode?.innerText ?? '') ?? 0;
        final timestamp = _parseTime(timeNode?.innerText);
        points.add(GeoPoint(
          lat: lat,
          lng: lng,
          elevation: elevation,
          timestamp: timestamp,
        ));
      }
      if (points.isEmpty) {
        throw const ValidationError('GPX contains no valid points');
      }
      return points;
    } on XmlException catch (e) {
      throw ValidationError('Invalid GPX XML: $e');
    } on AppError {
      rethrow;
    } catch (e) {
      throw ValidationError('GPX parse error: $e');
    }
  }

  /// Parse a KML document into a list of [GeoPoint] track / route points
  /// (V2 ROUTES_IMPORT.md §1 — KML support, FIX_PLAN S5-T6).
  ///
  /// Two coordinate sources are supported:
  ///  1. `<coordinates>lng,lat,alt lng,lat,alt ...</coordinates>` inside
  ///     `<Point>`, `<LineString>`, `<MultiGeometry>` (classic KML).
  ///  2. `<coord>lng lat alt</coord>` per-line triplet inside a `<gx:Track>`
  ///     (Google extension). When `<when>` elements align by count with
  ///     `<coord>` elements, timestamps are attached to each point.
  List<GeoPoint> parseKml(String kmlContent) {
    try {
      final document = XmlDocument.parse(kmlContent);
      final points = <GeoPoint>[];

      // Source 1 — classic <coordinates> elements.
      for (final coordNode in document.findAllElements('coordinates')) {
        final raw = coordNode.innerText.trim();
        if (raw.isEmpty) continue;
        for (final token in raw.split(RegExp(r'\s+'))) {
          final parts = token.split(',');
          if (parts.length < 2) continue;
          final lng = double.tryParse(parts[0]);
          final lat = double.tryParse(parts[1]);
          if (lat == null || lng == null) continue;
          final elevation =
              parts.length >= 3 ? (double.tryParse(parts[2]) ?? 0) : 0.0;
          points.add(GeoPoint(
            lat: lat,
            lng: lng,
            elevation: elevation,
            timestamp: 0,
          ));
        }
      }

      // Source 2 — gx:Track `<coord>` elements (space-separated, not comma).
      // Only used when no classic <coordinates> was found.
      var gxTimestamps = <int>[];
      if (points.isEmpty) {
        final coordStringNodes =
            document.findAllElements('coord').toList(growable: false);
        if (coordStringNodes.isNotEmpty) {
          final whenNodes = document.findAllElements('when').toList();
          if (whenNodes.isNotEmpty && whenNodes.length == coordStringNodes.length) {
            gxTimestamps = whenNodes
                .map((n) => _parseTime(n.innerText))
                .toList(growable: false);
          }
          for (var i = 0; i < coordStringNodes.length; i++) {
            final token = coordStringNodes[i].innerText.trim();
            final parts = token.split(RegExp(r'\s+'));
            if (parts.length < 2) continue;
            final lng = double.tryParse(parts[0]);
            final lat = double.tryParse(parts[1]);
            if (lat == null || lng == null) continue;
            final elevation =
                parts.length >= 3 ? (double.tryParse(parts[2]) ?? 0) : 0.0;
            final ts = i < gxTimestamps.length ? gxTimestamps[i] : 0;
            points.add(GeoPoint(
              lat: lat,
              lng: lng,
              elevation: elevation,
              timestamp: ts,
            ));
          }
        }
      } else if (document.findAllElements('coord').isNotEmpty) {
        // Classic coordinates were found — but a gx:Track may also be present
        // with matching `<when>` count. Attach timestamps in that case.
        final coordStringNodes =
            document.findAllElements('coord').toList(growable: false);
        final whenNodes = document.findAllElements('when').toList();
        if (whenNodes.length == coordStringNodes.length &&
            whenNodes.length == points.length) {
          for (var i = 0; i < points.length; i++) {
            points[i].timestamp = _parseTime(whenNodes[i].innerText);
          }
        }
      }

      if (points.isEmpty) {
        throw const ValidationError('KML contains no valid coordinates');
      }
      return points;
    } on XmlException catch (e) {
      throw ValidationError('Invalid KML XML: $e');
    } on AppError {
      rethrow;
    } catch (e) {
      throw ValidationError('KML parse error: $e');
    }
  }

  /// Dispatcher — pick the right parser based on the file extension
  /// (FIX_PLAN S5-T6). `extension` should be lowercase, without the dot.
  /// Supported: 'gpx', 'kml'. 'fit' throws a clear error so the UI can show
  /// a localized message.
  List<GeoPoint> parseForExtension(String content, String extension) {
    switch (extension) {
      case 'gpx':
        return parse(content);
      case 'kml':
        return parseKml(content);
      case 'fit':
        throw const ValidationError(
            'FIT format is not supported (proprietary binary)');
      default:
        throw ValidationError('Unsupported route format: $extension');
    }
  }

  /// Build a GPX 1.1 document string from a list of track points.
  String build({
    required String name,
    required List<GeoPoint> points,
    String description = '',
  }) {
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element('gpx', attributes: {
      'version': '1.1',
      'creator': 'Pokatuha',
      'xmlns': 'http://www.topografix.com/GPX/1/1',
    }, nest: () {
      builder.element('metadata', nest: () {
        builder.element('name', nest: name);
        if (description.isNotEmpty) {
          builder.element('desc', nest: description);
        }
      });
      builder.element('trk', nest: () {
        builder.element('name', nest: name);
        builder.element('trkseg', nest: () {
          for (final p in points) {
            builder.element('trkpt', attributes: {
              'lat': p.lat.toString(),
              'lon': p.lng.toString(),
            }, nest: () {
              if (p.elevation != 0) {
                builder.element('ele', nest: p.elevation.toString());
              }
              builder.element('time', nest: _formatTime(p.timestamp));
            });
          }
        });
      });
    });
    return builder.buildDocument().toXmlString(pretty: true);
  }

  int _parseTime(String? iso) {
    if (iso == null) return 0;
    try {
      return DateTime.parse(iso).toUtc().millisecondsSinceEpoch;
    } catch (_) {
      return 0;
    }
  }

  String _formatTime(int utcMillis) {
    if (utcMillis == 0) {
      return DateTime.now().toUtc().toIso8601String();
    }
    return DateTime.fromMillisecondsSinceEpoch(utcMillis, isUtc: true)
        .toIso8601String();
  }
}

XmlElement? _firstOrNull(Iterable<XmlElement> iter) =>
    iter.isEmpty ? null : iter.first;
