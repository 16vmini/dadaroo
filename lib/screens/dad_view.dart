import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dadaroo/config/app_config.dart';
import 'package:dadaroo/models/delivery.dart';
import 'package:dadaroo/models/takeaway_type.dart';
import 'package:dadaroo/providers/app_provider.dart';
import 'package:dadaroo/screens/delivery_setup_screen.dart';
import 'package:dadaroo/screens/profile_screen.dart';
import 'package:dadaroo/services/parent_jokes.dart';
import 'package:dadaroo/theme/app_theme.dart';

class DadView extends StatefulWidget {
  const DadView({super.key});

  @override
  State<DadView> createState() => _DadViewState();
}

class _DadViewState extends State<DadView> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  final _customController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    if (provider.isDeliveryActive) {
      return _buildActiveDeliveryView(provider);
    }

    final userName = provider.userProfile?.name ?? provider.currentParent.name;

    return Scaffold(
      appBar: AppBar(
        title: Text('🚗 ${appConfig.appName}'),
        actions: [
          if (provider.parents.length > 1)
            PopupMenuButton<String>(
              icon: const Icon(Icons.swap_horiz),
              tooltip: 'Switch ${appConfig.parentRole}',
              onSelected: (parentId) => provider.setCurrentParent(parentId),
              itemBuilder: (_) => provider.parents
                  .map((d) => PopupMenuItem(
                        value: d.id,
                        child: Row(
                          children: [
                            Icon(
                              d.id == provider.currentParent.id
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              color: AppTheme.primaryOrange,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(d.name),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Text(
              'Hey $userName! 👋',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkBrown,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Got the food? Let the family know!',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.warmBrown.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 40),

            // Takeaway selector
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.restaurant, color: AppTheme.primaryOrange),
                        const SizedBox(width: 8),
                        Text(
                          "What's for dinner?",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.darkBrown,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: TakeawayType.values
                          .where((t) => t != TakeawayType.custom)
                          .map((type) => ChoiceChip(
                                label: Text('${type.emoji} ${type.displayName}'),
                                selected: provider.selectedTakeaway == type,
                                onSelected: (_) =>
                                    provider.setSelectedTakeaway(type),
                                selectedColor: AppTheme.primaryOrange,
                                labelStyle: TextStyle(
                                  color: provider.selectedTakeaway == type
                                      ? Colors.white
                                      : AppTheme.darkBrown,
                                  fontWeight: FontWeight.w500,
                                ),
                                backgroundColor: AppTheme.lightOrange,
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ChoiceChip(
                          label: const Text('✨ Custom'),
                          selected:
                              provider.selectedTakeaway == TakeawayType.custom,
                          onSelected: (_) =>
                              provider.setSelectedTakeaway(TakeawayType.custom),
                          selectedColor: AppTheme.primaryOrange,
                          labelStyle: TextStyle(
                            color:
                                provider.selectedTakeaway == TakeawayType.custom
                                    ? Colors.white
                                    : AppTheme.darkBrown,
                          ),
                          backgroundColor: AppTheme.lightOrange,
                        ),
                        if (provider.selectedTakeaway ==
                            TakeawayType.custom) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _customController,
                              decoration: InputDecoration(
                                hintText: 'What is it?',
                                isDense: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: AppTheme.primaryOrange,
                                  ),
                                ),
                              ),
                              onChanged: provider.setCustomTakeawayName,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // THE BIG BUTTON
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final scale = 1.0 + _pulseController.value * 0.05;
                return Transform.scale(
                  scale: scale,
                  child: child,
                );
              },
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const DeliverySetupScreen()),
                  );
                },
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        appConfig.primaryColorLight,
                        appConfig.primaryColor,
                        appConfig.primaryColorDark,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryOrange.withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        "I'VE GOT\nTHE\nFOOD!",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Joke
            Card(
              color: AppTheme.lightOrange,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Text('😄', style: TextStyle(fontSize: 28)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        ParentJokes.random,
                        style: TextStyle(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          color: AppTheme.warmBrown,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveDeliveryView(AppProvider provider) {
    final delivery = provider.activeDelivery!;
    final status = delivery.status;
    final isTracking = status.isTracking;

    return Scaffold(
      appBar: AppBar(
        title: Text('${status.emoji} ${status.displayName}'),
        actions: [
          TextButton.icon(
            onPressed: () => provider.simulateArrival(),
            icon: const Icon(Icons.fast_forward, color: Colors.white),
            label: const Text('Demo: Arrive',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Current status card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      delivery.takeawayEmoji,
                      style: const TextStyle(fontSize: 48),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Bringing ${delivery.takeawayDisplayName}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkBrown,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Status progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: status.progressValue,
                        backgroundColor: AppTheme.lightOrange,
                        valueColor:
                            AlwaysStoppedAnimation(AppTheme.primaryOrange),
                        minHeight: 10,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      status.displayName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryOrange,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Status timeline
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.timeline, color: AppTheme.primaryOrange),
                        const SizedBox(width: 8),
                        Text(
                          'Order Progress',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.darkBrown,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...DeliveryStatus.values
                        .where((s) => s != DeliveryStatus.nearlyThere)
                        .map((s) => _buildStatusRow(s, delivery.status)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ETA card (only when tracking)
            if (isTracking) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.timer, color: AppTheme.primaryOrange),
                          const SizedBox(width: 8),
                          Builder(builder: (context) {
                            final eta = provider.etaRemaining;
                            final minutes = eta.inMinutes;
                            final seconds = eta.inSeconds % 60;
                            return Text(
                              'ETA: ${minutes}m ${seconds.toString().padLeft(2, '0')}s',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryOrange,
                              ),
                            );
                          }),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: provider.deliveryProgress,
                          backgroundColor: AppTheme.lightOrange,
                          valueColor:
                              AlwaysStoppedAnimation(AppTheme.successGreen),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(provider.deliveryProgress * 100).toInt()}% of the way home',
                        style: TextStyle(
                          color: AppTheme.warmBrown.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Multi-drop stop tracker
            if (delivery.isMultiDrop &&
                (status == DeliveryStatus.onRoute ||
                    status == DeliveryStatus.nearlyThere)) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.route, color: AppTheme.primaryOrange),
                          const SizedBox(width: 8),
                          Text(
                            'Delivery Stops',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkBrown,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${delivery.completedStops}/${delivery.totalStops}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryOrange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...delivery.stops.map((stop) => _buildStopRow(
                            stop,
                            isCurrent:
                                stop.orderIndex == delivery.currentStopIndex,
                          )),
                    ],
                  ),
                ),
              ),
              if (delivery.currentStop != null &&
                  !delivery.currentStop!.isDelivered)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: ElevatedButton.icon(
                    onPressed: () => provider.markCurrentStopDelivered(),
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(
                        'Delivered to ${delivery.currentStop!.name}'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successGreen,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
            ],

            // Next status button
            if (status.next != null &&
                status != DeliveryStatus.nearlyThere)
              ElevatedButton.icon(
                onPressed: () => provider.advanceDeliveryStatus(),
                icon: Icon(_statusActionIcon(status)),
                label: Text(
                  _statusActionLabel(status),
                  style: const TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryOrange,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => provider.cancelDelivery(),
              child: Text(
                'Cancel Delivery',
                style: TextStyle(color: AppTheme.warmBrown),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusActionLabel(DeliveryStatus status) => switch (status) {
        DeliveryStatus.arrivedAtRestaurant => "ORDER PLACED",
        DeliveryStatus.orderPlaced => "THEY'RE MAKING IT",
        DeliveryStatus.orderPreparing => "GOT THE FOOD!",
        DeliveryStatus.orderCollected => "ON MY WAY!",
        DeliveryStatus.onRoute => "NEARLY THERE!",
        _ => "NEXT",
      };

  IconData _statusActionIcon(DeliveryStatus status) => switch (status) {
        DeliveryStatus.arrivedAtRestaurant => Icons.receipt_long,
        DeliveryStatus.orderPlaced => Icons.restaurant,
        DeliveryStatus.orderPreparing => Icons.shopping_bag,
        DeliveryStatus.orderCollected => Icons.directions_car,
        DeliveryStatus.onRoute => Icons.pin_drop,
        _ => Icons.arrow_forward,
      };

  Widget _buildStatusRow(DeliveryStatus step, DeliveryStatus currentStatus) {
    final isDone = step.index < currentStatus.index;
    final isCurrent = step == currentStatus;
    final IconData icon;
    final Color color;

    if (isDone) {
      icon = Icons.check_circle;
      color = AppTheme.successGreen;
    } else if (isCurrent) {
      icon = Icons.radio_button_checked;
      color = AppTheme.primaryOrange;
    } else {
      icon = Icons.radio_button_unchecked;
      color = AppTheme.warmBrown.withValues(alpha: 0.3);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(width: 10),
          Text(step.emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              step.displayName,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                color: isDone
                    ? AppTheme.warmBrown.withValues(alpha: 0.5)
                    : isCurrent
                        ? AppTheme.darkBrown
                        : AppTheme.warmBrown.withValues(alpha: 0.5),
              ),
            ),
          ),
          if (isCurrent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primaryOrange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'NOW',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryOrange,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStopRow(dynamic stop, {required bool isCurrent}) {
    final IconData icon;
    final Color color;
    if (stop.isDelivered) {
      icon = Icons.check_circle;
      color = AppTheme.successGreen;
    } else if (isCurrent) {
      icon = Icons.radio_button_checked;
      color = AppTheme.primaryOrange;
    } else {
      icon = Icons.radio_button_unchecked;
      color = AppTheme.warmBrown.withValues(alpha: 0.4);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stop.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    color: stop.isDelivered
                        ? AppTheme.warmBrown.withValues(alpha: 0.5)
                        : AppTheme.darkBrown,
                    decoration: stop.isDelivered
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                if (stop.recipientName != null)
                  Text(
                    'For: ${stop.recipientName}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.warmBrown.withValues(alpha: 0.6),
                    ),
                  ),
                if (stop.items.isNotEmpty)
                  Text(
                    stop.items.join(', '),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.warmBrown.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
          ),
          if (isCurrent && !stop.isDelivered)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primaryOrange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'NOW',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryOrange,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
