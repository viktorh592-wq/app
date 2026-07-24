/// GPX service — parse and export GPX files (FR-008 — Import/Export GPX).
/// Imported data receive new local UUIDs (UUID_Policy.md).
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
