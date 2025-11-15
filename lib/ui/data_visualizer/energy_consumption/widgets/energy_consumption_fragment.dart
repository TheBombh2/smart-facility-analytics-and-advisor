import 'dart:math';
import 'package:admin_app/ui/core/theme/theme.dart';
import 'package:flutter/material.dart';

// --- NEW ENUM FOR METRIC SELECTION ---
enum EnergyMetric { 
  occupancy, 
  hvac, 
  lighting, 
  officeUtilities, 
  others 
}

// --- ENUM FOR FLOOR SELECTION (KEPT) ---
enum FloorType { ground, second }


// --- 1. Data Model and Utility Functions ---

// Represents a single defined zone on the floor plan, updated to handle multiple metrics
class ZoneData {
  final String id;
  final String name;
  // Coordinates are defined relative to a conceptual 1000x600 grid.
  final List<Offset> coordinates; 
  // Stores current load (occupancy count, W, etc.) for each metric
  final Map<EnergyMetric, double> currentLoad; 
  // Stores max capacity/load for each metric
  final Map<EnergyMetric, double> maxLoad; 

  ZoneData({
    required this.id,
    required this.name,
    required this.coordinates,
    required this.currentLoad,
    required this.maxLoad,
  });

  // Utility method to create a copy of the zone data with a new currentLoad map
  ZoneData copyWith({Map<EnergyMetric, double>? newLoad}) {
    return ZoneData(
      id: id,
      name: name,
      coordinates: coordinates,
      currentLoad: newLoad ?? currentLoad,
      maxLoad: maxLoad,
    );
  }


  // Calculate the occupancy/load ratio (0.0 to 1.0) for the selected metric
  double getRatio(EnergyMetric metric) {
    final current = currentLoad[metric] ?? 0.0;
    final max = maxLoad[metric] ?? 1.0;
    if (max == 0) return 0.0;
    return (current / max).clamp(0.0, 1.0);
  }

  // Get the display value for the selected metric
  String getDisplayValue(EnergyMetric metric) {
    final value = currentLoad[metric] ?? 0.0;
    
    switch (metric) {
      case EnergyMetric.occupancy:
        return value.toInt().toString(); // Occupancy as integer
      case EnergyMetric.hvac:
      case EnergyMetric.lighting:
      case EnergyMetric.officeUtilities:
      case EnergyMetric.others:
        // Format to one decimal place, or kW if large
        if (value >= 1000) {
          return '${(value / 1000).toStringAsFixed(1)} kW';
        }
        return value.toStringAsFixed(0);
      default:
        return 'N/A';
    }
  }
}

// Helper function to create the mock data maps for readability
Map<EnergyMetric, double> _load({
  required double occ,
  required double hvac,
  required double light,
  required double office,
  required double others,
}) => {
  EnergyMetric.occupancy: occ,
  EnergyMetric.hvac: hvac,
  EnergyMetric.lighting: light,
  EnergyMetric.officeUtilities: office,
  EnergyMetric.others: others,
};

// Data for Ground Floor 
final List<ZoneData> kGroundFloorZones = [
  ZoneData(
    id: 'G2',
    name: 'Meeting Room',
    coordinates: [
      const Offset(575, 110),
      const Offset(922, 110),
      const Offset(922, 255),
      const Offset(575, 255),
    ],
    currentLoad: _load(occ: 3, hvac: 1200, light: 450, office: 200, others: 100),
    maxLoad: _load(occ: 8, hvac: 2500, light: 600, office: 300, others: 200),
  ),
  ZoneData(
    id: 'G3',
    name: 'Lobby Area',
    coordinates: [
      const Offset(790, 260),
      const Offset(920, 260),
      const Offset(920, 490),
      const Offset(790, 490),
    ],
    currentLoad: _load(occ: 35, hvac: 18000, light: 5500, office: 800, others: 300),
    maxLoad: _load(occ: 50, hvac: 20000, light: 7000, office: 1000, others: 500),
  ),
  ZoneData(
    id: 'G4',
    name: 'Office Bay 1',
    coordinates: [
      const Offset(110, 110),
      const Offset(565, 110),
      const Offset(565, 255),

      const Offset(445, 190),

      const Offset(400, 225),


      const Offset(230, 225),
      const Offset(230, 490),
      const Offset(110, 490),
    ],
    currentLoad: _load(occ: 12, hvac: 7000, light: 2200, office: 4500, others: 200),
    maxLoad: _load(occ: 25, hvac: 10000, light: 3000, office: 6000, others: 500),
  ),
];

