import 'dart:math';
import 'package:flutter/material.dart';

// Base class for all game objects
abstract class GameObject {
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

  // Check if this object collides with another object
  bool collidesWith(GameObject other) {
    if (!isVisible || !other.isVisible) return false;
    
    return (x < other.x + other.width &&
        x + width > other.x &&
        y < other.y + other.height &&
        y + height > other.y);
  }

  // Get the center point of the object
  Offset get center => Offset(x + width / 2, y + height / 2);
}

// Player spaceship
class Player extends GameObject {
  int lives;
  bool isInvulnerable;
  int invulnerabilityTimer;
  
  Player({
    required double x,
    required double y,
    required double width,
    required double height,
    this.lives = 3,
    this.isInvulnerable = false,
    this.invulnerabilityTimer = 0,
  }) : super(
          x: x,
          y: y,
          width: width,
          height: height,
        );
  
  // Move player to a new position
  void moveTo(double newX, double screenWidth) {
    // Ensure player stays within screen bounds
    if (newX >= 0 && newX <= screenWidth - width) {
      x = newX;
    }
  }
  
  // Handle player getting hit by an asteroid
  void hit() {
    if (!isInvulnerable && lives > 0) {
      lives--;
      isInvulnerable = true;
      invulnerabilityTimer = 90; // 90 frames = ~1.5 seconds at 60fps
    }
  }
  
  // Update player state each frame
  void update() {
    if (isInvulnerable) {
      invulnerabilityTimer--;
      if (invulnerabilityTimer <= 0) {
        isInvulnerable = false;
      }
    }
  }
}

// Asteroid object
class Asteroid extends GameObject {
  double speedY;
  double rotationAngle;
  double rotationSpeed;
  
  Asteroid({
    required double x,
    required double y,
    required double width,
    required double height,
    required this.speedY,
    this.rotationAngle = 0,
    this.rotationSpeed = 0,
  }) : super(
          x: x,
          y: y,
          width: width,
          height: height,
        );
  
  // Update asteroid position and rotation
  void update(double screenHeight) {
    y += speedY;
    rotationAngle += rotationSpeed;
    
    // If asteroid goes off screen, mark it as not visible
    if (y > screenHeight) {
      isVisible = false;
    }
  }
  
  // Factory method to create a random asteroid
  static Asteroid random(double screenWidth, double asteroidSize) {
    final random = Random();
    
    // Random x position within screen bounds
    final x = random.nextDouble() * (screenWidth - asteroidSize);
    
    // Start above the screen
    final y = -asteroidSize - random.nextDouble() * 300;
    
    // Random vertical speed
    final speedY = 1 + random.nextDouble() * 3;
    
    // Random rotation speed
    final rotationSpeed = (random.nextDouble() - 0.5) * 0.1;
    
    return Asteroid(
      x: x,
      y: y,
      width: asteroidSize,
      height: asteroidSize,
      speedY: speedY,
      rotationSpeed: rotationSpeed,
    );
  }
}

// Bullet fired by player
class Bullet extends GameObject {
  double speedY;
  
  Bullet({
    required double x,
    required double y,
    required double width,
    required double height,
    required this.speedY,
  }) : super(
          x: x,
          y: y,
          width: width,
          height: height,
        );
  
  // Update bullet position
  void update() {
    y -= speedY;
    
    // If bullet goes off screen (top), mark it as not visible
    if (y + height < 0) {
      isVisible = false;
    }
  }
}

// Game state class to manage overall game state
class GameState {
  int score = 0;
  int highScore = 0;
  bool isGameOver = false;
  bool isPaused = false;
  
  // Reset game state for a new game
  void reset() {
    score = 0;
    isGameOver = false;
    isPaused = false;
  }
  
  // Update high score if current score is higher
  void updateHighScore() {
    if (score > highScore) {
      highScore = score;
    }
  }
}