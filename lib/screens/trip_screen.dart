import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../components/buttons.dart';

class TripScreen extends StatelessWidget {
  const TripScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cardSageBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'TRIPS',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
            fontFamily: 'Courier', // Giving it that specific look from the image if possible
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User greeting
            const Text(
              'HEY JOHNNY !!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            
            // Upcoming
            Row(
              children: [
                const Text(
                  'UPCOMING',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 1,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: 10,
                      itemBuilder: (context, index) {
                        return Container(
                          width: 8,
                          margin: const EdgeInsets.only(right: 8),
                          color: AppColors.primary,
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircularIconButton(
                  icon: Icons.add,
                  onPressed: () {},
                  backgroundColor: AppColors.primary,
                  iconColor: Colors.white,
                )
              ],
            ),
            const SizedBox(height: 16),
            
            _buildTripCard('CAPE YORK', 'leaving 13/10/2021', 'https://picsum.photos/seed/capeyork/300/300'),
            const SizedBox(height: 16),
            _buildTripCard('FRASER ISLAND', 'leaving 27/12/2021', 'https://images.unsplash.com/photo-1506744626753-1fa7604ee447?auto=format&fit=crop&w=300&q=80'),
            
            const SizedBox(height: 32),
            
            // Past
            Row(
              children: [
                const Text(
                  'PAST',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 1,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: 10,
                      itemBuilder: (context, index) {
                        return Container(
                          width: 8,
                          margin: const EdgeInsets.only(right: 8),
                          color: AppColors.primary,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            _buildTripCard('DOUBLE ISLAND', '10/09 - 12/09/2021', 'https://images.unsplash.com/photo-1449844908441-8829872d2607?auto=format&fit=crop&w=300&q=80'),
          ],
        ),
      ),
    );
  }

  Widget _buildTripCard(String title, String date, String imageUrl) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.primary, width: 1.5),
      ),
      child: Row(
        children: [
          Image.network(
            imageUrl,
            width: 80,
            height: 80,
            fit: BoxFit.cover,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  date,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
