import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/kennel_box.dart';

class BoxesScreen extends StatefulWidget {
  const BoxesScreen({super.key});

  @override
  State<BoxesScreen> createState() => _BoxesScreenState();
}

class _BoxesScreenState extends State<BoxesScreen> {
  final Box<KennelBox> boxBox = Hive.box<KennelBox>('kennel_boxes');
  final SupabaseClient supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _boxes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBoxes();
  }

  Future<void> _loadBoxes() async {
    setState(() => _isLoading = true);
    try {
      final response = await supabase.from('boxes').select('*').order('name');
      _boxes = List<Map<String, dynamic>>.from(response);
      
      if (_boxes.isEmpty) {
        // Se Supabase è vuoto, carica da Hive
        final localBoxes = boxBox.values.toList();
        for (var box in localBoxes) {
          final data = {
            'name': box.name,
            'notes': box.notes,
            'capacity': box.capacity,
          };
          final result = await supabase.from('boxes').insert(data).select();
          box.supabaseId = result[0]['id'];
          box.synced = true;
          await box.save();
        }
        // Ricarica da Supabase
        final response2 = await supabase.from('boxes').select('*').order('name');
        _boxes = List<Map<String, dynamic>>.from(response2);
      }
    } catch (e) {
      print('❌ Errore caricamento box: $e');
      // Fallback: carica da Hive
      _boxes = boxBox.values.map((b) => {
        'id': b.supabaseId ?? 'local',
        'name': b.name,
        'notes': b.notes,
        'capacity': b.capacity,
      }).toList();
    }
    setState(() => _isLoading = false);
  }

  void _showAddBoxDialog([KennelBox? boxToEdit]) async {
    final isEditing = boxToEdit != null;
    final nameController = TextEditingController(text: boxToEdit?.name ?? '');
    final notesController = TextEditingController(text: boxToEdit?.notes ?? '');
    final capacityController = TextEditingController(
      text: boxToEdit?.capacity.toString() ?? '2',
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Modifica box' : 'Nuovo box'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nome / Numero *'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: capacityController,
                decoration: const InputDecoration(
                  labelText: 'Capienza massima (n. cani)',
                  hintText: '2',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'Note (taglia, posizione...)'),
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
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Il nome è obbligatorio')),
                );
                return;
              }
              final capacity = int.tryParse(capacityController.text.trim()) ?? 2;
              if (capacity < 1) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('La capienza deve essere almeno 1')),
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
      ),
    );

    if (result == true) {
      setState(() => _isLoading = true);
      try {
        final capacity = int.tryParse(capacityController.text.trim()) ?? 2;
        final data = {
          'name': nameController.text.trim(),
          'notes': notesController.text.trim().isEmpty ? null : notesController.text.trim(),
          'capacity': capacity,
        };

        if (isEditing && boxToEdit != null && boxToEdit.supabaseId != null) {
          // 🔥 AGGIORNA SU SUPABASE
          await supabase.from('boxes').update(data).match({'id': boxToEdit.supabaseId!});
          boxToEdit.name = data['name']!;
          boxToEdit.notes = data['notes'];
          boxToEdit.capacity = data['capacity']!;
          boxToEdit.synced = true;
          await boxToEdit.save();
        } else {
          // 🔥 SALVA DIRETTAMENTE SU SUPABASE
          final result = await supabase.from('boxes').insert(data).select();
          final supabaseId = result[0]['id'];
          
          // Salva anche in Hive come backup
          final box = KennelBox(
            supabaseId: supabaseId,
            name: data['name']!,
            notes: data['notes'],
            capacity: data['capacity']!,
            synced: true,
          );
          await boxBox.add(box);
        }
        
        await _loadBoxes();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Box salvato su cloud!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Errore: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _deleteBox(Map<String, dynamic> box) async {
    final supabaseId = box['id'];
    if (supabaseId == null || supabaseId.toString().startsWith('local')) {
      // Se non ha supabaseId, elimina solo da Hive
      final localBox = boxBox.values.firstWhere(
        (b) => b.supabaseId == supabaseId,
        orElse: () => KennelBox(name: ''),
      );
      if (localBox.name.isNotEmpty) await localBox.delete();
      await _loadBoxes();
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Elimina box'),
        content: Text('Eliminare ${box['name']}? (eliminato anche dal cloud)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await supabase.from('boxes').delete().match({'id': supabaseId});
                final localBox = boxBox.values.firstWhere(
                  (b) => b.supabaseId == supabaseId,
                  orElse: () => KennelBox(name: ''),
                );
                if (localBox.name.isNotEmpty) await localBox.delete();
                await _loadBoxes();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Box eliminato dal cloud')),
                );
                Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('❌ Errore: $e')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
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
        onPressed: _showAddBoxDialog,
        backgroundColor: Colors.brown,
        child: const Icon(Icons.add),
      ),
      body: _boxes.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text('Nessun box configurato'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _showAddBoxDialog,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.brown),
                    child: const Text('➕ Aggiungi box'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _boxes.length,
              itemBuilder: (context, index) {
                final box = _boxes[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.brown[100],
                      child: const Icon(Icons.inventory_2, color: Colors.brown),
                    ),
                    title: Text(box['name'] ?? ''),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (box['notes'] != null && box['notes'].toString().isNotEmpty)
                          Text(box['notes']),
                        Text(
                          'Capienza: ${box['capacity'] ?? 2} cane${(box['capacity'] ?? 2) > 1 ? 's' : ''}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () {
                            // Trova il box in Hive per la modifica
                            final localBox = boxBox.values.firstWhere(
                              (b) => b.supabaseId == box['id'],
                              orElse: () => KennelBox(name: ''),
                            );
                            if (localBox.name.isNotEmpty) {
                              _showAddBoxDialog(localBox);
                            } else {
                              // Crea un oggetto temporaneo per la modifica
                              final tempBox = KennelBox(
                                supabaseId: box['id'],
                                name: box['name'] ?? '',
                                notes: box['notes'],
                                capacity: box['capacity'] ?? 2,
                              );
                              _showAddBoxDialog(tempBox);
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () => _deleteBox(box),
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
