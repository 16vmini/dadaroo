import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dadaroo/config/app_config.dart';
import 'package:dadaroo/models/delivery.dart';
import 'package:dadaroo/providers/app_provider.dart';
import 'package:dadaroo/services/parent_jokes.dart';
import 'package:dadaroo/theme/app_theme.dart';
import 'package:dadaroo/widgets/dadaroo_map.dart';
import 'package:dadaroo/widgets/celebration_widget.dart';

class FamilyView extends StatelessWidget {
  const FamilyView({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    if (provider.showCelebration) {
      return _buildCelebrationView(context, provider);
    }

    if (!provider.isDeliveryActive) {
      return _buildWaitingView();
    }

    return _buildTrackingView(context, provider);
  }

  Widget _buildWaitingView() {
    return Scaffold(
      appBar: AppBar(title: Text('${appConfig.familyMemberEmoji} Family View')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.lightOrange,
                  shape: BoxShape.circle,
                ),
                child: const Text('🍽️', style: TextStyle(fontSize: 64)),
              ),
              const SizedBox(height: 24),
              Text(
                'Waiting for ${appConfig.parentRole}...',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkBrown,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "No food run in progress yet.\nTell ${appConfig.parentRole} it's dinner time!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.warmBrown.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 40),
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
      ),
    );
  }

  Widget _buildTrackingView(BuildContext context, AppProvider provider) {
    final delivery = provider.activeDelivery!;
    final status = delivery.status;
    final isTracking = status.isTracking;

    return Scaffold(
      appBar: AppBar(
        title: Text('${status.emoji} ${appConfig.parentRole} Tracker'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Status header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              color: AppTheme.primaryOrange.withValues(alpha: 0.1),
              child: Column(
                children: [
                  Text(
                    delivery.takeawayEmoji,
                    style: const TextStyle(fontSize: 48),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${delivery.dadName} ${status.familyMessage}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkBrown,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    delivery.takeawayDisplayName,
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.warmBrown.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),

            // Status timeline for family
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
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
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: status.progressValue,
                          backgroundColor: AppTheme.lightOrange,
                          valueColor:
                              AlwaysStoppedAnimation(AppTheme.primaryOrange),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...DeliveryStatus.values
                          .where((s) => s != DeliveryStatus.nearlyThere)
                          .map((s) => _buildFamilyStatusRow(s, status)),
                    ],
                  ),
                ),
              ),
            ),

            // Map (only when on route)
            if (isTracking)
              DadarooMap(
                dadLocation: provider.currentParentLocation,
                homeLocation: provider.gpsService.homeLocation,
                progress: provider.deliveryProgress,
              ),

            // ETA (only when tracking)
            if (isTracking)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              color: provider.parentIsClose
                                  ? AppTheme.successGreen
                                  : AppTheme.primaryOrange,
                              size: 32,
                            ),
                            const SizedBox(width: 12),
                            Builder(builder: (context) {
                              final eta = provider.etaRemaining;
                              final minutes = eta.inMinutes;
                              final seconds = eta.inSeconds % 60;
                              return Text(
                                '${minutes}m ${seconds.toString().padLeft(2, '0')}s',
                                style: TextStyle(
                                  fontSize: 42,
                                  fontWeight: FontWeight.w900,
                                  color: provider.parentIsClose
                                      ? AppTheme.successGreen
                                      : AppTheme.primaryOrange,
                                ),
                              );
                            }),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (provider.parentIsClose)
                          _ParentCloseAlert()
                        else
                          Text(
                            '${appConfig.parentRole} is on the way! 🚗',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppTheme.warmBrown.withValues(alpha: 0.8),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildFamilyStatusRow(DeliveryStatus step, DeliveryStatus current) {
    final isDone = step.index < current.index;
    final isCurrent = step == current;
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

  Widget _buildCelebrationView(BuildContext context, AppProvider provider) {
    return Scaffold(
      body: Stack(
        children: [
          const CelebrationWidget(),
          Positioned(
            left: 24,
            right: 24,
            bottom: 60,
            child: Column(
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    provider.skipRating();
                  },
                  icon: const Icon(Icons.star),
                  label: Text('Rate Your ${appConfig.parentRole}!'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => provider.skipRating(),
                  child: Text(
                    'Skip Rating',
                    style: TextStyle(color: AppTheme.warmBrown),
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

class _ParentCloseAlert extends StatefulWidget {
  @override
  State<_ParentCloseAlert> createState() => _ParentCloseAlertState();
}

class _ParentCloseAlertState extends State<_ParentCloseAlert>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.successGreen
                .withValues(alpha: 0.15 + _controller.value * 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.successGreen.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '🎉',
                style: TextStyle(
                  fontSize: 20 + _controller.value * 4,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${appConfig.parentRole.toUpperCase()} IS ALMOST HOME!',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.successGreen,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
