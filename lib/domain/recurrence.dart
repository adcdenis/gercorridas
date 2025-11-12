enum Recurrence {
  none,
  weekly,
  monthly,
  yearly;

  static Recurrence fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'weekly':
        return Recurrence.weekly;
      case 'monthly':
        return Recurrence.monthly;
      case 'yearly':
        return Recurrence.yearly;
      default:
        return Recurrence.none;
    }
  }
}