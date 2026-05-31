import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bọc một `AsyncValue<List<T>>` với loading / error / empty / data.
class AsyncListView<T> extends StatelessWidget {
  final AsyncValue<List<T>> value;
  final Widget Function(T item) itemBuilder;
  final String emptyMessage;
  final Future<void> Function()? onRefresh;
  final EdgeInsets padding;

  const AsyncListView({
    super.key,
    required this.value,
    required this.itemBuilder,
    this.emptyMessage = 'Chưa có dữ liệu',
    this.onRefresh,
    this.padding = const EdgeInsets.all(12),
  });

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Lỗi: $e', textAlign: TextAlign.center),
        ),
      ),
      data: (items) {
        Widget list;
        if (items.isEmpty) {
          list = ListView(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 80),
                child: Center(child: Text(emptyMessage)),
              ),
            ],
          );
        } else {
          list = ListView.builder(
            padding: padding,
            itemCount: items.length,
            itemBuilder: (_, i) => itemBuilder(items[i]),
          );
        }
        if (onRefresh == null) return list;
        return RefreshIndicator(onRefresh: onRefresh!, child: list);
      },
    );
  }
}
