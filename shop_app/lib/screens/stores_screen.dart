import 'dart:async';

import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../widgets/common.dart';

class StoresScreen extends StatefulWidget {
  const StoresScreen({
    super.key,
    this.initialQuery,
    this.initialCategory,
    this.showBackButton = false,
  });

  final String? initialQuery;
  final String? initialCategory;
  final bool showBackButton;

  @override
  State<StoresScreen> createState() => _StoresScreenState();
}

class _StoresScreenState extends State<StoresScreen> {
  late final TextEditingController _search =
      TextEditingController(text: widget.initialQuery);
  late String? _category = widget.initialCategory;
  late Future<List<Store>> _stores = _load();
  Timer? _debounce;

  Future<List<Store>> _load() {
    return api.fetchStores(query: _search.text, category: _category);
  }

  void _reload() => setState(() => _stores = _load());

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), _reload);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: widget.showBackButton,
        title: const Text('Lojas'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onChanged: _onSearchChanged,
              onSubmitted: (_) => _reload(),
              decoration: const InputDecoration(
                hintText: 'Buscar loja ou produto',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(28)),
                ),
              ),
            ),
          ),
          if (_category != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 4),
                child: InputChip(
                  label: Text(_category!),
                  onDeleted: () {
                    _category = null;
                    _reload();
                  },
                ),
              ),
            ),
          Expanded(
            child: AsyncView<List<Store>>(
              future: _stores,
              onRetry: _reload,
              builder: (context, stores) {
                if (stores.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Nenhuma loja encontrada. Tente outra palavra ou pergunte ao assistente.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: stores.length,
                  itemBuilder: (context, index) => StoreTile(store: stores[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
