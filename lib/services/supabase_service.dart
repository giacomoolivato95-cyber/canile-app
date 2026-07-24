import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  SupabaseClient get client => Supabase.instance.client;

  // ============ DOGS ============
  Future<List<Map<String, dynamic>>> fetchDogs() async {
    final response = await client
        .from('dogs')
        .select('*')
        .order('name');
    return response;
  }

  Future<void> upsertDog(Map<String, dynamic> dog) async {
    await client.from('dogs').upsert(dog);
  }

  Future<void> deleteDog(String supabaseId) async {
    await client.from('dogs').delete().match({'id': supabaseId});
  }

  // ============ BOXES ============
  Future<List<Map<String, dynamic>>> fetchBoxes() async {
    final response = await client
        .from('boxes')
        .select('*')
        .order('name');
    return response;
  }

  Future<void> upsertBox(Map<String, dynamic> box) async {
    await client.from('boxes').upsert(box);
  }

  Future<void> deleteBox(String supabaseId) async {
    await client.from('boxes').delete().match({'id': supabaseId});
  }

  // ============ BOOKINGS ============
  Future<List<Map<String, dynamic>>> fetchBookings() async {
    final response = await client
        .from('bookings')
        .select('*')
        .order('start_date');
    return response;
  }

  Future<void> upsertBooking(Map<String, dynamic> booking) async {
    await client.from('bookings').upsert(booking);
  }

  Future<void> deleteBooking(String supabaseId) async {
    await client.from('bookings').delete().match({'id': supabaseId});
  }
}