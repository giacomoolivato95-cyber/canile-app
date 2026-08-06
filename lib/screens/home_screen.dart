import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

import 'calendar_screen.dart';
import 'dogs_screen.dart';
import 'boxes_screen.dart';
import '../services/sync_service.dart';
import '../models/dog.dart';
import '../models/kennel_box.dart';
import '../models/booking.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _isOnline = true;
  bool _isSyncing = false;
  String _syncStatus = '';
  int _syncCounter = 0;

  final SyncService _syncService = SyncService();

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _listenConnectivity();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _performSync();
    });
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    setState(() {
      _isOnline = result != ConnectivityResult.none;
    });
  }

  void _listenConnectivity() {
    Connectivity().onConnectivityChanged.listen((result) {
      final wasOffline = !_isOnline;
      final isNowOnline = result != ConnectivityResult.none;
      
      setState(() {
        _isOnline = isNowOnline;
      });

      if (wasOffline && isNowOnline) {
        _performSync();
      }
    });
  }

  Future<void> _performSync() async {
    if (_isSyncing) {
      print('⚠️ Sync già in corso...');
      return;
    }
    
    if (!_isOnline) {
      _showSnackBar('⚠️ Sei offline, non posso sincronizzare');
      return;
    }

    setState(() {
      _isSyncing = true;
      _syncStatus = '🔄 Sincronizzazione...';
    });

    try {
      final results = await _syncService.syncAll();
      
      final totalChanges = results['dogs_added']! + results['dogs_updated']! +
                          results['boxes_added']! + results['boxes_updated']! +
                          results['bookings_added']! + results['bookings_updated']!;
      
      setState(() {
        _syncCounter++;
        _syncStatus = totalChanges > 0 ? '✅ Sincronizzato!' : '✅ Già sincronizzato';
      });

      setState(() {});

      if (totalChanges > 0) {
        _showSnackBar(
          '✅ Sincronizzati: 🐕 ${results['dogs_added']! + results['dogs_updated']!} cani, '
          '📦 ${results['boxes_added']! + results['boxes_updated']!} box, '
          '📅 ${results['bookings_added']! + results['bookings_updated']!} prenotazioni'
        );
      } else {
        _showSnackBar('✅ Tutto sincronizzato!');
      }
      
    } catch (e) {
      setState(() {
        _syncStatus = '❌ Errore';
      });
      _showSnackBar('❌ Errore sincronizzazione: $e');
      print('❌ Errore sync: $e');
    } finally {
      setState(() {
        _isSyncing = false;
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) {
            setState(() {
              _syncStatus = '';
            });
          }
        });
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _exportLocalData() async {
    try {
      final dogBox = Hive.box<Dog>('dogs');
      final boxBox = Hive.box<KennelBox>('kennel_boxes');
      final bookingBox = Hive.box<Booking>('bookings');
      
      final data = {
        'dogs': dogBox.values.map((d) => ({
          'name': d.name,
          'breed': d.breed,
          'serviceType': d.serviceType,
          'owner': d.owner,
          'phone': d.phone,
          'notes': d.notes,
        })).toList(),
        'boxes': boxBox.values.map((b) => ({
          'name': b.name,
          'notes': b.notes,
          'capacity': b.capacity,
        })).toList(),
        'bookings': bookingBox.values.map((b) => ({
          'dogId': b.dogId,
          'boxId': b.boxId,
          'startDate': b.startDate.toIso8601String(),
          'endDate': b.endDate.toIso8601String(),
          'notes': b.notes,
        })).toList(),
      };
      
      final jsonString = jsonEncode(data);
      await Clipboard.setData(ClipboardData(text: jsonString));
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('📊 Dati esportati'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('🐕 Cani: ${data['dogs']!.length}'),
              Text('📦 Box: ${data['boxes']!.length}'),
              Text('📅 Prenotazioni: ${data['bookings']!.length}'),
              const SizedBox(height: 16),
              const Text('✅ I dati sono stati copiati nella clipboard (appunti).'),
              const Text('Incollali in un appunti o in un messaggio per salvarli.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Chiudi'),
            ),
          ],
        ),
      );
      
    } catch (e) {
      _showSnackBar('❌ Errore esportazione: $e');
      print('❌ Errore export: $e');
    }
  }

  void _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      const CalendarScreen(),
      const DogsScreen(),
      const BoxesScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Canile App'),
            if (_syncStatus.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  _syncStatus,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
          ],
        ),
        actions: [
          if (!_isOnline)
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: Row(
                children: [
                  const Icon(Icons.wifi_off, color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  const Text(
                    'Offline',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            onPressed: _exportLocalData,
            tooltip: 'Esporta dati locali',
          ),
          
          IconButton(
            icon: Icon(
              _isSyncing ? Icons.sync_problem : Icons.sync,
              color: _isSyncing ? Colors.amber : Colors.white,
              size: 28,
            ),
            onPressed: _isSyncing ? null : _performSync,
            tooltip: _isOnline 
                ? 'Sincronizza i dati con il cloud' 
                : 'Offline - sincronizzazione non disponibile',
          ),
          
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: _logout,
            tooltip: 'Esci',
          ),
        ],
      ),
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: Colors.brown,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'Calendario',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.pets),
            label: 'Cani',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2),
            label: 'Box',
          ),
        ],
      ),
    );
  }
}
