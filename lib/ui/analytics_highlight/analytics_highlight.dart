import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
class AnalyticsHighlightFragment extends StatelessWidget {
  const AnalyticsHighlightFragment({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Building Performance Dashboard'),
        backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Real-Time Energy & Comfort Metrics',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: constraints.maxWidth > 600 ? 2 : 1,
                  crossAxisSpacing: 16.0,
                  mainAxisSpacing: 16.0,
                  childAspectRatio: constraints.maxWidth > 600 ? 1.5 : 1.2,
                  children: const [
                    EnergyConsumptionCard(),
                    ThermocraftRatingCard(),
                    OccupancyCard(),
                    WeatherCard(),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// --- DATA ---

final List<FlSpot> energyData = [
  const FlSpot(0, 50),
  const FlSpot(1, 55),
  const FlSpot(2, 65),
  const FlSpot(3, 70),
  const FlSpot(4, 55),
  const FlSpot(5, 80),
  const FlSpot(6, 75),
  const FlSpot(7, 90),
];

final List<int> ratingDistribution = [5, 8, 12, 15, 10];

final List<FlSpot> occupancyData = [
  const FlSpot(0, 0),
  const FlSpot(4, 2),
  const FlSpot(8, 10),
  const FlSpot(12, 18),
  const FlSpot(16, 25),
  const FlSpot(20, 15),
  const FlSpot(24, 0),
];

class WeatherHourData {
  final int hour;
  final double tempC;
  final double humidity;
  WeatherHourData(this.hour, this.tempC, this.humidity);
}

final List<WeatherHourData> weatherData = [
  WeatherHourData(8, 15, 60),
  WeatherHourData(12, 22, 45),
  WeatherHourData(16, 25, 40),
  WeatherHourData(20, 18, 55),
];

// --- CARD WIDGETS ---

class EnergyConsumptionCard extends StatelessWidget {
  const EnergyConsumptionCard({super.key});

  @override
  Widget build(BuildContext context) {
    return _buildCard(
      title: 'Energy Consumption (kWh)',
      color: Colors.teal,
      chart: LineChart(
        LineChartData(
          gridData: FlGridData(show: true),
          titlesData: FlTitlesData(
            leftTitles:
                AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28)),
            bottomTitles:
                AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24)),
          ),
          borderData: FlBorderData(show: true),
          lineBarsData: [
            LineChartBarData(
              spots: energyData,
              isCurved: true,
              color: Colors.teal,
              barWidth: 3,
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [Colors.teal.withOpacity(0.4), Colors.transparent],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}

class ThermocraftRatingCard extends StatelessWidget {
  const ThermocraftRatingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return _buildCard(
      title: 'Thermocraft Comfort Rating (1–5 Stars)',
      color: Colors.orange,
      chart: BarChart(
        BarChartData(
          gridData: FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles:
                AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) =>
                    Text((value.toInt() + 1).toString()),
              ),
            ),
          ),
          barGroups: List.generate(ratingDistribution.length, (i) {
            final color = i == 4 ? Colors.green : Colors.orange;
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(toY: ratingDistribution[i].toDouble(), color: color)
              ],
            );
          }),
        ),
      ),
    );
  }
}

class OccupancyCard extends StatelessWidget {
  const OccupancyCard({super.key});

  @override
  Widget build(BuildContext context) {
    return _buildCard(
      title: 'Room Occupancy (People)',
      color: Colors.indigo,
      chart: LineChart(
        LineChartData(
          gridData: FlGridData(show: true),
          titlesData: FlTitlesData(show: true),
          borderData: FlBorderData(show: true),
          lineBarsData: [
            LineChartBarData(
              spots: occupancyData,
              isCurved: true,
              color: Colors.indigo,
              barWidth: 3,
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [Colors.indigo.withOpacity(0.3), Colors.transparent],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}

class WeatherCard extends StatelessWidget {
  const WeatherCard({super.key});

  @override
  Widget build(BuildContext context) {
    final groups = weatherData.map((e) {
      return BarChartGroupData(
        x: e.hour,
        barRods: [
          BarChartRodData(
              toY: e.tempC, color: Colors.blue, width: 8, borderRadius: BorderRadius.zero),
          BarChartRodData(
              toY: e.humidity / 3,
              color: Colors.lightBlueAccent,
              width: 8,
              borderRadius: BorderRadius.zero),
        ],
        barsSpace: 4,
      );
    }).toList();

    return _buildCard(
      title: 'External Weather Data',
      color: Colors.blue,
      chart: BarChart(
        BarChartData(
          gridData: FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(show: true),
          barGroups: groups,
        ),
      ),
    );
  }
}

// --- Helper ---

Widget _buildCard(
    {required String title,
    required Color color,
    required Widget chart}) {
  return Card(
    elevation: 4,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w600, color: color)),
          const SizedBox(height: 8),
          Expanded(child: chart),
        ],
      ),
    ),
  );
}
