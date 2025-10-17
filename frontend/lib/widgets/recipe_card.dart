import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../services/api_service.dart';

class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback? onTap;

  const RecipeCard({
    Key? key,
    required this.recipe,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final imageUrl = _resolveImageUrl(recipe.image);

    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(4),
      child: InkWell(
        onTap: onTap,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final mediaWidth = MediaQuery.of(context).size.shortestSide;
            final isHandset = mediaWidth < 600;
            const baseAspectRatio = 0.7;
            final additionalHeight = isHandset ? 20.0 : 0.0;
            const topFlex = 3;
            final bottomFlex = isHandset ? 3 : 2;

            final targetHeight = constraints.maxWidth / baseAspectRatio + additionalHeight;

            return SizedBox(
              height: targetHeight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: topFlex,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(color: Colors.grey[200]),
                          Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(child: CircularProgressIndicator());
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Icon(Icons.error_outline, color: Colors.grey),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: bottomFlex,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            recipe.name,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          if (recipe.tagsList.isNotEmpty) ...[
                            _RecipeTagList(tags: recipe.tagsList),
                            const SizedBox(height: 6),
                          ],
                          const Spacer(),
                          Row(
                            children: [
                              Icon(Icons.timer, size: 14, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  recipe.cookMinutes != null ? '${recipe.cookMinutes} mins' : 'N/A',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Colors.grey[600],
                                      ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.thumb_up, size: 14, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                '${recipe.likes} likes',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _resolveImageUrl(String image) {
    if (image.isEmpty) return image;
    if (!kIsWeb) return image;

    final encoded = Uri.encodeComponent(image);
    return '${ApiService.baseUrl}/image-proxy?url=$encoded';
  }
}

class _RecipeTagList extends StatelessWidget {
  const _RecipeTagList({required this.tags});

  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final baseStyle = theme.textTheme.labelSmall ??
        const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        );
    final textStyle = baseStyle.copyWith(
      color: baseStyle.color ?? Colors.grey.shade800,
      fontWeight: FontWeight.w500,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final boundedWidth = constraints.hasBoundedWidth && constraints.maxWidth.isFinite;
        final direction = Directionality.of(context);
        final mediaWidth = MediaQuery.of(context).size.shortestSide;
        final isHandset = mediaWidth < 600;
        final maxLines = isHandset ? 1 : 2;

        if (!boundedWidth) {
          return Wrap(
            spacing: _tagChipSpacing,
            runSpacing: _tagChipRunSpacing,
            children: tags
                .map(
                  (tag) => _RecipeTagChip(
                    label: tag,
                    textStyle: textStyle,
                  ),
                )
                .toList(),
          );
        }

        final chips = _computeVisibleChips(
          tags: tags,
          maxWidth: constraints.maxWidth,
          textStyle: textStyle,
          textDirection: direction,
          maxLines: maxLines,
        );

        return Wrap(
          spacing: _tagChipSpacing,
          runSpacing: maxLines > 1 ? _tagChipRunSpacing : 0,
          children: chips
              .map(
                (chip) => _RecipeTagChip(
                  label: chip.label,
                  textStyle: textStyle,
                  isEllipsis: chip.isEllipsis,
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _RecipeTagChip extends StatelessWidget {
  const _RecipeTagChip({
    required this.label,
    required this.textStyle,
    this.isEllipsis = false,
  });

  final String label;
  final TextStyle textStyle;
  final bool isEllipsis;

  @override
  Widget build(BuildContext context) {
    final background = isEllipsis ? Colors.grey.shade300 : Colors.grey.shade200;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: _tagChipHorizontalPadding,
        vertical: _tagChipVerticalPadding,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: textStyle,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

List<_TagChipData> _computeVisibleChips({
  required List<String> tags,
  required double maxWidth,
  required TextStyle textStyle,
  required TextDirection textDirection,
  required int maxLines,
}) {
  if (maxWidth <= 0) {
    return const [];
  }

  final painter = TextPainter(
    textDirection: textDirection,
    maxLines: 1,
  );

  final lines = <_TagLineData>[_TagLineData(spacing: _tagChipSpacing)];
  var overflowDetected = false;

  for (final rawTag in tags) {
    final label = rawTag.trim();
    if (label.isEmpty) continue;

    final chipWidth = _measureChipWidth(label, textStyle, painter);
    final chip = _TagChipData(label: label, width: chipWidth);
    final line = lines.last;
    final spacingToAdd = line.isEmpty ? 0 : _tagChipSpacing;

    if (line.width + spacingToAdd + chipWidth <= maxWidth || line.isEmpty) {
      line.addChip(chip);
    } else {
      if (lines.length == maxLines) {
        overflowDetected = true;
        break;
      }
      final newLine = _TagLineData(spacing: _tagChipSpacing);
      lines.add(newLine);
      newLine.addChip(chip);
    }
  }

  if (overflowDetected) {
    final ellipsisWidth = _measureChipWidth('...', textStyle, painter);
    final ellipsisChip = _TagChipData(label: '...', width: ellipsisWidth, isEllipsis: true);
    final targetLine = lines.last;

    var spacingToAdd = targetLine.isEmpty ? 0 : _tagChipSpacing;
    if (targetLine.width + spacingToAdd + ellipsisWidth <= maxWidth) {
      targetLine.addChip(ellipsisChip);
    } else {
      var ellipsisPlaced = false;
      while (targetLine.chips.isNotEmpty) {
        targetLine.removeLast();
        spacingToAdd = targetLine.isEmpty ? 0 : _tagChipSpacing;
        if (targetLine.width + spacingToAdd + ellipsisWidth <= maxWidth) {
          targetLine.addChip(ellipsisChip);
          ellipsisPlaced = true;
          break;
        }
      }
      if (!ellipsisPlaced) {
        targetLine.addChip(ellipsisChip);
      }
    }
  }

  return lines.expand((line) => line.chips).toList();
}

double _measureChipWidth(String label, TextStyle textStyle, TextPainter painter) {
  painter
    ..text = TextSpan(text: label, style: textStyle)
    ..layout(minWidth: 0, maxWidth: double.infinity);
  return painter.width + (_tagChipHorizontalPadding * 2);
}

class _TagChipData {
  _TagChipData({
    required this.label,
    required this.width,
    this.isEllipsis = false,
  });

  final String label;
  final double width;
  final bool isEllipsis;
}

class _TagLineData {
  _TagLineData({required this.spacing});

  final double spacing;
  final List<_TagChipData> chips = [];
  double width = 0;

  bool get isEmpty => chips.isEmpty;

  void addChip(_TagChipData chip) {
    if (chips.isNotEmpty) {
      width += spacing;
    }
    chips.add(chip);
    width += chip.width;
  }

  _TagChipData? removeLast() {
    if (chips.isEmpty) return null;
    final removed = chips.removeLast();
    width -= removed.width;
    if (chips.isNotEmpty) {
      width -= spacing;
    }
    return removed;
  }
}

const double _tagChipHorizontalPadding = 8.0;
const double _tagChipVerticalPadding = 4.0;
const double _tagChipSpacing = 6.0;
const double _tagChipRunSpacing = 6.0;
