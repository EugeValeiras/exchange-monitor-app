import 'package:flutter/material.dart';

import '../../core/theme/em_tokens.dart';
import '../../features/market/screens/market_screen.dart';
import '../../features/movements/screens/movements_screen.dart';
import '../../features/position/screens/position_screen.dart';
import '../../features/settings/screens/settings_screen.dart';

/// Cuatro destinos reales.
///
/// Antes eran Dashboard, Balances, Prices y Transactions: las dos primeras
/// mostraban la misma tarjeta y casi los mismos datos, y no había ningún lugar
/// para los ajustes. Al fusionarlas se libera la pestaña que faltaba.
class AppScaffold extends StatefulWidget {
  const AppScaffold({super.key});

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  int _index = 0;

  static const _tabs = <({IconData icon, String label})>[
    (icon: Icons.show_chart, label: 'Posición'),
    (icon: Icons.swap_horiz, label: 'Movimientos'),
    (icon: Icons.bar_chart, label: 'Mercado'),
    (icon: Icons.settings_outlined, label: 'Ajustes'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          PositionScreen(),
          MovementsScreen(),
          MarketScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: EmColors.bg,
          border: Border(top: BorderSide(color: EmColors.stroke)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: EmSpace.md,
              vertical: EmSpace.sm + 2,
            ),
            child: Row(
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _index = i),
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _tabs[i].icon,
                            size: 21,
                            color: i == _index
                                ? EmColors.textPrimary
                                : EmColors.textTertiary,
                          ),
                          const SizedBox(height: EmSpace.xs + 1),
                          Text(
                            _tabs[i].label,
                            style: EmText.meta.copyWith(
                              fontSize: 11,
                              fontWeight:
                                  i == _index ? FontWeight.w600 : FontWeight.w500,
                              color: i == _index
                                  ? EmColors.textPrimary
                                  : EmColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
