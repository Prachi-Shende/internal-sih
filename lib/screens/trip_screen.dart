import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_colors.dart';
import '../components/buttons.dart';
import '../services/app_state.dart';

import '../services/models.dart';

class TripScreen extends StatelessWidget {
  const TripScreen({Key? key}) : super(key: key);

  void _showAddTripModal(BuildContext context, AppState appState) {
    String newTitle = '';
    DateTime? selectedDate;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            String dateText = selectedDate == null 
                ? 'Select Date' 
                : '${selectedDate!.day.toString().padLeft(2, '0')}/${selectedDate!.month.toString().padLeft(2, '0')}/${selectedDate!.year}';

            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 24, right: 24, top: 24,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Plan a New Trip', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: const InputDecoration(labelText: 'Destination (e.g. Kyoto, Japan)', border: OutlineInputBorder()),
                    onChanged: (val) => newTitle = val,
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (date != null) setState(() => selectedDate = date);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Dates', border: OutlineInputBorder()),
                      child: Text(dateText, style: TextStyle(color: selectedDate == null ? Colors.grey[600] : Colors.black, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary, 
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        if (newTitle.isNotEmpty && selectedDate != null) {
                          // Compare with yesterday so today counts as upcoming
                          bool isUpcoming = selectedDate!.isAfter(DateTime.now().subtract(const Duration(days: 1)));
                          
                          appState.addTrip(Trip(
                            id: DateTime.now().millisecondsSinceEpoch.toString(),
                            title: newTitle,
                            dateString: isUpcoming ? 'leaving $dateText' : dateText,
                            imageUrl: 'https://picsum.photos/seed/${newTitle.replaceAll(' ', '')}/400/300',
                            isUpcoming: isUpcoming,
                          ));
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isUpcoming ? 'Trip added to upcoming!' : 'Trip added to past!')));
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill out all fields')));
                        }
                      },
                      child: const Text('Add Trip', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showEditTripModal(BuildContext context, AppState appState, Trip trip) {
    String newTitle = trip.title;
    // Extract date from "leaving 13/10/2026" or "13/10/2026"
    String initialDateString = trip.dateString.replaceAll('leaving ', '').split(' - ')[0]; 
    DateTime? selectedDate;
    
    try {
      if (initialDateString.length >= 10) {
        int d = int.parse(initialDateString.substring(0, 2));
        int m = int.parse(initialDateString.substring(3, 5));
        int y = int.parse(initialDateString.substring(6, 10));
        selectedDate = DateTime(y, m, d);
      }
    } catch (e) {
      // Fallback
    }
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            String dateText = selectedDate == null 
                ? 'Select Date' 
                : '${selectedDate!.day.toString().padLeft(2, '0')}/${selectedDate!.month.toString().padLeft(2, '0')}/${selectedDate!.year}';

            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 24, right: 24, top: 24,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Edit Trip', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: newTitle,
                    decoration: const InputDecoration(labelText: 'Destination', border: OutlineInputBorder()),
                    onChanged: (val) => newTitle = val,
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (date != null) setState(() => selectedDate = date);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Dates', border: OutlineInputBorder()),
                      child: Text(dateText, style: TextStyle(color: selectedDate == null ? Colors.grey[600] : Colors.black, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary, 
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        if (newTitle.isNotEmpty && selectedDate != null) {
                          bool isUpcoming = selectedDate!.isAfter(DateTime.now().subtract(const Duration(days: 1)));
                          
                          appState.updateTrip(Trip(
                            id: trip.id,
                            title: newTitle,
                            dateString: isUpcoming ? 'leaving $dateText' : dateText,
                            imageUrl: trip.imageUrl,
                            isUpcoming: isUpcoming,
                          ));
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Trip updated successfully!')));
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill out all fields')));
                        }
                      },
                      child: const Text('Save Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

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
            Text(
              'HEY ${appState.userName.split(" ")[0].toUpperCase()} !!',
              style: const TextStyle(
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
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 1,
                    color: AppColors.primary.withOpacity(0.3),
                  ),
                ),
                const SizedBox(width: 12),
                CircularIconButton(
                  icon: Icons.add,
                  onPressed: () => _showAddTripModal(context, appState),
                  backgroundColor: AppColors.primary,
                  iconColor: Colors.white,
                )
              ],
            ),
            const SizedBox(height: 16),
            
            if (appState.upcomingTrips.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: Text("No upcoming trips. Tap + to plan one!", style: TextStyle(color: AppColors.textSecondary))),
              )
            else
              ...appState.upcomingTrips.map((trip) => Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: _buildTripCard(context, appState, trip),
              )),
            
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
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 1,
                    color: AppColors.primary.withOpacity(0.3),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (appState.pastTrips.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: Text("No past trips.", style: TextStyle(color: AppColors.textSecondary))),
              )
            else
              ...appState.pastTrips.map((trip) => Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: _buildTripCard(context, appState, trip),
              )),
          ],
        ),
      ),
    );
  }

  Widget _buildTripCard(BuildContext context, AppState appState, Trip trip) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), bottomLeft: Radius.circular(20)),
            child: Image.network(
              trip.imageUrl,
              width: 100,
              height: 100,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trip.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.calendar_month, color: AppColors.primary, size: 14),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        trip.dateString,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.edit, color: AppColors.primary, size: 20),
                onPressed: () => _showEditTripModal(context, appState, trip),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(height: 12),
              IconButton(
                icon: const Icon(Icons.delete, color: AppColors.emergency, size: 20),
                onPressed: () {
                  appState.deleteTrip(trip.id);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Trip deleted!')));
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }
}
