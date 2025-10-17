import 'package:flutter/material.dart';
import '../models/recipe.dart';

class RecipeWalkthroughScreen extends StatefulWidget {
  const RecipeWalkthroughScreen({required this.recipe, super.key});

  final Recipe recipe;

  @override
  State<RecipeWalkthroughScreen> createState() => _RecipeWalkthroughScreenState();
}

class _RecipeWalkthroughScreenState extends State<RecipeWalkthroughScreen> {
  late final PageController _controller;
  late final List<String> _steps;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _steps = widget.recipe.instructionsList;
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final steps = _steps;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.recipe.name} 步驟'),
      ),
      body: steps.isEmpty
          ? const Center(
              child: Text('目前沒有可顯示的步驟'),
            )
          : Column(
              children: [
                _StepIndicator(current: _currentPage, total: steps.length),
                const Divider(height: 1),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    scrollDirection: Axis.vertical,
                    onPageChanged: (page) {
                      setState(() {
                        _currentPage = page;
                      });
                    },
                    itemCount: steps.length,
                    itemBuilder: (context, index) {
                      final step = steps[index];
                      return Padding(
                        padding: const EdgeInsets.all(24),
                        child: Card(
                          elevation: 3,
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '步驟 ${index + 1}',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 12),
                                Expanded(
                                  child: SingleChildScrollView(
                                    child: Text(
                                      step,
                                      style: Theme.of(context).textTheme.bodyLarge,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      bottomNavigationBar: steps.isEmpty
          ? null
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: ElevatedButton(
                onPressed: () => _handleNext(context),
                child: Text(_currentPage == steps.length - 1 ? '完成' : '下一步'),
              ),
            ),
    );
  }

  void _handleNext(BuildContext context) {
    final steps = _steps;
    if (steps.isEmpty) return;

    if (_currentPage >= steps.length - 1) {
      Navigator.of(context).maybePop();
      return;
    }

    final nextPage = _currentPage + 1;
    _controller.animateToPage(
      nextPage,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    if (total <= 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '第 ${current + 1} / $total 步',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const Icon(Icons.swipe_up_alt_outlined),
        ],
      ),
    );
  }
}
