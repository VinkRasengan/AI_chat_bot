import 'package:flutter/material.dart';
import '../../core/constants/api_constants.dart';

class ModelSelectorWidget extends StatelessWidget {
  final String currentModel;
  final Function(String) onModelChanged;

  const ModelSelectorWidget({
    super.key,
    required this.currentModel,
    required this.onModelChanged,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.api),
      tooltip: 'Select AI Model',
      onPressed: () {
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) => _buildModelSelector(context),
        );
      },
    );
  }

  Widget _buildModelSelector(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Colors.grey.withAlpha(100),
                width: 1,
              ),
            ),
          ),
          child: const Text(
            'Select AI Model',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: ListView(
            children: ApiConstants.modelNames.entries.map((entry) {
              final modelId = entry.key;
              final modelName = entry.value;
              final isSelected = modelId == currentModel;

              return ListTile(
                leading: Icon(
                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                  color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
                ),
                title: Text(modelName),
                subtitle: Text(
                  _getModelDescription(modelId),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                selected: isSelected,
                onTap: () {
                  onModelChanged(modelId);
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  String _getModelDescription(String modelId) {
    switch (modelId) {
      case 'claude-3-5-sonnet-20240620':
        return 'Balanced reasoning and creative abilities';
      case 'gpt-4o':
        return 'Advanced capabilities with excellent reasoning';
      case 'gpt-4o-mini':
        return 'Fast and efficient general-purpose model';
      case 'gemini-1.5-flash-latest':
        return 'Quick responses with high efficiency';
      case 'gemini-1.5-pro-latest':
        return 'Advanced reasoning and problem-solving';
      case 'claude-3-haiku-20240307':
        return 'Fast and efficient for simple tasks';
      default:
        return 'AI Assistant model';
    }
  }
}
