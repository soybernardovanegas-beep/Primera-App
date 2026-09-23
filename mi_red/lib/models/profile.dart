class Profile {
  const Profile({
    this.displayName = '',
    this.myWhy = '',
    this.idealGoal = 20,
  });

  factory Profile.fromRow(Map<String, dynamic>? row) {
    if (row == null) return const Profile();
    return Profile(
      displayName: row['display_name'] as String? ?? '',
      myWhy: row['my_why'] as String? ?? '',
      idealGoal: (row['ideal_goal'] as num?)?.toInt() ?? 20,
    );
  }

  final String displayName;
  final String myWhy;
  final int idealGoal;

  Map<String, dynamic> toRow() => {
        'display_name': displayName,
        'my_why': myWhy,
        'ideal_goal': idealGoal,
      };
}
