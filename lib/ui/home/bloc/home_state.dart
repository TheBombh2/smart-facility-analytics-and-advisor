part of 'home_bloc.dart';

// home_state.dart (Modified)

@immutable
class HomeState {
  final FragmentType currentFragment;
  final TabType selectedTab; // <-- NEW

  const HomeState({
    required this.currentFragment,
    this.selectedTab = TabType.dataVisualizer, // Set initial tab
  });

  HomeState copyWith({
    FragmentType? currentFragment,
    TabType? selectedTab, // <-- NEW
  }) {
    return HomeState(
      currentFragment: currentFragment ?? this.currentFragment,
      selectedTab: selectedTab ?? this.selectedTab,
    );
  }
}