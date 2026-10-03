import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_maplibre/flutter_map_maplibre.dart';
import 'package:latlong2/latlong.dart';

/// The same vector basemap and interaction limits for every map in the app.
class LocationMap extends StatelessWidget {
  const LocationMap({
    required this.center,
    required this.markers,
    this.zoom = 16,
    this.cameraFit,
    this.controller,
    super.key,
  });

  final LatLng center;
  final List<Marker> markers;
  final double zoom;
  final CameraFit? cameraFit;
  final MapController? controller;

  @override
  Widget build(BuildContext context) => FlutterMap(
        mapController: controller,
        options: MapOptions(
          initialCenter: center,
          initialZoom: zoom,
          initialCameraFit: cameraFit,
          minZoom: 0,
          maxZoom: 20,
          cameraConstraint: CameraConstraint.containCenter(
            bounds: LatLngBounds(
              const LatLng(-85.05112878, -180),
              const LatLng(85.05112878, 180),
            ),
          ),
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
        ),
        children: [
          const MapLibreLayer(
            initStyle: 'https://tiles.openfreemap.org/styles/liberty',
          ),
          MarkerLayer(markers: markers),
        ],
      );
}
