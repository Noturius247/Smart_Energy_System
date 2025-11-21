import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../realtime_db_service.dart';
import '../theme_provider.dart';
import 'energy_chart.dart';

class EnergyOverviewScreen extends StatefulWidget {
  final RealtimeDbService realtimeDbService;

  const EnergyOverviewScreen({super.key, required this.realtimeDbService});

  @override
  State<EnergyOverviewScreen> createState() => _EnergyOverviewScreenState();
}

class _EnergyOverviewScreenState extends State<EnergyOverviewScreen> {
  // All the methods and state previously in _HomeScreenState related to the content
  // of the "Energy" tab will go here.

  // NOTE: _realtimeDbService is passed via widget.realtimeDbService

  Widget _currentEnergyCard() {
    final now = DateTime.now();
    final formattedDate = DateFormat(
      'EEEE, MMMM d, yyyy - hh:mm a',
    ).format(now);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Theme.of(context).cardColor, Theme.of(context).primaryColor],
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Energy Usage',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  formattedDate,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                Text(
                  '24.8 kWh',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '+2.5% less than yesterday',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 50,
                width: 50,
                child: CircularProgressIndicator(
                  value: 0.7,
                  color: Theme.of(context).colorScheme.secondary,
                  backgroundColor: Theme.of(
                    context,
                  ).primaryColor.withAlpha((255 * 0.2).round()),
                  strokeWidth: 5,
                ),
              ),
              Text(
                '70%',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _solarProductionCard() {
    return Container(
      width: 110,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Theme.of(context).cardColor, Theme.of(context).primaryColor],
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly Consumption',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            '8.2 kWh',
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.secondary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          LinearProgressIndicator(
            value: 0.7,
            backgroundColor: Theme.of(
              context,
            ).primaryColor.withAlpha((255 * 0.2).round()),
            color: Theme.of(context).colorScheme.secondary,
            minHeight: 5,
          ),
          const SizedBox(height: 3),
          Text(
            'Consume hours: 5.2 hrs',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _energyConsumptionChart() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Theme.of(context).cardColor, Theme.of(context).primaryColor],
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Energy Consumption",
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const EnergyChart(),
        ],
      ),
    );
  }

  Widget _tipTile(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.secondary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _energyTipsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Smart Energy Tips',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        _tipTile(
          Icons.battery_charging_full,
          'Unplug Chargers',
          'Unplug devices once fully charged to avoid phantom load.',
        ),
        const SizedBox(height: 6),
        _tipTile(
          Icons.ac_unit,
          'Efficient AC Use',
          'Set air conditioners between 24–25°C for efficiency.',
        ),
        const SizedBox(height: 6),
        _tipTile(
          Icons.lightbulb,
          'Switch to LED',
          'LED bulbs use up to 80% less energy than incandescent bulbs.',
        ),
        const SizedBox(height: 6),
        _tipTile(
          Icons.local_laundry_service,
          'Run Full Loads',
          'Washers and dishwashers are most efficient when fully loaded.',
        ),
        const SizedBox(height: 6),
        _tipTile(
          Icons.power,
          'Use Smart Plugs',
          'Monitor and control appliances remotely with smart plugs.',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _currentEnergyCard()),
              const SizedBox(width: 10),
              _solarProductionCard(),
            ],
          ),
          const SizedBox(height: 12),
          _energyConsumptionChart(),
          const SizedBox(height: 12),
          _energyTipsSection(),
        ],
      ),
    );
  }
}
