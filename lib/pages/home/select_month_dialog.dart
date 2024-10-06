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
  late final SheetProvider sheetProvider;
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
  void initState() {
    sheetProvider = Provider.of<SheetProvider>(context, listen: false);
    super.initState();
  }

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
            value: sheetProvider.selectedOption,
            items: _options.map((String option) => DropdownMenuItem<String>(value: option, child: Text(option))).toList(),
            onChanged: (String? newValue) {
              setState(() => sheetProvider.selectedOption = newValue!);
            }
          ),
          InkWell(
            onTap: () => setState(() => sheetProvider.oneMonthOnly = !sheetProvider.oneMonthOnly),
            child: Row(
              children: [
                Checkbox(value: sheetProvider.oneMonthOnly, onChanged: (value) => setState(() => sheetProvider.oneMonthOnly = !sheetProvider.oneMonthOnly)),
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
            int monthIndex = _options.indexOf(sheetProvider.selectedOption);
            if(sheetProvider.oneMonthOnly) {
              final key = monthsMap.keys.firstWhere((e) => e == sheetProvider.selectedOption.toLowerCase());
              sheetProvider.monthsToGenerate.add({"mes": sheetProvider.selectedOption, "index": monthsMap[key]});
            }else {
              for(var i = monthIndex; i < _options.length; i++) {
                final key = monthsMap.keys.firstWhere((e) => e == _options[i].toLowerCase());
                sheetProvider.monthsToGenerate.add({"mes": _options[i], "index": monthsMap[key]});
              }
            }
            Navigator.pop(context, true);
          },
          child: const Text('Gerar', style: TextStyle(color: Color.fromRGBO(60, 141, 188, 1)),)
        ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.red)))
      ],
    );
  }
}
