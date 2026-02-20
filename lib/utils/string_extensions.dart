
extension StringExtensions on String {
  String toTitleCase() {
    if (isEmpty) return this;
    
    // Split by space to handle multi-word strings
    return toLowerCase().split(' ').map((word) {
      if (word.isEmpty) return '';
      if (word.length == 1) return word.toUpperCase();
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }
}
