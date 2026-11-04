class LocalUserProfile {
  final String username;
  final String bioTagline;
  final int avatarPresetIndex;
  final String? customAvatarFilePath;

  const LocalUserProfile({
    this.username = 'Fannz',
    this.bioTagline = 'Penikmat Musik Zunify 🎧',
    this.avatarPresetIndex = 0,
    this.customAvatarFilePath,
  });

  String get timeBasedGreeting {
    final hour = DateTime.now().hour;
    if (hour >= 4 && hour < 11) {
      return 'Selamat Pagi, $username ☀️';
    } else if (hour >= 11 && hour < 15) {
      return 'Selamat Siang, $username 🔥';
    } else if (hour >= 15 && hour < 19) {
      return 'Selamat Sore, $username 🌇';
    } else {
      return 'Selamat Malam, $username 🌙';
    }
  }

  LocalUserProfile copyWith({
    String? username,
    String? bioTagline,
    int? avatarPresetIndex,
    String? customAvatarFilePath,
  }) {
    return LocalUserProfile(
      username: username ?? this.username,
      bioTagline: bioTagline ?? this.bioTagline,
      avatarPresetIndex: avatarPresetIndex ?? this.avatarPresetIndex,
      customAvatarFilePath: customAvatarFilePath ?? this.customAvatarFilePath,
    );
  }

  Map<String, dynamic> toJson() => {
        'username': username,
        'bioTagline': bioTagline,
        'avatarPresetIndex': avatarPresetIndex,
        'customAvatarFilePath': customAvatarFilePath,
      };

  factory LocalUserProfile.fromJson(Map<String, dynamic> json) => LocalUserProfile(
        username: (json['username'] as String?)?.trim().isNotEmpty == true
            ? json['username'] as String
            : 'Fannz',
        bioTagline: json['bioTagline'] as String? ?? 'Penikmat Musik Zunify 🎧',
        avatarPresetIndex: (json['avatarPresetIndex'] as num?)?.toInt() ?? 0,
        customAvatarFilePath: json['customAvatarFilePath'] as String?,
      );
}
