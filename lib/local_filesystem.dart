import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:developer' as developer;

import 'package:chunked_stream/chunked_stream.dart';
import 'package:file_browser/semaphore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as image;
import 'package:path/path.dart' as path;

import 'package:file_browser/filesystem_interface.dart';

final _semaphore = Semaphore(max(Platform.numberOfProcessors - 1, 1));

class LocalFileSystem extends FileSystemInterface {
  @override
  Future<Widget> getThumbnail(FileSystemEntry entry,
      {double? width, double? height}) async {
    if (!entry.isDirectory) {
      final ext = path.extension(entry.name).toLowerCase();
      if (ext == '.png' || ext == '.jpg' || ext == '.jpeg') {
        await _semaphore.acquire();
        final bytes = await compute(getThumbnailFromFile,
            ComputeArguments(path: entry.path, width: width, height: height));
        _semaphore.release();
        return Image.memory(Uint8List.fromList(bytes), fit: BoxFit.contain);
      }
    }
    return super.getThumbnail(entry, width: width, height: height);
  }

  @override
  Future<FileSystemEntryStat> stat(FileSystemEntry entry) async {
    if (entry.isDirectory) {
      final stat = await Directory(entry.path).stat();
      return FileSystemEntryStat(
          entry: entry,
          lastModified: stat.modified.millisecondsSinceEpoch,
          size: stat.size,
          mode: stat.mode);
    } else {
      final stat = await File(entry.path).stat();
      return FileSystemEntryStat(
          entry: entry,
          lastModified: stat.modified.millisecondsSinceEpoch,
          size: stat.size,
          mode: stat.mode);
    }
  }

  @override
  Future<List<FileSystemEntryStat>> listContents(FileSystemEntry entry) async {
    var files = <FileSystemEntryStat>[];
    final dir = Directory(entry.path);
    await for (var file in dir.list(recursive: false)) {
      final name = path.basename(file.path);
      final relativePath = path.join(entry.relativePath, name);
      try {
        if (File(file.path).existsSync()) {
          files.add(await stat(FileEntry(
              name: name, path: file.path, relativePath: relativePath)));
        } else if (Directory(file.path).existsSync()) {
          files.add(await stat(FolderEntry(
              name: name, path: file.path, relativePath: relativePath)));
        }
      } catch (e) {
        // skip this file, warn and continue...
        developer.log('Failed to access file or directory: $e');
      }
    }
    return files;
  }

  @override
  Future<Stream<List<int>>> read(FileSystemEntry entry,
      {int bufferSize = 512}) async {
    final stream = bufferChunkedStream(File(entry.path).openRead(),
        bufferSize: bufferSize);
    return stream;
  }
}

FutureOr<List<int>> getThumbnailFromFile(ComputeArguments args) async {
  final decodedImage = image.decodeImage(File(args.path).readAsBytesSync());
  if (decodedImage != null) {
    // Resize the image to a thumbnail (maintaining the aspect ratio).
    int? rw, rh;
    if (args.width != null) {
      rw = args.width!.round();
    }
    if (args.height != null) {
      rh = args.height!.round();
    }
    final thumbnail = image.copyResize(decodedImage, width: rw, height: rh);
    final bytes = image.encodePng(thumbnail);
    return bytes;
  } else {
    throw 'Error decoding image';
  }
}

class ComputeArguments {
  final String path;
  final double? width;
  final double? height;

  ComputeArguments(
      {required this.path, required this.width, required this.height});
}
