import 'package:get/get.dart';
import 'package:path/path.dart' as path;
import "package:collection/collection.dart";

import 'package:file_browser/filesystem_interface.dart';

typedef SelectionCallback = Future<void> Function(
    FileSystemEntry entry, bool selected);

class FileBrowserController extends GetxController {
  // file root and entries
  final FileSystemInterface fs;
  List<FileSystemEntryStat> roots = List<FileSystemEntryStat>.empty();
  final rootPathsSet = <String>{};

  // options
  final currentDir = Rx<FileSystemEntry>(FileSystemEntry.blank());
  final showDirectoriesFirst = RxBool(false);
  final showFileExtensions = RxList([]);

  // selection changes
  SelectionCallback? onSelectionUpdate;
  final selected = RxSet<FileSystemEntry>({});

  FileBrowserController({required this.fs, this.onSelectionUpdate});

  Future<List<FileSystemEntryStat>> sortedListing(FileSystemEntry entry) async {
    if (isRootEntry(entry)) {
      // Root entry
      return roots;
    }
    // fetch entries
    final contents = await fs.listContents(entry);
    // apply filters
    if (showFileExtensions.isNotEmpty) {
      contents.retainWhere((element) {
        for (var filter in showFileExtensions) {
          if (element.entry.isDirectory ||
              element.entry.path.toLowerCase().endsWith(filter.toLowerCase())) {
            return true;
          }
        }
        return false;
      });
    }
    // apply sorting
    contents.sort((a, b) {
      if (showDirectoriesFirst.value) {
        // We need to put dirs first
        if (a.entry.isDirectory && !b.entry.isDirectory) {
          return -1;
        } else if (!a.entry.isDirectory && b.entry.isDirectory) {
          return 1;
        }
      }
      return compareAsciiLowerCaseNatural(a.entry.name, b.entry.name);
    });
    return contents;
  }

  void toggleSelect(FileSystemEntry entry) async {
    final contains = selected.contains(entry);
    if (contains) {
      selected.remove(entry);
    } else {
      selected.add(entry);
    }
    if (onSelectionUpdate != null) {
      await onSelectionUpdate!(entry, !contains);
    }
  }

  void updateRoots(List<FileSystemEntryStat> roots) {
    this.roots = roots;
    rootPathsSet.clear();
    for (var entry in roots) {
      final parent = path.dirname(entry.entry.path);
      // On Linux, parent of '/' is '/', which poses a problem since we have a fake root
      // To deal with this, we don't add '/' to rootPathsSet
      if (parent != '/') {
        rootPathsSet.add(parent);
      }
    }
  }

  bool isRootEntry(FileSystemEntry entry) {
    return entry.path == '';
  }
}
