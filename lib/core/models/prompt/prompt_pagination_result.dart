import 'prompt_model.dart';

/// Represents the paginated result of prompt queries
class PromptPaginationResult {
  final bool hasNext;
  final int offset;
  final int limit;
  final int total;
  final List<PromptModel> items;

  PromptPaginationResult({
    required this.hasNext,
    required this.offset,
    required this.limit,
    required this.total,
    required this.items,
  });

  factory PromptPaginationResult.fromMap(Map<String, dynamic> map) {
    return PromptPaginationResult(
      hasNext: map['hasNext'] ?? false,
      offset: map['offset'] ?? 0,
      limit: map['limit'] ?? 20,
      total: map['total'] ?? 0,
      items: map['items'] != null
          ? List<PromptModel>.from(
              map['items'].map((item) => PromptModel.fromMap(item)))
          : [],
    );
  }

  /// Returns true if there are more pages available
  bool get hasMorePages => hasNext;

  /// Calculates the next offset for pagination
  int get nextOffset => offset + limit;

  /// Returns the current page number (1-based)
  int get currentPage => (offset ~/ limit) + 1;

  /// Calculates the total number of pages
  int get totalPages => (total / limit).ceil();
}
