import 'dart:developer';

import 'package:get/get.dart';
import 'package:path/path.dart' as path;
import "package:collection/collection.dart";

import 'package:file_browser/filesystem_interface.dart';

typedef SelectionCallback = void Function(FileSystemEntry entry, bool selected);

class FileBrowserController extends GetxController {
  // file system
  final FileSystemInterface fs;

  // file system root folder entries
  get roots => _roots;
  final List<FileSystemEntryStat> _roots = <FileSystemEntryStat>[];
  // parent directory of our root folders, if any
  get rootPathsSet => _rootPathsSet;
  final _rootPathsSet = <String>{};

  // current directory within root
  final currentDir = Rx<FileSystemEntry>(FileSystemEntry.blank());

  // list and selection options
  final showDirectoriesFirst = RxBool(true);
  final showFileExtensions = RxList<String>([]);
  final allowMultiSelection = RxBool(false);

  // selection changes
  final selectedEntries = RxSet<FileSystemEntry>({});
  final SelectionCallback? onSelectionUpdate;

  FileBrowserController({required this.fs, this.onSelectionUpdate});

  // sorted and possibly filtered entries of the current directory
  Future<List<FileSystemEntryStat>> fetchDirectoryEntries() async {
    // root entry
    if (isRootEntry(currentDir.value)) {
      return roots;
    }
    // fetch entries for current dir
    final contents = await fs.listContents(currentDir.value);
    // apply filters
    if (showFileExtensions.isNotEmpty) {
      contents.retainWhere((element) {
        if (element.entry.isDirectory) {
          return true;
        }
        for (var filter in showFileExtensions) {
          if (element.entry.path.toLowerCase().endsWith(filter.toLowerCase())) {
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

  void toggleSelect(FileSystemEntry entry) {
    final contains = selectedEntries.contains(entry);
    if (contains) {
      selectedEntries.remove(entry);
    } else {
      if (!allowMultiSelection.value) {
        selectedEntries.assign(entry);
      } else {
        selectedEntries.add(entry);
      }
    }
    if (onSelectionUpdate != null) {
      onSelectionUpdate!(entry, !contains);
    }
  }

  void updateRoots(List<FileSystemEntryStat> rootFolderEntries) {
    _roots.assignAll(rootFolderEntries);
    _rootPathsSet.clear();
    for (final entry in rootFolderEntries) {
      final parent = path.dirname(entry.entry.path);
      // On Linux, parent of '/' is '/' , which poses a problem since we have
      // a fake root. To deal with this, we don't add '/' to rootPathsSet
      if (parent != '/') {
        _rootPathsSet.add(parent);
      }
    }
  }

  bool isRootEntry(FileSystemEntry entry) {
    return entry.path == '';
  }
}
