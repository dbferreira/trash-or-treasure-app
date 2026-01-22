import 'package:flutter/material.dart';
import '../models.dart';
import 'package:url_launcher/url_launcher.dart';

class ResultCard extends StatelessWidget {
  final WorkflowResult result;

  const ResultCard({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 18,
                  color: theme.colorScheme.primary.withOpacity(0.5),
                ),
                _buildConfidenceBadge(context),
              ],
            ),
          ),
          ListTile(
            title: Text(result.item.name, style: theme.textTheme.titleMedium),
            subtitle: Text(result.item.description),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estimated Value',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.secondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatPrice(result.price.low)} — ${_formatPrice(result.price.high)}',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          if (result.sources.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Comparable Listings',
                style: theme.textTheme.labelMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Wrap(
                spacing: 8,
                children: result.sources.map((source) {
                  return ActionChip(
                    avatar: const Icon(Icons.link, size: 16),
                    label: Text(source.type),
                    onPressed: () async {
                      final url = Uri.parse(source.url);
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url);
                      }
                    },
                    labelStyle: theme.textTheme.labelSmall,
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatPrice(String price) {
    if (price.isEmpty) return r'$0';
    if (price.startsWith(r'$')) return price;
    return r'$' + price;
  }

  Widget _buildConfidenceBadge(BuildContext context) {
    final theme = Theme.of(context);
    final confidence = result.confidence;

    Color color;
    if (confidence >= 80) {
      color = Colors.green;
    } else if (confidence >= 60) {
      color = Colors.orange;
    } else {
      color = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        '$confidence% Match',
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