// Data for Second Floor (New Data)
final List<ZoneData> kSecondFloorZones = [
  ZoneData(
    id: 'S1',
    name: 'Co-Work Space A',
    coordinates: [
      const Offset(110, 140),
      const Offset(440, 140),
      const Offset(440, 300),
      const Offset(110, 300),
    ],
    currentLoad: _load(occ: 15, hvac: 8500, light: 1200, office: 3200, others: 400),
    maxLoad: _load(occ: 30, hvac: 10000, light: 1500, office: 4000, others: 500),
  ),
  ZoneData(
    id: 'S2',
    name: 'Co-Work Space B',
    coordinates: [
      const Offset(446, 140),
      const Offset(576, 140),
      const Offset(576, 300),
      const Offset(446, 300),
    ],
    currentLoad: _load(occ: 14, hvac: 5100, light: 750, office: 1800, others: 250),
    maxLoad: _load(occ: 30, hvac: 6000, light: 900, office: 2200, others: 300),
  ),
  ZoneData(
    id: 'S3',
    name: 'Focus Pods',
    coordinates: [
      const Offset(584, 140),
      const Offset(715, 140),
      const Offset(715, 300),
      const Offset(584, 300),
    ],
    currentLoad: _load(occ: 5, hvac: 3100, light: 500, office: 900, others: 150),
    maxLoad: _load(occ: 10, hvac: 4000, light: 600, office: 1000, others: 200),
  ),
  ZoneData(
    id: 'S4',
    name: 'Quiet Zone',
    coordinates: [
      const Offset(730, 140),
      const Offset(910, 140),
      const Offset(910, 300),
      const Offset(730, 300),
    ],
    currentLoad: _load(occ: 5, hvac: 2000, light: 400, office: 600, others: 50),
    maxLoad: _load(occ: 15, hvac: 3000, light: 500, office: 800, others: 100),
  ),
  ZoneData(
    id: 'S5',
    name: 'Server Rack',
    coordinates: [
      const Offset(770, 360),
      const Offset(910, 360),
      const Offset(910, 520),
      const Offset(770, 520),
    ],
    // Server Rack has high HVAC and Others (IT equipment) load
    currentLoad: _load(occ: 0, hvac: 15000, light: 50, office: 0, others: 12000),
    maxLoad: _load(occ: 0, hvac: 20000, light: 100, office: 0, others: 15000),
  ),
  ZoneData(
    id: 'S6', // Renamed from S5 (second instance)
    name: 'Pantry/Kitchen',
    coordinates: [
      const Offset(250, 455),
      const Offset(400, 455),
      const Offset(400, 546),
      const Offset(250, 546),
    ],
    // Pantry has high Office Utilities load (appliances)
    currentLoad: _load(occ: 5, hvac: 1000, light: 500, office: 5000, others: 100),
    maxLoad: _load(occ: 10, hvac: 1500, light: 600, office: 8000, others: 200),
  ),
  ZoneData(
    id: 'S7', // Renamed from S9
    name: 'Relaxation Zone',
    coordinates: [
      const Offset(110, 310),
      const Offset(250, 310),
      const Offset(250, 500),
      const Offset(110, 500),
    ],
    currentLoad: _load(occ: 8, hvac: 3000, light: 1000, office: 500, others: 100),
    maxLoad: _load(occ: 15, hvac: 5000, light: 1200, office: 600, others: 200),
  ),
];

// Map containing all floor data (image and zones)
// NOTE: We initialize floor data using a deep copy to ensure initial currentZones 
// can be updated without affecting kFloorPlans
final Map<FloorType, List<ZoneData>> kInitialFloorZones = {
  FloorType.ground: kGroundFloorZones.map((z) => z.copyWith()).toList(),
  FloorType.second: kSecondFloorZones.map((z) => z.copyWith()).toList(),
};

final Map<FloorType, Map<String, dynamic>> kFloorPlans = {
  
  FloorType.second: {
    'label': 'Second Floor',
    'imageUrl': 'assets/images/second_floor.jpeg',
    // Zones list will be handled by the state object
  },

  FloorType.ground: {
    'label': 'Ground Floor',
    'imageUrl': 'assets/images/ground_floor.jpeg',
    // Zones list will be handled by the state object
  },
};

