/// Result of a fuzzy match operation
class FuzzyMatchResult {
  final String? matchedValue;
  final double matchScore; // 0.0 to 1.0, where 1.0 is exact match
  final String matchType; // 'exact', 'case_insensitive', 'fuzzy', 'partial'
  final String? reason;

  FuzzyMatchResult({
    required this.matchedValue,
    required this.matchScore,
    required this.matchType,
    this.reason,
  });

  bool get isMatch => matchScore >= 0.6; // 60% similarity threshold
  bool get isStrongMatch =>
      matchScore >= 0.8; // 80% similarity threshold (fuzzy)

  @override
  String toString() =>
      'Match: $matchedValue (score: ${(matchScore * 100).toStringAsFixed(1)}%, type: $matchType)';
}

/// Service to provide fuzzy matching capabilities for strings
/// Supports: exact matching, case-insensitive matching, partial matching, and fuzzy matching
class FuzzyMatchingService {
  static const double _exactMatchScore = 1.0;
  static const double _caseInsensitiveMatchScore = 0.95;
  static const double _partialMatchThreshold = 0.6;
  static const double _fuzzyMatchThreshold = 0.6;

  /// Finds the best match for an input string from a list of candidates
  ///
  /// Strategy:
  /// 1. Exact match (score: 1.0)
  /// 2. Case-insensitive exact match (score: 0.95)
  /// 3. Partial/short name match (score: 0.7-0.9)
  /// 4. Fuzzy match using Levenshtein distance (score: 0.6+)
  /// 5. No match (score: 0.0)
  ///
  /// Parameters:
  ///   - input: The input string to match
  ///   - candidates: List of candidate strings to match against
  ///   - caseSensitive: Whether to perform exact case-sensitive matching first
  ///
  /// Returns:
  ///   - FuzzyMatchResult with the best match or null if no candidates match threshold
  static FuzzyMatchResult? findBestMatch({
    required String input,
    required List<String> candidates,
    bool caseSensitive = false,
  }) {
    if (input.trim().isEmpty || candidates.isEmpty) {
      return null;
    }

    final trimmedInput = input.trim();
    FuzzyMatchResult? bestMatch;

    for (final candidate in candidates) {
      final trimmedCandidate = candidate.trim();

      // 1. Exact match (case-sensitive)
      if (caseSensitive && trimmedInput == trimmedCandidate) {
        return FuzzyMatchResult(
          matchedValue: trimmedCandidate,
          matchScore: _exactMatchScore,
          matchType: 'exact',
          reason: 'Exact match',
        );
      }

      // 2. Case-insensitive exact match
      if (trimmedInput.toLowerCase() == trimmedCandidate.toLowerCase()) {
        if (bestMatch == null ||
            bestMatch.matchScore < _caseInsensitiveMatchScore) {
          bestMatch = FuzzyMatchResult(
            matchedValue: trimmedCandidate,
            matchScore: _caseInsensitiveMatchScore,
            matchType: 'case_insensitive',
            reason: 'Case-insensitive exact match',
          );
        }
        continue;
      }

      // 3. Partial/short name match
      final partialMatch = _checkPartialMatch(trimmedInput, trimmedCandidate);
      if (partialMatch != null) {
        if (bestMatch == null ||
            bestMatch.matchScore < partialMatch.matchScore) {
          bestMatch = partialMatch;
        }
        continue;
      }

      // 4. Fuzzy match using Levenshtein distance
      final fuzzyScore = _levenshteinSimilarity(trimmedInput, trimmedCandidate);
      if (fuzzyScore >= _fuzzyMatchThreshold) {
        if (bestMatch == null || bestMatch.matchScore < fuzzyScore) {
          bestMatch = FuzzyMatchResult(
            matchedValue: trimmedCandidate,
            matchScore: fuzzyScore,
            matchType: 'fuzzy',
            reason:
                'Fuzzy match (${(fuzzyScore * 100).toStringAsFixed(1)}% similar)',
          );
        }
      }
    }

    return bestMatch;
  }

