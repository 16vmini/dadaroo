import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dadaroo/models/takeaway_type.dart';
import 'package:dadaroo/providers/app_provider.dart';
import 'package:dadaroo/screens/profile_screen.dart';
import 'package:dadaroo/services/dad_jokes.dart';
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

    final userName = provider.userProfile?.name ?? provider.currentDad.name;

    return Scaffold(
      appBar: AppBar(
        title: const Text('🚗 Dadaroo'),
        actions: [
          if (provider.dads.length > 1)
            PopupMenuButton<String>(
              icon: const Icon(Icons.swap_horiz),
              tooltip: 'Switch Dad',
              onSelected: (dadId) => provider.setCurrentDad(dadId),
              itemBuilder: (_) => provider.dads
                  .map((d) => PopupMenuItem(
                        value: d.id,
                        child: Row(
                          children: [
                            Icon(
                              d.id == provider.currentDad.id
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
            // Dad greeting
            Text(
              'Hey $userName! 👋',
              style: const TextStyle(
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
                    const Row(
                      children: [
                        Icon(Icons.restaurant, color: AppTheme.primaryOrange),
                        SizedBox(width: 8),
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
                    // Custom option
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
                                  borderSide: const BorderSide(
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
                  provider.startDelivery();
                },
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [
                        Color(0xFFFF8C42),
                        AppTheme.primaryOrange,
                        Color(0xFFD4600A),
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

            // Dad joke
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
                        DadJokes.random,
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
    final eta = provider.etaRemaining;
    final minutes = eta.inMinutes;
    final seconds = eta.inSeconds % 60;

    return Scaffold(
      appBar: AppBar(
        title: const Text('🚗 On My Way!'),
        actions: [
          TextButton.icon(
            onPressed: () => provider.simulateArrival(),
            icon: const Icon(Icons.fast_forward, color: Colors.white),
            label: const Text('Demo: Arrive',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      provider.activeDelivery!.takeawayEmoji,
                      style: const TextStyle(fontSize: 60),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Bringing ${provider.activeDelivery!.takeawayDisplayName}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkBrown,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // ETA
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.lightOrange,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timer,
                              color: AppTheme.primaryOrange),
                          const SizedBox(width: 8),
                          Text(
                            'ETA: ${minutes}m ${seconds.toString().padLeft(2, '0')}s',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryOrange,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: provider.deliveryProgress,
                        backgroundColor: AppTheme.lightOrange,
                        valueColor: const AlwaysStoppedAnimation(
                            AppTheme.primaryOrange),
                        minHeight: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
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
            const Spacer(),
            // Cancel button
            TextButton(
              onPressed: () => provider.cancelDelivery(),
              child: const Text(
                'Cancel Delivery',
                style: TextStyle(color: AppTheme.warmBrown),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
