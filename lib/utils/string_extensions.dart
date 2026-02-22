
extension StringExtensions on String {
  String toTitleCase() {
    if (isEmpty) return this;
    
    // Replace underscores with spaces and split
    return replaceAll('_', ' ').toLowerCase().split(' ').map((word) {
      if (word.isEmpty) return '';
      if (word.length == 1) return word.toUpperCase();
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }
}
