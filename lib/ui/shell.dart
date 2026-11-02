import 'package:flutter/material.dart';

import '../config.dart';
import '../state.dart';
import '../theme.dart';
import 'attendance_page.dart';
import 'common.dart';
import 'settings_page.dart';
import 'workers_page.dart';

/// Main window: sidebar on the left, current page on the right.
class Shell extends StatefulWidget {
  const Shell({super.key, required this.state});

  final AppState state;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = 0;

  Widget _page() {
    switch (_index) {
      case 0:
        return AttendancePage(
          state: widget.state,
          onGoWorkers: () => setState(() => _index = 1),
        );
      case 1:
        return WorkersPage(state: widget.state);
      default:
        return SettingsPage(state: widget.state);
    }
  }

  @override
  Widget build(BuildContext context) {
    final company = widget.state.companyName;
    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 232,
            decoration: const BoxDecoration(
              color: kPanel,
              border: Border(right: BorderSide(color: kBorder)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                  child: Row(
                    children: [
                      const MusterLogo(size: 34),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              kAppName,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: kNavy,
                              ),
                            ),
                            Text(
                              company.isEmpty ? 'Your company' : company,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: kSubtle,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                _NavItem(
                  icon: Icons.fact_check_outlined,
                  label: 'Attendance',
                  selected: _index == 0,
                  onTap: () => setState(() => _index = 0),
                ),
                _NavItem(
                  icon: Icons.groups_outlined,
                  label: 'Workers',
                  selected: _index == 1,
                  onTap: () => setState(() => _index = 1),
                ),
                const _NavItem(
                  icon: Icons.payments_outlined,
                  label: 'Salary',
                  selected: false,
                  soon: true,
                ),
                const _NavItem(
                  icon: Icons.request_quote_outlined,
                  label: 'Advances',
                  selected: false,
                  soon: true,
                ),
                const _NavItem(
                  icon: Icons.summarize_outlined,
                  label: 'Reports',
                  selected: false,
                  soon: true,
                ),
                const Spacer(),
                const Divider(height: 1, color: kBorder),
                const SizedBox(height: 6),
                _NavItem(
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  selected: _index == 2,
                  onTap: () => setState(() => _index = 2),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
          Expanded(child: _page()),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    this.onTap,
    this.soon = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool soon;

  @override
  Widget build(BuildContext context) {
    final color = soon ? const Color(0xFF9A9A9A) : (selected ? kNavy : kInk);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Material(
        color: selected ? kNavySoft : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: soon ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 16,
                  decoration: BoxDecoration(
                    color: selected ? kAmber : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 9),
                Icon(icon, size: 19, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                if (soon)
                  const Pill(
                    text: 'Soon',
                    color: kMuted,
                    background: kGreySoft,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