// Helper to get a heat color based on occupancy ratio (no change)
Color getColorForRatio(double ratio) {
  final clampedRatio = ratio.clamp(0.0, 1.0);
  
  if (clampedRatio <= 0.5) {
    return Color.lerp(
      lemonGlow,
       amberBurst,
      clampedRatio * 2,
    )!;
  } else {
    return Color.lerp(
      goldenSun,
      honeyGold,
      (clampedRatio - 0.5) * 2,
    )!;
  }
}

// Helper to get the metric label/title
String getMetricLabel(EnergyMetric metric) {
  switch (metric) {
    case EnergyMetric.occupancy: return 'Occupancy';
    case EnergyMetric.hvac: return 'HVAC Load (W)';
    case EnergyMetric.lighting: return 'Lighting Load (W)';
    case EnergyMetric.officeUtilities: return 'Office Utilities Load (W)';
    case EnergyMetric.others: return 'Others Load (W)';
  }
}



// --- 2. The Custom Painter (Draws the Zones) ---

class FloorPlanPainter extends CustomPainter {
  final List<ZoneData> zones;
  final Size originalImageSize = const Size(1000, 600);
  final Size canvasSize;
  final EnergyMetric selectedMetric;

  FloorPlanPainter(this.zones, this.canvasSize, this.selectedMetric);

  @override
  void paint(Canvas canvas, Size size) {
    final double scaleX = size.width / originalImageSize.width;
    final double scaleY = size.height / originalImageSize.height;
    final double minScale = min(scaleX, scaleY);

    for (final zone in zones) {
      // Use the ratio for the selected metric
      final ratio = zone.getRatio(selectedMetric);
      final heatColor = getColorForRatio(ratio);

      // --- 1. Draw the Zone Shape (Polygon) ---
      final path = Path();
      
      final scaledCoordinates = zone.coordinates.map((offset) {
        return Offset(offset.dx * scaleX, offset.dy * scaleY);
      }).toList();

      if (scaledCoordinates.isNotEmpty) {
        path.moveTo(scaledCoordinates.first.dx, scaledCoordinates.first.dy);
        for (int i = 1; i < scaledCoordinates.length; i++) {
          path.lineTo(scaledCoordinates[i].dx, scaledCoordinates[i].dy);
        }
        path.close();
      }

      final paint = Paint()
        ..color = heatColor.withOpacity(0.6)
        ..style = PaintingStyle.fill;
      
      canvas.drawPath(path, paint);

      // --- 2. Draw the Border ---
      final borderPaint = Paint()
        ..color = heatColor.withOpacity(1.0)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      canvas.drawPath(path, borderPaint);

      // --- 3. Draw the Occupancy/Load Text ---
      if (scaledCoordinates.isNotEmpty) {
        final averageX = scaledCoordinates.map((o) => o.dx).reduce((a, b) => a + b) / scaledCoordinates.length;
        final averageY = scaledCoordinates.map((o) => o.dy).reduce((a, b) => a + b) / scaledCoordinates.length;
        
        // Use the display value for the selected metric
        final displayValue = zone.getDisplayValue(selectedMetric);

        final textStyle = TextStyle(
          color: Colors.white,
          fontSize: 20 * minScale, // Dynamically sized text
          fontWeight: FontWeight.bold,
          shadows: [
            const Shadow(blurRadius: 2, color: Colors.black, offset: Offset(1, 1)),
          ]
        );
        
        final textSpan = TextSpan(
          text: displayValue,
          style: textStyle,
        );
        
        final textPainter = TextPainter(
          text: textSpan,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        );
        
        textPainter.layout(minWidth: 0, maxWidth: size.width);
        
        final textOffset = Offset(
          averageX - textPainter.width / 2,
          averageY - textPainter.height / 2,
        );
        
        textPainter.paint(canvas, textOffset);
      }
    }
  }

  @override
  bool shouldRepaint(covariant FloorPlanPainter oldDelegate) {
    // Repaint if zones, canvas size, OR the selected metric changes
    return oldDelegate.zones != zones || 
           oldDelegate.canvasSize != canvasSize ||
           oldDelegate.selectedMetric != selectedMetric;
  }
}


