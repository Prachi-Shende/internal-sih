import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../components/buttons.dart';
import 'safety_assist_screen.dart'; // We'll create this soon

class MapScreen extends StatelessWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Simulated Map Background (Aerial view)
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 1.0,
              maxScale: 5.0,
              child: Image.network(
                'https://images.unsplash.com/photo-1524661135-423995f22d0b', // Aerial map view
                fit: BoxFit.cover,
              ),
            ),
          ),
          
          // Safety Gradient overlay (just a slight darkening for contrast)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.1),
            ),
          ),

          // AR Route Path Simulation (SVG or custom painter could go here, we'll use a simple indicator)
          Center(
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.5), width: 2, style: BorderStyle.solid),
              ),
              child: const Center(
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary,
                  child: CircleAvatar(
                    radius: 20,
                    backgroundImage: NetworkImage('https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=100&q=80'),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).size.height * 0.45,
            left: MediaQuery.of(context).size.width * 0.5 - 25,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'You',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // Top floating controls
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircularIconButton(
                    icon: Icons.chevron_left,
                    onPressed: () {
                      // Handled by MainNavigationWrapper usually, or goes to home
                    },
                  ),
                  
                  // Floating Destination Card (AR mode style)
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(left: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              'https://images.unsplash.com/photo-1537996194471-e657df975ab4',
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Destination on',
                                  style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                ),
                                Text(
                                  'Nusa Dua Beach',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  CircularIconButton(
                    icon: Icons.more_horiz,
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),

          // Route distance info
          Positioned(
            top: 140,
            left: 24,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Distance', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                  Text('24.5 Km', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  SizedBox(height: 8),
                  Text('Time', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                  Text('1-2 Hrs', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                ],
              ),
            ),
          ),

          // Bottom Navigation Card (Route progress)
          Positioned(
            bottom: 120, // Above floating bottom nav
            left: 24,
            right: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // "I Feel Unsafe" Action button
                GestureDetector(
                  onTap: () {
                    // Navigate to Safety Assist
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SafetyAssistScreen()));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.emergency.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.security, color: AppColors.emergency, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'I FEEL UNSAFE',
                          style: TextStyle(
                            color: AppColors.emergency,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // AR Route Bottom Panel
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, -5),
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(Icons.turn_left, color: AppColors.emergency),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Stack(
                                alignment: Alignment.centerLeft,
                                children: [
                                  Container(height: 4, color: AppColors.divider),
                                  Container(height: 4, width: 80, color: AppColors.primary),
                                  Positioned(
                                    left: 70,
                                    child: Container(
                                      width: 16,
                                      height: 16,
                                      decoration: const BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.directions_car, size: 10, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Icon(Icons.play_arrow, color: AppColors.warning),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text('1.3km', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          Text('23min', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('15:50', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('Exit AR View', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      )
                    ],
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
