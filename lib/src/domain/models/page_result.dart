/// 表示与具体上游分页协议无关的一页领域数据。
final class PageResult<T> {
  const PageResult({
    required this.items,
    required this.page,
    required this.hasMore,
  });

  final List<T> items;
  final int page;
  final bool hasMore;
}