  /// Finds all matching candidates sorted by match score (descending)
  ///
  /// Returns a list of FuzzyMatchResult sorted by score (best matches first)
  static List<FuzzyMatchResult> findAllMatches({
    required String input,
    required List<String> candidates,
    double minScore = 0.5,
  }) {
    if (input.trim().isEmpty || candidates.isEmpty) {
      return [];
    }

    final trimmedInput = input.trim();
    final results = <FuzzyMatchResult>[];

    for (final candidate in candidates) {
      final trimmedCandidate = candidate.trim();

      // Check exact match
      if (trimmedInput == trimmedCandidate) {
        results.add(
          FuzzyMatchResult(
            matchedValue: trimmedCandidate,
            matchScore: _exactMatchScore,
            matchType: 'exact',
            reason: 'Exact match',
          ),
        );
        continue;
      }

      // Check case-insensitive exact match
      if (trimmedInput.toLowerCase() == trimmedCandidate.toLowerCase()) {
        results.add(
          FuzzyMatchResult(
            matchedValue: trimmedCandidate,
            matchScore: _caseInsensitiveMatchScore,
            matchType: 'case_insensitive',
            reason: 'Case-insensitive exact match',
          ),
        );
        continue;
      }

      // Check partial match
      final partialMatch = _checkPartialMatch(trimmedInput, trimmedCandidate);
      if (partialMatch != null && partialMatch.matchScore >= minScore) {
        results.add(partialMatch);
        continue;
      }

      // Check fuzzy match
      final fuzzyScore = _levenshteinSimilarity(trimmedInput, trimmedCandidate);
      if (fuzzyScore >= minScore) {
        results.add(
          FuzzyMatchResult(
            matchedValue: trimmedCandidate,
            matchScore: fuzzyScore,
            matchType: 'fuzzy',
            reason:
                'Fuzzy match (${(fuzzyScore * 100).toStringAsFixed(1)}% similar)',
          ),
        );
      }
    }

    // Sort by score descending
    results.sort((a, b) => b.matchScore.compareTo(a.matchScore));

    return results;
  }

  /// Checks for partial/short name matches
  /// E.g., "Veg" matches "Vegetables", "Dairy" matches "DairyProducts"
  static FuzzyMatchResult? _checkPartialMatch(String input, String candidate) {
    final inputLower = input.toLowerCase();
    final candidateLower = candidate.toLowerCase();

    // Exact substring match
    if (candidateLower.contains(inputLower)) {
      final score = inputLower.length / candidateLower.length;
      if (score >= _partialMatchThreshold) {
        return FuzzyMatchResult(
          matchedValue: candidate,
          matchScore: score,
          matchType: 'partial',
          reason: 'Partial match: "$input" is substring of "$candidate"',
        );
      }
    }

    // Reverse: candidate is substring of input
    if (inputLower.contains(candidateLower)) {
      final score = candidateLower.length / inputLower.length;
      if (score >= _partialMatchThreshold) {
        return FuzzyMatchResult(
          matchedValue: candidate,
          matchScore: score,
          matchType: 'partial',
          reason: 'Partial match: "$candidate" is substring of "$input"',
        );
      }
    }

    // Check for acronyms or first letter matches
    // E.g., "OP" matches "Olive Oil"
    final acronym = _extractAcronym(input);
    if (acronym.isNotEmpty && candidateLower.startsWith(acronym)) {
      return FuzzyMatchResult(
        matchedValue: candidate,
        matchScore: 0.75,
        matchType: 'partial',
        reason: 'Acronym match: "$input" matches "$candidate"',
      );
    }

    return null;
  }

  /// Extracts acronym from input (first letters of words)
  static String _extractAcronym(String input) {
    final words = input.split(RegExp(r'[\s\-_]+'));
    return words.map((w) => w.isEmpty ? '' : w[0]).join('').toLowerCase();
  }

  /// Calculates Levenshtein similarity between two strings
  /// Returns a value between 0.0 (completely different) and 1.0 (identical)
  static double _levenshteinSimilarity(String s1, String s2) {
    final distance = _levenshteinDistance(s1.toLowerCase(), s2.toLowerCase());
    final maxLength = (s1.length > s2.length) ? s1.length : s2.length;
    if (maxLength == 0) return 1.0;
    return 1.0 - (distance / maxLength);
  }

  /// Calculates Levenshtein distance between two strings
  /// This is the minimum number of edits needed to transform one string into another
  static int _levenshteinDistance(String s1, String s2) {
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    final matrix = List<List<int>>.generate(
      s2.length + 1,
      (i) => List<int>.generate(s1.length + 1, (j) => 0),
    );

    // Initialize first column and row
    for (int i = 0; i <= s2.length; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= s1.length; j++) {
      matrix[0][j] = j;
    }

    // Calculate distances
    for (int i = 1; i <= s2.length; i++) {
      for (int j = 1; j <= s1.length; j++) {
        final cost = s2[i - 1] == s1[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1, // deletion
          matrix[i][j - 1] + 1, // insertion
          matrix[i - 1][j - 1] + cost, // substitution
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return matrix[s2.length][s1.length];
  }
}
