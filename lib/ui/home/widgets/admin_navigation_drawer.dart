import 'package:admin_app/ui/core/shared_widgets/navigation_item.dart';
import 'package:admin_app/ui/core/theme/theme.dart';
import 'package:admin_app/ui/home/bloc/home_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Helper to get a readable label for the FragmentType
String _getFragmentLabel(FragmentType type) {
  switch (type) {
    case FragmentType.energyConsumption:
      return 'Energy Consumption';
    case FragmentType.thermoComfortRating:
      return 'Thermocomfort Rating';
    case FragmentType.occupancyMapping:
      return 'Occupancy Mapping';
    case FragmentType.wearherData:
      return 'Weather Data';

      case FragmentType.analyticsHighlightFragment:
      return 'Analytics Highlight';

      case FragmentType.strategicAdvisorFragment:
      return "Stratigic Advisor";
      case FragmentType.reporterFragment:
      return "Reporter Fragment";
  }
}

class AdminNavigationDrawer extends StatelessWidget {
  const AdminNavigationDrawer({super.key});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250, // Slightly wider drawer
      color: Colors.grey.shade800,
      child: Column(
        children: [
          // Static Header Section
          Container(
            width: double.infinity,
            decoration: BoxDecoration(color: Colors.grey),
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'LOGOOO',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 20),
          
          // **Dynamic Navigation Items**
          Expanded(
            child: SingleChildScrollView(
              child: BlocBuilder<HomeBloc, HomeState>(
                builder: (context, state) {
                  // Get the fragments list based on the currently selected tab
                  final List<FragmentType> currentFragments = 
                      tabFragmentMap[state.selectedTab] ?? [];
                  
                  return Column(
                    children: currentFragments.map((fragmentType) {
                      return _buildNavigationItem(
                        context,
                        _getFragmentLabel(fragmentType),
                        fragmentType,
                        state.currentFragment, // Current selected fragment
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Updated _buildNavigationItem to use the currently selected fragment for highlighting
Widget _buildNavigationItem(
  BuildContext context,
  String label,
  FragmentType fragmentType,
  FragmentType currentSelectedFragment,
) {
  final bool isSelected = fragmentType == currentSelectedFragment;
  
  return NavigationItem(
    title: label,
    isSelected: isSelected, 
    onTap: () {
      context.read<HomeBloc>().add(SwitchFragment(fragmentType));
    },
  );
}