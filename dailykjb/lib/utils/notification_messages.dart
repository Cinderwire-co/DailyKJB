import 'dart:math';

class NotificationMessages {
  static final Random _random = Random();

  // Early stage messages (days 1-14) - Getting started, building habit
  static const List<String> _earlyMessages = [
    "Hey! Let's do this, {name}. Let's spend time with the Lord!",
    "Good morning, {name}! Your Bible is waiting for you.",
    "Rise and shine, {name}! Time to meet with God.",
    "{name}, a new day means new mercies. Let's read together!",
    "Hey {name}! Ready to grow in the Word today?",
    "Starting strong, {name}! Your daily reading awaits.",
    "{name}, every journey begins with a single step. Let's take one today!",
    "Good day, {name}! The Lord has something for you in His Word.",
    "{name}, building a habit takes consistency. You've got this!",
    "Hey there, {name}! Let's make time for what matters most.",
  ];

  // Building momentum messages (days 15-30) - Encouragement for consistency
  static const List<String> _buildingMessages = [
    "{name}, you're building something beautiful! Keep reading.",
    "Look at you go, {name}! Your faithfulness is inspiring.",
    "{name}, consistency is key and you're doing great!",
    "Another day, another opportunity, {name}. Let's dive in!",
    "{name}, the Word is a lamp unto your feet. Keep walking!",
    "You're on a roll, {name}! Don't stop now.",
    "{name}, your dedication to God's Word is showing!",
    "Keep pressing on, {name}! You're making real progress.",
    "{name}, every chapter brings you closer to the goal!",
    "Way to stay committed, {name}! Today's reading awaits.",
  ];

  // Established habit messages (days 31-60) - Celebrating progress
  static const List<String> _establishedMessages = [
    "{name}, you've made this a habit! Keep the momentum going.",
    "Wow, {name}! Your commitment to Scripture is amazing.",
    "{name}, you're {percent}% through! The Word is transforming you.",
    "Look how far you've come, {name}! Keep pressing forward.",
    "{name}, your faithfulness is bearing fruit. Keep reading!",
    "You're crushing it, {name}! God's Word is alive in you.",
    "{name}, {daysComplete} days of faithfulness! Well done!",
    "The discipline is paying off, {name}. Keep going strong!",
    "{name}, you're becoming a person of the Word!",
    "Incredible progress, {name}! Today's reading is ready for you.",
  ];

  // Strong progress messages (days 61-90) - Deep encouragement
  static const List<String> _strongProgressMessages = [
    "{name}, you're over halfway! The finish line is in sight.",
    "What an incredible journey, {name}! Keep running the race.",
    "{name}, {percent}% complete! You're an inspiration.",
    "The Word is becoming part of you, {name}. Beautiful!",
    "{name}, your perseverance is remarkable. Keep going!",
    "You've come so far, {name}! Don't give up now.",
    "{name}, {daysComplete} days strong! God is pleased.",
    "Almost there, {name}! Your dedication is extraordinary.",
    "{name}, you're proving that faithfulness matters!",
    "What a testimony, {name}! Keep pressing toward the goal.",
  ];

  // Final stretch messages (90%+) - Celebration and finish strong
  static const List<String> _finalStretchMessages = [
    "{name}, the finish line is so close! You can do this!",
    "Almost there, {name}! What an incredible achievement!",
    "{name}, {percent}% complete! You're nearly done!",
    "The home stretch, {name}! Finish strong!",
    "{name}, you've read so much of God's Word! Amazing!",
    "Just a little more, {name}! You're going to make it!",
    "{name}, your journey through Scripture is almost complete!",
    "What faithfulness, {name}! Keep going to the end!",
    "{name}, you're about to accomplish something incredible!",
    "So close, {name}! The crown awaits the faithful!",
  ];

  // Completion celebration messages
  static const List<String> _completionMessages = [
    "{name}, you did it! You've completed your reading plan!",
    "Congratulations, {name}! What an incredible accomplishment!",
    "{name}, you've read through the entire plan! God bless you!",
    "Amazing, {name}! You finished! Time to celebrate!",
    "{name}, your faithfulness has paid off! Well done!",
  ];

  /// Get an encouraging notification message based on progress
  static String getMessage({
    required String name,
    required int daysComplete,
    required int totalDays,
    required double percentComplete,
  }) {
    List<String> messagePool;

    if (percentComplete >= 100) {
      messagePool = _completionMessages;
    } else if (percentComplete >= 90) {
      messagePool = _finalStretchMessages;
    } else if (percentComplete >= 60) {
      messagePool = _strongProgressMessages;
    } else if (percentComplete >= 30) {
      messagePool = _establishedMessages;
    } else if (percentComplete >= 15) {
      messagePool = _buildingMessages;
    } else {
      messagePool = _earlyMessages;
    }

    final message = messagePool[_random.nextInt(messagePool.length)];

    return message
        .replaceAll('{name}', name)
        .replaceAll('{daysComplete}', daysComplete.toString())
        .replaceAll('{totalDays}', totalDays.toString())
        .replaceAll('{percent}', percentComplete.toStringAsFixed(0));
  }

  /// Get a simple title for the notification
  static String getTitle({required double percentComplete}) {
    if (percentComplete >= 100) {
      return '🎉 Congratulations!';
    } else if (percentComplete >= 90) {
      return '🏁 Almost There!';
    } else if (percentComplete >= 60) {
      return '⭐ Keep Going!';
    } else if (percentComplete >= 30) {
      return '📖 Daily Reading';
    } else {
      return '📖 Daily Reading';
    }
  }
}
