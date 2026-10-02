import 'package:flutter/material.dart';

Future<bool> confirmCalculationReset(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空当前计算？'),
        content: const Text('已填写的条件和当前结果将被清空。已保存的历史记录与模板不受影响。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('继续编辑'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清空并新建'),
          ),
        ],
      ),
    ) ??
    false;
