import 'package:escala_trabalho/controller/sheet_provider.dart';
import 'package:escala_trabalho/helper/date_helper.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SelectMonthDialog extends StatefulWidget {
  const SelectMonthDialog({super.key});

  @override
  State<SelectMonthDialog> createState() => _SelectMonthDialogState();
}

class _SelectMonthDialogState extends State<SelectMonthDialog> {
  String _selectedOption = 'Janeiro';
  bool _oneMonthOnly = false;
  final List<String> _options = [
    'Janeiro',
    'Fevereiro',
    'Março',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro',
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Gerar escala a partir de qual mês?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButton<String>(
            isExpanded: true,
            value: _selectedOption,
            items: _options.map((String option) => DropdownMenuItem<String>(value: option, child: Text(option))).toList(),
            onChanged: (String? newValue) {
              setState(() => _selectedOption = newValue!);
            }
          ),
          InkWell(
            onTap: () => setState(() => _oneMonthOnly = !_oneMonthOnly),
            child: Row(
              children: [
                Checkbox(value: _oneMonthOnly, onChanged: (value) => setState(() => _oneMonthOnly = !_oneMonthOnly)),
                const Text('Gerar somente este mês')
              ],
            ),
          )
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            final sheetProvider = Provider.of<SheetProvider>(context, listen: false);
            int monthIndex = _options.indexOf(_selectedOption);
            if(_oneMonthOnly) {
              final key = monthMap.keys.firstWhere((e) => e == _selectedOption.toLowerCase());
              sheetProvider.monthsToGenerate.add({"mes": _selectedOption, "index": monthMap[key]});
            }else {
              for(var i = monthIndex; i < _options.length; i++) {
                final key = monthMap.keys.firstWhere((e) => e == _options[i].toLowerCase());
                sheetProvider.monthsToGenerate.add({"mes": _options[i], "index": monthMap[key]});
              }
            }
            Navigator.pop(context, true);
          },
          child: const Text('Gerar')
        ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.red)))
      ],
    );
  }
}
