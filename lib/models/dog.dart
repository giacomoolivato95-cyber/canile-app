import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/dog.dart';
import '../models/kennel_box.dart';
import '../models/booking.dart';

class DogsScreen extends StatefulWidget {
  const DogsScreen({super.key});

  @override
  State<DogsScreen> createState() => _DogsScreenState();
}

class _DogsScreenState extends State<DogsScreen> {
  final Box<Dog> dogBox = Hive.box<Dog>('dogs');
  final SupabaseClient supabase = Supabase.instance.client;
  List<Dog> _dogs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDogs();
  }

  Future<void> _loadDogs() async {
    setState(() => _isLoading = true);
    try {
      final response = await supabase.from('dogs').select('*').order('name');
      final dogsFromSupabase = List<Map<String, dynamic>>.from(response);
      
      if (dogsFromSupabase.isNotEmpty) {
        await dogBox.clear();
        for (var dogData in dogsFromSupabase) {
          final dog = Dog(
            supabaseId: dogData['id'],
            name: dogData['name'] ?? '',
            breed: dogData['breed'],
            serviceType: dogData['service_type'] ?? 'pensione',
            owner: dogData['owner'],
            phone: dogData['phone'],
            notes: dogData['notes'],
            updatedAt: DateTime.parse(dogData['updated_at'] ?? DateTime.now().toIso8601String()),
            synced: true,
          );
          await dogBox.add(dog);
        }
        _dogs = dogBox.values.toList();
      } else {
        _dogs = dogBox.values.toList();
      }
    } catch (e) {
      print('❌ Errore caricamento cani: $e');
      _dogs = dogBox.values.toList();
    }
    setState(() => _isLoading = false);
  }

  void _showAddDogDialog([Dog? dogToEdit]) async {
    final isEditing = dogToEdit != null;
    final nameController = TextEditingController(text: dogToEdit?.name ?? '');
    final breedController = TextEditingController(text: dogToEdit?.breed ?? '');
    final ownerController = TextEditingController(text: dogToEdit?.owner ?? '');
    final phoneController = TextEditingController(text: dogToEdit?.phone ?? '');
    final notesController = TextEditingController(text: dogToEdit?.notes ?? '');
    
    String? selectedServiceType = dogToEdit?.serviceType ?? 'pensione';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(isEditing ? 'Modifica cane' : 'Nuovo cane'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Nome *'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: breedController,
                    decoration: const InputDecoration(labelText: 'Razza'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedServiceType,
                    decoration: const InputDecoration(
                      labelText: 'Tipo servizio *',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'pensione',
                        child: Row(
                          children: [
                            Icon(Icons.home, color: Colors.blue),
                            SizedBox(width: 8),
                            Text('🏠 Pensione'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'asilo',
                        child: Row(
                          children: [
                            Icon(Icons.school, color: Colors.orange),
                            SizedBox(width: 8),
                            Text('🎨 Asilo'),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        selectedServiceType = value;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: ownerController,
                    decoration: const InputDecoration(labelText: 'Proprietario'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(labelText: 'Telefono'),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(labelText: 'Note'),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annulla'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (nameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Il nome è obbligatorio')),
                    );
                    return;
                  }
                  if (selectedServiceType == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Seleziona il tipo servizio')),
                    );
                    return;
                  }
                  Navigator.pop(context, true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: Text(isEditing ? '💾 Salva' : '➕ Aggiungi'),
              ),
            ],
          );
        },
      ),
    );

    if (result == true) {
      setState(() => _isLoading = true);
      
      try {
        final data = {
          'name': nameController.text.trim(),
          'breed': breedController.text.trim().isEmpty ? null : breedController.text.trim(),
          'service_type': selectedServiceType!,
          'owner': ownerController.text.trim().isEmpty ? null : ownerController.text.trim(),
          'phone': phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
          'notes': notesController.text.trim().isEmpty ? null : notesController.text.trim(),
        };

        if (isEditing && dogToEdit != null && dogToEdit.supabaseId != null) {
          await supabase.from('dogs').update(data).match({'id': dogToEdit.supabaseId!});
          
          dogToEdit.name = data['name']!;
          dogToEdit.breed = data['breed'];
          dogToEdit.serviceType = data['service_type']!;
          dogToEdit.owner = data['owner'];
          dogToEdit.phone = data['phone'];
          dogToEdit.notes = data['notes'];
          dogToEdit.synced = true;
          await dogToEdit.save();
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Cane aggiornato su cloud!')),
          );
        } else {
          final result = await supabase.from('dogs').insert(data).select();
          final supabaseId = result[0]['id'];
          
          final dog = Dog(
            supabaseId: supabaseId,
            name: data['name']!,
            breed: data['breed'],
            serviceType: data['service_type']!,
            owner: data['owner'],
            phone: data['phone'],
            notes: data['notes'],
            synced: true,
          );
          await dogBox.add(dog);
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Cane salvato su cloud!')),
          );
        }
        
        await _loadDogs();
        
      } catch (e) {
        print('❌ Errore salvataggio: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Errore: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _deleteDog(Dog dog) async {
    if (dog.supabaseId == null) {
      await dog.delete();
      await _loadDogs();
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Elimina cane'),
        content: Text('Eliminare ${dog.name}? (eliminato anche dal cloud)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await supabase.from('dogs').delete().match({'id': dog.supabaseId!});
                await dog.delete();
                await _loadDogs();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Cane eliminato dal cloud')),
                );
                Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('❌ Errore: $e')),
                );
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDogDialog,
        backgroundColor: Colors.brown,
        child: const Icon(Icons.add),
      ),
      body: _dogs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.pets, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Nessun cane registrato',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _showAddDogDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.brown,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('➕ Aggiungi cane'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _dogs.length,
              itemBuilder: (context, index) {
                final dog = _dogs[index];
                
                final Color cardColor = dog.serviceType == 'asilo' 
                    ? Colors.orange.shade50 
                    : Colors.blue.shade50;
                
                final Color iconColor = dog.serviceType == 'asilo' 
                    ? Colors.orange 
                    : Colors.blue;
                
                final String serviceLabel = dog.serviceType == 'asilo' 
                    ? '🎨 Asilo' 
                    : '🏠 Pensione';

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  color: cardColor,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: iconColor.withOpacity(0.2),
                      child: Text(
                        dog.name[0].toUpperCase(),
                        style: TextStyle(color: iconColor, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(
                      dog.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (dog.breed != null) Text('🐕 ${dog.breed}'),
                        Text(
                          '${dog.owner ?? 'Proprietario non indicato'}${dog.phone != null ? ' • ${dog.phone}' : ''}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: iconColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            serviceLabel,
                            style: TextStyle(
                              fontSize: 11,
                              color: iconColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => _showAddDogDialog(dog),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () => _deleteDog(dog),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
