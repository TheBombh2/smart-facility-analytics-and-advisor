import 'package:admin_app/ui/home/widgets/home_tab_type.dart';
import 'package:bloc/bloc.dart';
import 'package:meta/meta.dart';

part 'home_event.dart';
part 'home_state.dart';

// --- FragmentType Enum (Expanded) ---
enum FragmentType {
  // Data Visualizer
  energyConsumption,
  thermoComfortRating,
  occupancyMapping,
  wearherData,
  analyticsHighlightFragment,
  strategicAdvisorFragment,
  reporterFragment,
  
 
}

// Helper to map a Tab to its list of Fragments
Map<TabType, List<FragmentType>> tabFragmentMap = {
  TabType.dataVisualizer: [
    FragmentType.energyConsumption,
    FragmentType.thermoComfortRating,
    FragmentType.occupancyMapping,
    FragmentType.wearherData,
  ],
  TabType.analyticsHighlights: [
    FragmentType.analyticsHighlightFragment,
  ],
  TabType.strategicAdvisor: [
    FragmentType.strategicAdvisorFragment,
  ],
  TabType.reporter: [
    FragmentType.reporterFragment,
  ],
};

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc()
      : super(
          HomeState(
            currentFragment: FragmentType.energyConsumption,
            selectedTab: TabType.dataVisualizer,
          ),
        ) {
    
    // Handler for switching individual fragments/categories
    on<SwitchFragment>((event, emit) {
      // Only switch fragment if it belongs to the currently selected tab
      final currentFragments = tabFragmentMap[state.selectedTab];
      if (currentFragments != null && currentFragments.contains(event.fragmentType)) {
          emit(state.copyWith(currentFragment: event.fragmentType));
      } else {
        // Optional: log or handle unauthorized fragment switch
        print('Attempted to switch to fragment not in current tab: ${event.fragmentType.name}');
      }
    });

    // Handler for switching top-level tabs
    on<SwitchTab>((event, emit) {
      final newTabType = event.newTabType;
      
      // 1. Find the first fragment for the new tab (Critical logic)
      final firstFragmentOfNewTab = tabFragmentMap[newTabType]?.first;

      if (firstFragmentOfNewTab != null) {
        // 2. Emit a new state with the new tab AND its first fragment
        emit(state.copyWith(
          selectedTab: newTabType,
          currentFragment: firstFragmentOfNewTab,
        ));
      } else {
        print('Error: Selected tab ${newTabType.name} has no fragments defined.');
      }
    });
  }
}