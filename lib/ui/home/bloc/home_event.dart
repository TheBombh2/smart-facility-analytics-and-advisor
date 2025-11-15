part of 'home_bloc.dart';

// Base class for all Home events

abstract class HomeEvent {}

class SwitchFragment extends HomeEvent{
  final FragmentType fragmentType;
  SwitchFragment(this.fragmentType);
}

// New event to switch the top-level tab
class SwitchTab extends HomeEvent {
  final TabType newTabType;
  SwitchTab(this.newTabType);
}