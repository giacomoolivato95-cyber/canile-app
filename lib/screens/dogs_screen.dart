import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/dog.dart';

class DogsScreen extends StatefulWidget {
  const DogsScreen({super.key});

  @override
  State<DogsScreen> createState() => _DogsScreenState();
}

class _DogsScreenState extends State<DogsScreen> {
  final Box<Dog> dogBox = Hive.box<Dog>('dogs');

  void _showAddDogDialog([Dog? dogToEdit]) async {
    final isEditing = dogToEdit != null;
    final nameController = TextEditingController(text: dogToEdit?.name ?? '');
    final ownerController = TextEditingController(text: dogToEdit?.owner ?? '');
    final phoneController = TextEditingController(text: dogToEdit?.phone ?? '');
    final notesController = TextEditingController(text: dogToEdit?.notes ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Modifica cane' : 'Nuovo cane'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nome *'),
              ),
              TextField(
                controller: ownerController,
                decoration: const InputDecoration(labelText: 'Proprietario'),
              ),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Telefono'),
                keyboardType: TextInputType.phone,
              ),
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
      if (isEditing) {
        dogToEdit!.name = nameController.text.trim();
        dogToEdit.owner = ownerController.text.trim();
        dogToEdit.phone = phoneController.text.trim();
        dogToEdit.notes = notesController.text.trim();
        dogToEdit.save();
      } else {
        final dog = Dog(
          name: nameController.text.trim(),
          owner: ownerController.text.trim(),
          phone: phoneController.text.trim(),
          notes: notesController.text.trim(),
          synced: false,
        );
        dogBox.add(dog);
      }
      setState(() {});
    }
  }

  void _deleteDog(Dog dog) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Elimina cane'),
        content: Text('Eliminare ${dog.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () {
              dog.delete();
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
        onPressed: _showAddDogDialog,
        backgroundColor: Colors.brown,
        child: const Icon(Icons.add),
      ),
      body: dogBox.values.isEmpty
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
              itemCount: dogBox.values.length,
              itemBuilder: (context, index) {
                final dog = dogBox.values.toList()[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.brown[100],
                      child: Text(
                        dog.name[0].toUpperCase(),
                        style: TextStyle(color: Colors.brown[800]),
                      ),
                    ),
                    title: Text(dog.name),
                    subtitle: Text(
                      '${dog.owner ?? 'Proprietario non indicato'}${dog.phone != null ? ' • ${dog.phone}' : ''}',
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