// --- 3. The Main Screen (Integration) ---

class EnergyConsumptionFragment extends StatefulWidget {
  const EnergyConsumptionFragment({super.key});

  @override
  State<EnergyConsumptionFragment> createState() => _EnergyConsumptionFragmentState();
}

class _EnergyConsumptionFragmentState extends State<EnergyConsumptionFragment> {
  
  // SCROLL CONTROLLER & STATE FOR BACK-TO-TOP BUTTON
  late ScrollController _scrollController;
  bool _showBackToTopButton = false;
  
  // STATE VARIABLES
  FloorType selectedFloor = FloorType.ground;
  EnergyMetric selectedMetric = EnergyMetric.hvac; 
  // THIS LIST HOLDS THE CURRENT, UPDATABLE ZONE DATA
  late List<ZoneData> currentZones;

  @override
  void initState() {
    super.initState();
    // Initialize current zones from the static list (deep copy)
    currentZones = kInitialFloorZones[selectedFloor]!;

    // SCROLL LISTENER SETUP
    _scrollController = ScrollController()
      ..addListener(() {
        setState(() {
          // Show button if scroll position is past 400 pixels
          if (_scrollController.offset >= 400) {
            _showBackToTopButton = true;
          } else {
            _showBackToTopButton = false;
          }
        });
      });
  }
  
  @override
  void dispose() {
    _scrollController.dispose(); // Dispose the controller
    super.dispose();
  }

  // FUNCTION TO SCROLL TO TOP
  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  // --- Core Function to Update Zone Load ---
  // This is the function you would call whenever new data arrives.
  void _updateZoneLoad(String zoneId, EnergyMetric metricToUpdate, double newValue) {
    setState(() {
      // Find the index of the zone to update
      final index = currentZones.indexWhere((zone) => zone.id == zoneId);
      
      if (index != -1) {
        final oldZone = currentZones[index];
        // 1. Create a copy of the old currentLoad map
        final newLoadMap = Map<EnergyMetric, double>.from(oldZone.currentLoad);
        
        // 2. Update the specific metric value in the new map
        newLoadMap[metricToUpdate] = newValue;
        
        // 3. Create a new ZoneData object using copyWith and the new map
        final updatedZone = oldZone.copyWith(newLoad: newLoadMap);
        
        // 4. Replace the old zone object in the currentZones list
        currentZones[index] = updatedZone;
      }
    });
  }


  // --- Logic to switch floor plans ---
  void _switchFloor(FloorType newFloor) {
    setState(() {
      selectedFloor = newFloor;
      // When switching floor, load the initial zones for that floor (deep copy)
      currentZones = kInitialFloorZones[selectedFloor]!;
    });
  }

  // --- Logic to switch metric visualization ---
  void _switchMetric(EnergyMetric newMetric) {
    setState(() {
      selectedMetric = newMetric;
    });
  }

  // --- SIMULATION FUNCTION: Randomly updates HVAC load for all zones on current floor ---
  void _simulateHvacDataChange() {
    final Random random = Random();
    final metric = EnergyMetric.hvac;

    for (final zone in currentZones) {
      final maxLoad = zone.maxLoad[metric] ?? 10000;
      // Generate a new load value between 20% and 90% of maxLoad
      final minLoad = maxLoad * 0.2;
      final range = maxLoad * 0.7;
      
      final newLoad = minLoad + random.nextDouble() * range;
      
      // Call the core update function
      _updateZoneLoad(zone.id, metric, newLoad);
    }
  }


