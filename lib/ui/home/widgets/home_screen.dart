import 'package:admin_app/ui/analytics_highlight/analytics_highlight.dart';
import 'package:admin_app/ui/core/theme/theme.dart';
import 'package:admin_app/ui/home/bloc/home_bloc.dart';
import 'package:admin_app/ui/home/widgets/admin_navigation_drawer.dart';
import 'package:admin_app/ui/data_visualizer/energy_consumption/widgets/energy_consumption_fragment.dart';
import 'package:admin_app/ui/home/widgets/home_tab_type.dart';
import 'package:admin_app/ui/reporter/widgets/reporter.dart';
import 'package:admin_app/ui/startigic_advisor/widgets/stratigic_advisor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// Helper list for iteration
const List<TabType> availableTabs = [
  TabType.dataVisualizer,
  TabType.analyticsHighlights,
  TabType.strategicAdvisor,
  TabType.reporter
];

class _HomeScreenState extends State<HomeScreen> {
  // Helper to get the screen widget based on the FragmentType
  Widget _getFragmentWidget(FragmentType type) {
    switch (type) {
      case FragmentType.energyConsumption:
      case FragmentType.thermoComfortRating:
      case FragmentType.occupancyMapping:
      case FragmentType.wearherData:
        return (EnergyConsumptionFragment()); // Using ProfileFragment as a placeholder for all railway fragments

     case FragmentType.analyticsHighlightFragment:
     return AnalyticsHighlightFragment();

     case FragmentType.strategicAdvisorFragment:
     return StrategicAdvisorFragment();

     case FragmentType.reporterFragment:
     return GHGReporterFragment();
      

      default:
        return Center(
          child: Text(
            'Content for ${type.name} Not Implemented',
            style: TextStyle(fontSize: 24, color: Colors.red),
          ),
        );
    }
  }

  // Helper to get a readable label for the TabType
  String _getTabLabel(TabType type) {
    switch (type) {
      case TabType.dataVisualizer:
        return 'Data Visualizer';
      case TabType.analyticsHighlights:
        return 'Analytics Highlights';
      case TabType.strategicAdvisor:
        return 'Strategic Advisor';
      case TabType.reporter:
        return 'Reporter';
    }
  }

  Widget _buildTabButton(
    BuildContext context,
    TabType tabType,
    TabType currentSelectedTab,
  ) {
    final bool isSelected = tabType == currentSelectedTab;

    return TextButton(
      onPressed: () {
        // Dispatch the event to switch the tab. The BLoC logic
        // handles selecting the first fragment of the new tab automatically.
        context.read<HomeBloc>().add(SwitchTab(tabType));
      },
      child: Text(
        _getTabLabel(tabType),
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
          fontSize: 18,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
         
         
          decorationThickness: 2.0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: deepLemon,
      body: Row(
        children: [
          const AdminNavigationDrawer(),
          Expanded(
            child: Column(
              children: [
                // **Header/Tabs Section**
                BlocBuilder<HomeBloc, HomeState>(
                  builder: (context, state) {
                    return Container(
                      width: double.infinity,
                      decoration: BoxDecoration(color: Colors.grey.shade800,),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: availableTabs.map((tabType) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 24.0),
                            child: _buildTabButton(
                              context,
                              tabType,
                              state.selectedTab,
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
                // **Scrollable content section (Fragment)**
                Expanded(
                  // Use Expanded to ensure the fragment takes remaining space
                  child: BlocBuilder<HomeBloc, HomeState>(
                    builder: (context, state) {
                      return _getFragmentWidget(state.currentFragment);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
