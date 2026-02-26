import 'package:flutter/material.dart';
import 'package:pos_app/screens/tables_screen/table_theme.dart';


enum TabView { floor, calendar, history }

// ═════════════════════════════════════════════════════════════
//  VIEW TOGGLE  (3 tabs)
// ═════════════════════════════════════════════════════════════
class ViewToggle extends StatelessWidget {
  final TabView current;
  final ValueChanged<TabView> onChanged;
  const ViewToggle({super.key, required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        height: 42,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: TC.surfaceWarm,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: TC.border),
        ),
        child: Row(
          children: [
            ToggleTab(
              label: 'Floor',
              icon: Icons.grid_view_rounded,
              selected: current == TabView.floor,
              onTap: () => onChanged(TabView.floor),
            ),
            ToggleTab(
              label: 'Calendar',
              icon: Icons.calendar_month_rounded,
              selected: current == TabView.calendar,
              onTap: () => onChanged(TabView.calendar),
            ),
            ToggleTab(
              label: 'History',
              icon: Icons.history_rounded,
              selected: current == TabView.history,
              onTap: () => onChanged(TabView.history),
            ),
          ],
        ),
      ),
    );
  }
}

class ToggleTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const ToggleTab({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: selected ? TC.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 8, offset: const Offset(0, 2))]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: selected ? TC.accent : TC.textMute),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? TC.accent : TC.textMute,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}