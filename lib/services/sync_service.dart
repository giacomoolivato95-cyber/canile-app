import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/dog.dart';
import '../models/kennel_box.dart';
import '../models/booking.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final SupabaseClient supabase = Supabase.instance.client;
  
  late final Box<Dog> dogBox;
  late final Box<KennelBox> boxBox;
  late final Box<Booking> bookingBox;

  bool _isInitialized = false;
  bool _isSyncing = false;

  void initialize() {
    if (!_isInitialized) {
      dogBox = Hive.box<Dog>('dogs');
      boxBox = Hive.box<KennelBox>('kennel_boxes');
      bookingBox = Hive.box<Booking>('bookings');
      _isInitialized = true;
      print('✅ SyncService inizializzato');
    }
  }

  Future<Map<String, int>> syncAll() async {
    if (!_isInitialized) {
      print('⚠️ SyncService non inizializzato');
      return {};
    }

    if (_isSyncing) {
      print('⚠️ Sync già in corso...');
      return {};
    }

    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) {
      print('⚠️ Offline: sync saltato');
      return {};
    }

    _isSyncing = true;
    final results = {
      'dogs_added': 0,
      'dogs_updated': 0,
      'boxes_added': 0,
      'boxes_updated': 0,
      'bookings_added': 0,
      'bookings_updated': 0,
    };

    try {
      print('🔄 Inizio sincronizzazione...');
      
      final dogResults = await _syncDogs();
      results['dogs_added'] = dogResults['added'] ?? 0;
      results['dogs_updated'] = dogResults['updated'] ?? 0;
      
      final boxResults = await _syncBoxes();
      results['boxes_added'] = boxResults['added'] ?? 0;
      results['boxes_updated'] = boxResults['updated'] ?? 0;
      
      final bookingResults = await _syncBookings();
      results['bookings_added'] = bookingResults['added'] ?? 0;
      results['bookings_updated'] = bookingResults['updated'] ?? 0;
      
      print('✅ Sync completato!');
      
    } catch (e) {
      print('❌ Errore sync: $e');
      rethrow;
    } finally {
      _isSyncing = false;
    }

    return results;
  }

  // ============ SYNC DOGS ============
  Future<Map<String, int>> _syncDogs() async {
    int added = 0, updated = 0;

    try {
      final response = await supabase.from('dogs').select('*').order('name');
      final supabaseDogs = List<Map<String, dynamic>>.from(response);

      for (var dogData in supabaseDogs) {
        final existingDog = dogBox.values.firstWhere(
          (d) => d.supabaseId == dogData['id'],
          orElse: () => Dog(name: ''),
        );
        
        if (existingDog.name.isNotEmpty) {
          existingDog.name = dogData['name'] ?? '';
          existingDog.breed = dogData['breed'];
          existingDog.serviceType = dogData['service_type'] ?? 'pensione';
          existingDog.owner = dogData['owner'];
          existingDog.phone = dogData['phone'];
          existingDog.notes = dogData['notes'];
          existingDog.updatedAt = dogData['updated_at'] != null 
              ? DateTime.parse(dogData['updated_at']) 
              : DateTime.now();
          existingDog.synced = true;
          await existingDog.save();
          updated++;
        } else {
          final newDog = Dog(
            supabaseId: dogData['id'],
            name: dogData['name'] ?? '',
            breed: dogData['breed'],
            serviceType: dogData['service_type'] ?? 'pensione',
            owner: dogData['owner'],
            phone: dogData['phone'],
            notes: dogData['notes'],
            updatedAt: dogData['updated_at'] != null 
                ? DateTime.parse(dogData['updated_at']) 
                : DateTime.now(),
            synced: true,
          );
          await dogBox.add(newDog);
          added++;
        }
      }

      final unsyncedDogs = dogBox.values.where((d) => !d.synced).toList();
      for (var dog in unsyncedDogs) {
        try {
          final data = {
            'name': dog.name,
            'breed': dog.breed,
            'service_type': dog.serviceType,
            'owner': dog.owner,
            'phone': dog.phone,
            'notes': dog.notes,
          };
          
          if (dog.supabaseId == null || dog.supabaseId!.startsWith('local_')) {
            final result = await supabase.from('dogs').insert(data).select();
            dog.supabaseId = result[0]['id'];
          } else {
            await supabase.from('dogs').update(data).match({'id': dog.supabaseId!});
          }
          dog.synced = true;
          dog.updatedAt = DateTime.now();
          await dog.save();
          updated++;
        } catch (e) {
          print('❌ Errore push dog ${dog.name}: $e');
        }
      }

    } catch (e) {
      print('❌ Errore sync dogs: $e');
    }

    return {'added': added, 'updated': updated};
  }

  // ============ SYNC BOXES ============
  Future<Map<String, int>> _syncBoxes() async {
    int added = 0, updated = 0;

    try {
      final response = await supabase.from('boxes').select('*').order('name');
      final supabaseBoxes = List<Map<String, dynamic>>.from(response);

      for (var boxData in supabaseBoxes) {
        final existingBox = boxBox.values.firstWhere(
          (b) => b.supabaseId == boxData['id'],
          orElse: () => KennelBox(name: '', capacity: 2),
        );
        
        if (existingBox.name.isNotEmpty) {
          existingBox.name = boxData['name'] ?? '';
          existingBox.notes = boxData['notes'];
          existingBox.capacity = boxData['capacity'] ?? 2;
          existingBox.updatedAt = boxData['updated_at'] != null 
              ? DateTime.parse(boxData['updated_at']) 
              : DateTime.now();
          existingBox.synced = true;
          await existingBox.save();
          updated++;
        } else {
          final newBox = KennelBox(
            supabaseId: boxData['id'],
            name: boxData['name'] ?? '',
            notes: boxData['notes'],
            capacity: boxData['capacity'] ?? 2,
            updatedAt: boxData['updated_at'] != null 
                ? DateTime.parse(boxData['updated_at']) 
                : DateTime.now(),
            synced: true,
          );
          await boxBox.add(newBox);
          added++;
        }
      }

      final unsyncedBoxes = boxBox.values.where((b) => !b.synced).toList();
      for (var box in unsyncedBoxes) {
        try {
          final data = {
            'name': box.name,
            'notes': box.notes,
            'capacity': box.capacity,
          };
          
          if (box.supabaseId == null || box.supabaseId!.startsWith('local_')) {
            final result = await supabase.from('boxes').insert(data).select();
            box.supabaseId = result[0]['id'];
          } else {
            await supabase.from('boxes').update(data).match({'id': box.supabaseId!});
          }
          box.synced = true;
          box.updatedAt = DateTime.now();
          await box.save();
          updated++;
        } catch (e) {
          print('❌ Errore push box ${box.name}: $e');
        }
      }

    } catch (e) {
      print('❌ Errore sync boxes: $e');
    }

    return {'added': added, 'updated': updated};
  }

  // ============ SYNC BOOKINGS ============
  Future<Map<String, int>> _syncBookings() async {
    int added = 0, updated = 0;

    try {
      final response = await supabase.from('bookings').select('*').order('start_date');
      final supabaseBookings = List<Map<String, dynamic>>.from(response);

      for (var bookingData in supabaseBookings) {
        final existingBooking = bookingBox.values.firstWhere(
          (b) => b.supabaseId == bookingData['id'],
          orElse: () => Booking(dogId: '', boxId: '', startDate: DateTime.now(), endDate: DateTime.now()),
        );
        
        if (existingBooking.dogId.isNotEmpty) {
          existingBooking.dogId = bookingData['dog_id'] ?? '';
          existingBooking.boxId = bookingData['box_id'] ?? '';
          existingBooking.startDate = DateTime.parse(bookingData['start_date']);
          existingBooking.endDate = DateTime.parse(bookingData['end_date']);
          existingBooking.notes = bookingData['notes'];
          existingBooking.updatedAt = bookingData['updated_at'] != null 
              ? DateTime.parse(bookingData['updated_at']) 
              : DateTime.now();
          existingBooking.synced = true;
          await existingBooking.save();
          updated++;
        } else {
          final newBooking = Booking(
            supabaseId: bookingData['id'],
            dogId: bookingData['dog_id'] ?? '',
            boxId: bookingData['box_id'] ?? '',
            startDate: DateTime.parse(bookingData['start_date']),
            endDate: DateTime.parse(bookingData['end_date']),
            notes: bookingData['notes'],
            updatedAt: bookingData['updated_at'] != null 
                ? DateTime.parse(bookingData['updated_at']) 
                : DateTime.now(),
            synced: true,
          );
          await bookingBox.add(newBooking);
          added++;
        }
      }

      final unsyncedBookings = bookingBox.values.where((b) => !b.synced).toList();
      for (var booking in unsyncedBookings) {
        try {
          final data = {
            'dog_id': booking.dogId,
            'box_id': booking.boxId,
            'start_date': booking.startDate.toIso8601String().split('T').first,
            'end_date': booking.endDate.toIso8601String().split('T').first,
            'notes': booking.notes,
          };
          
          if (booking.supabaseId == null || booking.supabaseId!.startsWith('local_')) {
            final result = await supabase.from('bookings').insert(data).select();
            booking.supabaseId = result[0]['id'];
          } else {
            await supabase.from('bookings').update(data).match({'id': booking.supabaseId!});
          }
          booking.synced = true;
          booking.updatedAt = DateTime.now();
          await booking.save();
          updated++;
        } catch (e) {
          print('❌ Errore push booking: $e');
        }
      }

    } catch (e) {
      print('❌ Errore sync bookings: $e');
    }

    return {'added': added, 'updated': updated};
  }

  Future<bool> hasInternet() async {
    final connectivity = await Connectivity().checkConnectivity();
    return connectivity != ConnectivityResult.none;
  }
}
