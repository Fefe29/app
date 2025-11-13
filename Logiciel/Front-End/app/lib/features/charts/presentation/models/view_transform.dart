/// Modèle partagé pour la transformation de vue (projection canvas)
import 'package:flutter/material.dart';

/// Classe pour transformer les coordonnées Mercator locales en pixels canvas
class ViewTransform {
  const ViewTransform({
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.scale,
    required this.offsetX,
    required this.offsetY,
  });

  // Limites du viewport en coordonnées Mercator locales
  final double minX, maxX, minY, maxY;
  
  // Paramètres de zoom et de pan
  final double scale, offsetX, offsetY;

  /// Projette une coordonnée Mercator locale en pixels canvas
  Offset project(double x, double y, Size size) {
    final px = offsetX + (x - minX) * scale;
    final py = size.height - offsetY - (y - minY) * scale; // Y logique vers le haut
    return Offset(px, py);
  }

  /// Projette un point depuis les pixels canvas vers les coordonnées Mercator locales
  Offset unproject(double pixelX, double pixelY, Size canvasSize) {
    final mercatorX = (pixelX - offsetX) / scale + minX;
    final mercatorY = (canvasSize.height - pixelY - offsetY) / scale + minY;
    return Offset(mercatorX, mercatorY);
  }

  /// Retourne la largeur du viewport en unités Mercator locales
  double get spanX => maxX - minX;
  
  /// Retourne la hauteur du viewport en unités Mercator locales
  double get spanY => maxY - minY;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ViewTransform &&
          runtimeType == other.runtimeType &&
          minX == other.minX &&
          maxX == other.maxX &&
          minY == other.minY &&
          maxY == other.maxY &&
          scale == other.scale &&
          offsetX == other.offsetX &&
          offsetY == other.offsetY;

  @override
  int get hashCode =>
      minX.hashCode ^
      maxX.hashCode ^
      minY.hashCode ^
      maxY.hashCode ^
      scale.hashCode ^
      offsetX.hashCode ^
      offsetY.hashCode;

  @override
  String toString() =>
      'ViewTransform(bounds: ($minX, $minY) to ($maxX, $maxY), scale: $scale, offset: ($offsetX, $offsetY))';
}
