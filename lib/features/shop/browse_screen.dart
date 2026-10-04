import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/widgets.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import 'providers.dart';

enum _Sort { featured, newest, priceLow, priceHigh }

const _sections = [('', 'All'), ('women', 'Women'), ('men', 'Men'), ('accessories', 'Accessories')];

/// The catalogue, filtered on the phone: section, category, search, sort, sale and new.
class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key, this.section = '', this.category = '', this.onlyNew = false});

  final String section;
  final String category;
  final bool onlyNew;

  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  late String _section = widget.section;
  late String _category = widget.category;
  late bool _onlyNew = widget.onlyNew;
  bool _onSale = false;
  _Sort _sort = _Sort.featured;
  String _query = '';

  @override
  void didUpdateWidget(BrowseScreen old) {
    super.didUpdateWidget(old);
    // Links from the home tab land here with new filters
    if (old.section != widget.section || old.category != widget.category || old.onlyNew != widget.onlyNew) {
      setState(() {
        _section = widget.section;
        _category = widget.category;
        _onlyNew = widget.onlyNew;
      });
    }
  }

  List<Product> _filter(List<Product> all) {
    final q = _query.trim().toLowerCase();
    final list = all.where((p) {
      if (_section.isNotEmpty && !p.inSection(_section)) return false;
      if (_category.isNotEmpty && p.category != _category) return false;
      if (_onlyNew && !p.isNew) return false;
      if (_onSale && !p.onSale) return false;
      if (q.isNotEmpty && !p.name.toLowerCase().contains(q) && !p.categoryName.toLowerCase().contains(q)) return false;
      return true;
    }).toList();
    switch (_sort) {
      case _Sort.featured:
        list.sort((a, b) => b.popularity.compareTo(a.popularity));
      case _Sort.newest:
        list.sort((a, b) => (b.isNew ? 1 : 0).compareTo(a.isNew ? 1 : 0));
      case _Sort.priceLow:
        list.sort((a, b) => a.price.compareTo(b.price));
      case _Sort.priceHigh:
        list.sort((a, b) => b.price.compareTo(a.price));
    }
    return list;
  }

  Future<void> _openFilters() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) {
          void update(VoidCallback f) {
            setState(f);
            setSheet(() {});
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sort and filter', style: display(30)),
                  const SizedBox(height: 16),
                  const Eyebrow('Sort by'),
                  RadioGroup<_Sort>(
                    groupValue: _sort,
                    onChanged: (v) => update(() => _sort = v!),
                    child: Column(
                      children: [
                        for (final (s, label) in [
                          (_Sort.featured, 'Featured'),
                          (_Sort.newest, 'Newest'),
                          (_Sort.priceLow, 'Price, low to high'),
                          (_Sort.priceHigh, 'Price, high to low'),
                        ])
                          RadioListTile<_Sort>(value: s, title: Text(label), contentPadding: EdgeInsets.zero, dense: true),
                      ],
                    ),
                  ),
                  const Divider(height: 24),
                  SwitchListTile(value: _onlyNew, onChanged: (v) => update(() => _onlyNew = v), title: const Text('New in only'), contentPadding: EdgeInsets.zero),
                  SwitchListTile(value: _onSale, onChanged: (v) => update(() => _onSale = v), title: const Text('On sale only'), contentPadding: EdgeInsets.zero),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: () => Navigator.pop(context), child: const Text('SHOW PIECES')),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider);
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];
    final filtersOn = (_onlyNew ? 1 : 0) + (_onSale ? 1 : 0) + (_sort != _Sort.featured ? 1 : 0);

    return Scaffold(
      appBar: AppBar(title: const Text('Shop')),
      body: AsyncBody(
        value: products,
        onRetry: () => ref.invalidate(productsProvider),
        builder: (all) {
          // Only categories with something in the chosen section
          final used = categories.where((c) => all.any((p) => p.category == c.slug && (_section.isEmpty || p.inSection(_section)))).toList();
          final list = _filter(all);
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      child: TextField(
                        decoration: const InputDecoration(hintText: 'Search the collection', prefixIcon: Icon(Icons.search, size: 20), isDense: true),
                        onChanged: (v) => setState(() => _query = v),
                        textInputAction: TextInputAction.search,
                      ),
                    ),
                    SizedBox(
                      height: 48,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        children: [
                          for (final (key, label) in _sections)
                            TextButton(
                              onPressed: () => setState(() {
                                _section = key;
                                _category = '';
                              }),
                              child: Container(
                                padding: const EdgeInsets.only(bottom: 4),
                                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _section == key ? AppColors.ink : Colors.transparent))),
                                child: Text(label.toUpperCase(), style: eyebrow(color: _section == key ? AppColors.ink : AppColors.muted)),
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 44,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          _Chip('Everything', selected: _category.isEmpty, onTap: () => setState(() => _category = '')),
                          for (final c in used) _Chip(c.name, selected: _category == c.slug, onTap: () => setState(() => _category = c.slug)),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 6, 0),
                      child: Row(
                        children: [
                          Expanded(child: Text('${list.length} ${list.length == 1 ? 'piece' : 'pieces'}', style: const TextStyle(color: AppColors.muted, fontSize: 13))),
                          TextButton.icon(
                            onPressed: _openFilters,
                            icon: const Icon(Icons.tune, size: 18),
                            label: Text(filtersOn > 0 ? 'Filter ($filtersOn)' : 'Filter'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (list.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Message(
                    icon: Icons.search_off,
                    text: 'Nothing matches these filters.',
                    action: OutlinedButton(
                      onPressed: () => setState(() {
                        _category = '';
                        _onlyNew = false;
                        _onSale = false;
                        _query = '';
                      }),
                      child: const Text('CLEAR FILTERS'),
                    ),
                  ),
                )
              else
                ProductGrid(list),
            ],
          );
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, {required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6, top: 4, bottom: 4),
      child: ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap(), showCheckmark: false),
    );
  }
}
