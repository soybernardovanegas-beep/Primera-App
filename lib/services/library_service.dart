import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:epubx/epubx.dart' show EpubReader;
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/book.dart';

class LibraryService {
  LibraryService(this._client);

  final SupabaseClient _client;

  Future<Directory> _booksDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'books'));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  File _localFileFor(Directory dir, String hash) =>
      File(p.join(dir.path, '$hash.epub'));

  /// Opens the system file picker, imports the chosen EPUB into the local
  /// library folder and syncs its metadata to Supabase. Books are matched
  /// across devices by content hash, so importing the same file on Android
  /// and Windows links them to a single library entry without ever
  /// uploading the file itself.
  Future<Book?> pickAndImportBook() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['epub'],
      withData: true,
    );
    final picked = result?.files.single;
    if (picked?.bytes == null) return null;

    final bytes = picked!.bytes!;
    final hash = sha256.convert(bytes).toString();

    final dir = await _booksDir();
    final localFile = _localFileFor(dir, hash);
    if (!localFile.existsSync()) {
      await localFile.writeAsBytes(bytes, flush: true);
    }

    final epubBookRef = await EpubReader.openBook(bytes);
    final title = epubBookRef.Title?.trim().isNotEmpty == true
        ? epubBookRef.Title!.trim()
        : p.basenameWithoutExtension(picked.name);
    final author = epubBookRef.Author?.trim();

    final userId = _client.auth.currentUser!.id;
    final row = await _client
        .from('books')
        .upsert(
          {
            'user_id': userId,
            'hash': hash,
            'title': title,
            'author': author,
          },
          onConflict: 'user_id,hash',
        )
        .select()
        .single();

    return Book.fromRow(row, localFile.path);
  }

  /// Fetches the synced library and resolves which entries already have a
  /// local file on this device.
  Future<List<Book>> fetchLibrary() async {
    final rows = await _client
        .from('books')
        .select()
        .order('added_at', ascending: false);

    final dir = await _booksDir();
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map((row) {
          final localFile = _localFileFor(dir, row['hash'] as String);
          final localPath = localFile.existsSync() ? localFile.path : '';
          return Book.fromRow(row, localPath);
        })
        .toList();
  }

  Future<void> deleteBook(Book book) async {
    await _client.from('books').delete().eq('id', book.id);
    if (book.availableLocally) {
      final file = File(book.localPath);
      if (file.existsSync()) {
        await file.delete();
      }
    }
  }
}
