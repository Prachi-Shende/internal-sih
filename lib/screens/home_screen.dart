import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_colors.dart';
import '../services/app_state.dart';
import '../services/mock_data.dart';
import '../services/models.dart';
import '../components/cards.dart';
import 'profile/notifications_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedCategory = 'Mountains';
  String _searchQuery = '';
  List<TripDestination> _searchResults = [];
  bool _isLoading = false;
  Timer? _debounce;

  Future<void> _searchLocations(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&addressdetails=1&limit=5');
      final response = await http.get(url, headers: {'User-Agent': 'TravaraApp/1.0'});
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final List<TripDestination> results = data.map((item) {
          final address = item['address'] ?? {};
          final name = item['name'] ?? 'Unknown Location';
          final country = address['country'] ?? '';
          final city = address['city'] ?? address['town'] ?? address['village'] ?? '';
          final locationStr = [city, country].where((e) => e.toString().isNotEmpty).join(', ');
          
          return TripDestination(
            id: item['place_id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
            name: name.toString().isEmpty ? 'Location' : name,
            location: locationStr.isEmpty ? 'Unknown' : locationStr,
            imageUrl: 'https://images.unsplash.com/photo-1488085061387-422e29b40080',
            rating: 4.5,
            isPopular: false,
            category: 'Search',
          );
        }).toList();

        if (mounted) {
          setState(() {
            _searchResults = results;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      backgroundColor: appState.isEmergencyActive 
          ? AppColors.emergency.withOpacity(0.1) 
          : (appState.currentRisk == RiskLevel.high ? AppColors.warning.withOpacity(0.1) : AppColors.background),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 120), // bottom padding for nav
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppColors.primary.withOpacity(0.2),
                          child: Text(
                            appState.userName.isNotEmpty ? appState.userName[0].toUpperCase() : 'E',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hi, ${appState.userName.split(' ')[0]} 👋',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                'Where do you want to discover?',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: appState.isEmergencyActive ? AppColors.emergency.withOpacity(0.2) : Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                          )
                        ],
                      ),
                      child: Icon(
                        Icons.notifications, 
                        size: 20, 
                        color: appState.isEmergencyActive ? AppColors.emergency : AppColors.textPrimary
                      ),
                    ),
                  ),
                ],
              ),
              
              if (appState.isEmergencyActive) ...[
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.emergency,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: AppColors.emergency.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'ACTIVE EMERGENCY\nHelp is coordinating. Follow safety instructions.',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 24),
              
              // Safety Status Card
              StatusCard(
                state: appState.systemState,
                risk: appState.currentRisk,
              ),

              const SizedBox(height: 24),

              // Search Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                    if (_debounce?.isActive ?? false) _debounce!.cancel();
                    _debounce = Timer(const Duration(milliseconds: 500), () {
                      _searchLocations(value);
                    });
                  },
                  onSubmitted: (value) {
                    FocusScope.of(context).unfocus();
                  },
                  decoration: InputDecoration(
                    hintText: 'Search destinations...',
                    hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.5)),
                    border: InputBorder.none,
                    icon: const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
                    suffixIcon: const Icon(Icons.tune, color: AppColors.textSecondary, size: 18),
                  ),
                ),
              ),

              // Search Dropdown
              if (_searchQuery.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 250),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _isLoading 
                    ? const Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : _searchResults.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Center(child: Text("No destinations found")),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final dest = _searchResults[index];
                              return ListTile(
                                leading: const Icon(Icons.location_on, color: AppColors.primary),
                                title: Text(dest.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(dest.location, style: const TextStyle(fontSize: 12)),
                                onTap: () {
                                  // Action on selecting a destination
                                  FocusScope.of(context).unfocus();
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Selected: ${dest.name}')),
                                  );
                                },
                              );
                            },
                          ),
                ),
              ],

              const SizedBox(height: 24),

              // Categories
              const Text(
                'Categories',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildCategoryPill('Mountains', Icons.landscape),
                    _buildCategoryPill('Waterfalls', Icons.water_drop),
                    _buildCategoryPill('Desert', Icons.wb_sunny),
                    _buildCategoryPill('Beaches', Icons.beach_access),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Popular Places
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Popular places',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'See all',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.sage,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Horizontal list of Destination Cards
              SizedBox(
                height: 320,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  itemCount: MockData.popularDestinations.where((d) => d.category == _selectedCategory).length,
                  itemBuilder: (context, index) {
                    final categoryDestinations = MockData.popularDestinations.where((d) => d.category == _selectedCategory).toList();
                    return DestinationCard(
                      destination: categoryDestinations[index],
                      onTap: () {
                        // Navigation to detail could go here
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryPill(String label, IconData icon) {
    bool isSelected = _selectedCategory == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = label;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: isSelected ? null : Border.all(color: AppColors.divider),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : AppColors.textPrimary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
