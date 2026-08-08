import 'package:flutter/material.dart';

/// Base class for every object that lives on the play field.
///
/// Provides position/size, visibility flag and AABB collision.
class GameObject {
  double x;
  double y;
  double width;
  double height;
  bool isVisible;

  GameObject({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.isVisible = true,
  });

  /// AABB collision check. Invisible objects never collide.
  bool collidesWith(GameObject other) {
    if (!isVisible || !other.isVisible) return false;

    return (x < other.x + other.width &&
        x + width > other.x &&
        y < other.y + other.height &&
        y + height > other.y);
  }

  /// Center point of the object's bounding box.
  Offset get center => Offset(x + width / 2, y + height / 2);
}