  @override
  Widget build(BuildContext context) {
    final floorData = kFloorPlans[selectedFloor]!;
    final imageUrl = floorData['imageUrl'] as String;
    final floorLabel = floorData['label'] as String;
    
    // Wrapped the ListView content in a Scaffold to use floatingActionButton
    return Scaffold(
      floatingActionButton: _showBackToTopButton
          ? FloatingActionButton(
              onPressed: _scrollToTop,
              backgroundColor: Colors.black,
              child: const Icon(Icons.arrow_upward, color: Colors.white),
            )
          : null,
      
      body: ListView(
        // Assign the scroll controller to the ListView
        controller: _scrollController,
        padding: const EdgeInsets.all(32.0),
        children: [
          // 1. Floor and Metric Selector
          _buildHeader(floorLabel, getMetricLabel(selectedMetric)),
          
          const SizedBox(height: 20),

          // 2. Heatmap Visualization Card
          _buildHeatmapCard(imageUrl),

          const SizedBox(height: 20),
          
          // 3. Energy Cards with "View on Map" buttons
          _buildHVACCard(),
          const SizedBox(height: 20),
          _buildLightingCard(),
          const SizedBox(height: 20),
          _buildOfficeUtilitiesCard(),
          const SizedBox(height: 20),
          _buildOthersCard(),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // New combined header for floor selection and current metric display
  Widget _buildHeader(String currentFloorLabel, String currentMetricLabel) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 1000),
      margin: const EdgeInsets.only(bottom: 10),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Current Floor: $currentFloorLabel', 
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  ToggleButtons(
                    isSelected: FloorType.values.map((e) => e == selectedFloor).toList(),
                    onPressed: (int index) {
                      _switchFloor(FloorType.values[index]);
                    },
                    borderRadius: BorderRadius.circular(8),
                    selectedColor: Colors.white,
                    fillColor: selectiveYellow,
                    color: textOnYellow,
                    borderWidth: 2,
                    borderColor: dodieYellow,
                    selectedBorderColor: dodieYellow,
                    children: FloorType.values.map((type) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Text(
                        kFloorPlans[type]!['label'] as String,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    )).toList(),
                  ),
                ],
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Text(
                    'Heatmap Displaying: ${currentMetricLabel}', 
                    style: TextStyle(fontSize: 16, color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                 
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }


  // Helper widget to display individual metrics (used in HVAC and Lighting cards)
  Widget _buildEnergyMetricItem({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String unit = '',
  }) {
    return Expanded(
      child: Card(
        color: color.withOpacity(0.1),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: color.withOpacity(0.5))),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(unit, style: const TextStyle(color: Colors.grey, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }

  // Combined card for HVAC Energy Metrics
  Widget _buildHVACCard() {
    final metric = EnergyMetric.hvac;
    final color = Colors.black;
    
    // Calculate total current HVAC load for display on the card
    final totalHvacLoad = currentZones.fold<double>(
      0.0, 
      (sum, zone) => sum + (zone.currentLoad[metric] ?? 0.0)
    ).toStringAsFixed(0);

    return Container(
      constraints: const BoxConstraints(maxWidth: 1000),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'HVAC Energy Consumption (W)',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color), 
                  ),
                  Row(
                    children: [
                      // NEW BUTTON TO SIMULATE DATA CHANGE
                      ElevatedButton.icon(
                        onPressed: _simulateHvacDataChange,
                        icon: const Icon(Icons.flash_on, size: 18, color: Colors.white),
                        label: const Text('Simulate Data Change', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () => _switchMetric(metric),
                        icon: Icon(Icons.map, size: 18, color: Colors.white),
                        label: const Text('View on Map', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 30),
              
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildEnergyMetricItem(
                    title: 'Current Total Power',
                    value: totalHvacLoad,
                    unit: 'W',
                    icon: Icons.ac_unit,
                    color: Colors.black,
                  ),
                  const SizedBox(width: 16),
                  _buildEnergyMetricItem(
                    title: '24h Peak Load',
                    value: '18,200',
                    unit: 'W',
                    icon: Icons.trending_up,
                    color: Colors.black,
                  ),
                 
                ],
              ),
              const SizedBox(height: 20),
            
            ],
          ),
        ),
      ),
    );
  }

  // Combined card for Lighting Energy Metrics
  Widget _buildLightingCard() {
    final metric = EnergyMetric.lighting;
    final color = Colors.black;
    
    // Calculate total current Lighting load for display on the card
    final totalLightingLoad = currentZones.fold<double>(
      0.0, 
      (sum, zone) => sum + (zone.currentLoad[metric] ?? 0.0)
    ).toStringAsFixed(0);


    return Container(
      constraints: const BoxConstraints(maxWidth: 1000),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Lighting Energy Consumption (W)',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color), 
                  ),
                  Row(
                    children: [
                       // ADDING SIMULATION BUTTON FOR LIGHTING TOO (Example: Zone S2 Lighting Update)
                      ElevatedButton.icon(
                        onPressed: () => _updateZoneLoad('S2', EnergyMetric.lighting, 50.0),
                        icon: const Icon(Icons.flash_on, size: 18, color: Colors.white),
                        label: const Text('Set S2 Light Low', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () => _switchMetric(metric),
                        icon: Icon(Icons.map, size: 18, color: Colors.white),
                        label: const Text('View on Map', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 30),
              
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildEnergyMetricItem(
                    title: 'Current Total Power',
                    value: totalLightingLoad,
                    unit: 'W',
                    icon: Icons.ac_unit,
                    color: Colors.black,
                  ),
                  const SizedBox(width: 16),
                  _buildEnergyMetricItem(
                    title: '24h Peak Load',
                    value: '18,200',
                    unit: 'W',
                    icon: Icons.trending_up,
                    color: Colors.black,
                  ),
                 
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfficeUtilitiesCard() {
    final metric = EnergyMetric.officeUtilities;
    final color = Colors.black;

    return Container(
      constraints: const BoxConstraints(maxWidth: 1000),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Office Utility Energy Consumption (W)',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color), 
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _switchMetric(metric),
                    icon: Icon(Icons.map, size: 18, color: Colors.white),
                    label: const Text('View on Map', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
                    ),
                  )
                ],
              ),
              const Divider(height: 30),
              
             Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildEnergyMetricItem(
                    title: 'Current Total Power',
                    value: "15123",
                    unit: 'W',
                    icon: Icons.ac_unit,
                    color: Colors.black,
                  ),
                  const SizedBox(width: 16),
                  _buildEnergyMetricItem(
                    title: '24h Peak Load',
                    value: '18,200',
                    unit: 'W',
                    icon: Icons.trending_up,
                    color: Colors.black,
                  ),
                 
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildOthersCard() {
    final metric = EnergyMetric.others;
    final color = Colors.black;
    
    return Container(
      constraints: const BoxConstraints(maxWidth: 1000),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Other Energy Consumption (W)',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color), 
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _switchMetric(metric),
                    icon: Icon(Icons.map, size: 18, color: Colors.white),
                    label: const Text('View on Map', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
                    ),
                  )
                ],
              ),
              const Divider(height: 30),
              
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildEnergyMetricItem(
                    title: 'Current Total Power',
                    value: "123123",
                    unit: 'W',
                    icon: Icons.ac_unit,
                    color: Colors.black,
                  ),
                  const SizedBox(width: 16),
                  _buildEnergyMetricItem(
                    title: '24h Peak Load',
                    value: '18,200',
                    unit: 'W',
                    icon: Icons.trending_up,
                    color: Colors.black,
                  ),
                 
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // Original floor selector and heatmap logic remains below:

  Widget _buildHeatmapCard(String imageUrl) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 1000),
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Current Metric Display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              color: Colors.black.withOpacity(0.1),
              child: Center(
                child: Text(
                  'Heatmap Visualization: ${getMetricLabel(selectedMetric)}',
                  style: TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold, 
                    color: Colors.black,
                  ),
                ),
              ),
            ),

            // Plan and Heatmap
            AspectRatio(
              aspectRatio: 1000 / 600,
              child: Stack(
                children: [
                  // 1. Background Image
                  Image.asset(
                    imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    key: ValueKey(imageUrl), 
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Text('Error loading floor plan image asset.', style: TextStyle(color: Colors.red)),
                    ),
                  ),

                  // 2. Dynamic Heatmap Overlay
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final actualCanvasSize = Size(constraints.maxWidth, constraints.maxHeight);
                      
                      return CustomPaint(
                        size: actualCanvasSize,
                        // PASS THE SELECTED METRIC TO THE PAINTER
                        painter: FloorPlanPainter(currentZones, actualCanvasSize, selectedMetric),
                      );
                    },
                  ),
                ],
              ),
            ),
            
            // Legend is placed inside the card for better grouping
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildHeatmapLegend(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeatmapLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Text(
          'Load Level:', 
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey.shade700)
        ),
        _legendItem(0.1, 'Low (<20%)', dodieYellow),
        _legendItem(0.5, 'Medium (~50%)', bananaYellow),
        _legendItem(0.9, 'High (>80%)', selectiveYellow),
      ],
    );
  }

  Widget _legendItem(double ratio, String label, Color baseColor) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: baseColor.withOpacity(0.6),
            border: Border.all(color: baseColor, width: 2),
            borderRadius: BorderRadius.circular(4)
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 14)),
      ],
    );
  }
}