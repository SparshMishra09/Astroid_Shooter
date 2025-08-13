import 'package:shared_preferences/shared_preferences.dart';

class ScoreService {
  static const String _highScoreKey = 'high_score';
  
  // Save high score to persistent storage
  static Future<void> saveHighScore(int score) async {
    final prefs = await SharedPreferences.getInstance();
    final currentHighScore = await getHighScore();
    
    // Only save if the new score is higher than the current high score
    if (score > currentHighScore) {
      await prefs.setInt(_highScoreKey, score);
    }
  }
  
  // Get high score from persistent storage
  static Future<int> getHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_highScoreKey) ?? 0;
  }
  
  // Reset high score (for testing purposes)
  static Future<void> resetHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_highScoreKey);
  }
}