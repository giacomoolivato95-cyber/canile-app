import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/kennel_box.dart';

class BoxesScreen extends StatefulWidget {
  const BoxesScreen({super.key});

  @override
  State<BoxesScreen> createState() => _BoxesScreenState();
}

class _BoxesScreenState extends State<BoxesScreen> {
  final Box<KennelBox> boxBox = Hive.box<KennelBox>('kennel_boxes');

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
            onPressed: () {
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
      final capacity = int.tryParse(capacityController.text.trim()) ?? 2;
      if (isEditing) {
        boxToEdit!.name = nameController.text.trim();
        boxToEdit.notes = notesController.text.trim();
        boxToEdit.capacity = capacity;
        boxToEdit.save();
      } else {
        final box = KennelBox(
          name: nameController.text.trim(),
          notes: notesController.text.trim(),
          capacity: capacity,
          synced: false,
        );
        boxBox.add(box);
      }
      setState(() {});
    }
  }

  void _deleteBox(KennelBox box) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Elimina box'),
        content: Text('Eliminare ${box.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () {
              box.delete();
              setState(() {});
              Navigator.pop(context);
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
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddBoxDialog,
        backgroundColor: Colors.brown,
        child: const Icon(Icons.add),
      ),
      body: boxBox.values.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Nessun box configurato',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _showAddBoxDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.brown,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('➕ Aggiungi box'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: boxBox.values.length,
              itemBuilder: (context, index) {
                final box = boxBox.values.toList()[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.brown[100],
                      child: const Icon(Icons.inventory_2, color: Colors.brown),
                    ),
                    title: Text(box.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (box.notes != null && box.notes!.isNotEmpty)
                          Text(box.notes!),
                        Text(
                          'Capienza: ${box.capacity} cane${box.capacity > 1 ? 's' : ''}',
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
                          onPressed: () => _showAddBoxDialog(box),
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