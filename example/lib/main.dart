import 'dart:io';
import 'dart:convert';

import 'package:file_browser/controllers/file_browser.dart';
import 'package:file_browser/file_browser.dart';
import 'package:file_browser/filesystem_interface.dart';
import 'package:file_browser/list_view.dart';
import 'package:file_browser/local_filesystem.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';

const imageFileExtensions = ['.png', '.jpg', '.jpeg'];
const audioFileExtensions = ['.wav', '.mp3', '.flac', '.aif', '.aiff'];

FileSystemEntryStat? rootEntry;

void main() async {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FileBrowser Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Scaffold(
        appBar: AppBar(title: const Text('File Browser')),
        backgroundColor: Colors.white,
        body: Demo(),
      ),
    );
  }
}

class Demo extends StatelessWidget {
  final fs = LocalFileSystem();
  late final FileBrowserController controller;

  Demo({Key? key}) : super(key: key) {
    // create controller configure it
    controller = FileBrowserController(fs: fs);
    controller.allowMultiSelection.value = true;
    controller.showDirectoriesFirst.value = true;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<FileSystemEntryStat>?>(
      future: checkAndRequestPermission(fs),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final rootFolders = snapshot.data;
          if (rootFolders != null) {
            controller.updateRoots(rootFolders);
            final style = ListViewStyle(
              thumbnailPadding: 8,
              thumbnailSize: 32,
              padding: const EdgeInsets.all(8),
              textStyle: Theme.of(context).textTheme.bodyMedium!,
              infoTextStyle: Theme.of(context).textTheme.bodySmall!,
            );
            final browser = Expanded(
              child: FileBrowser(controller: controller, style: style),
            );
            const buttonSize = 22.0;
            final browserOptionsRow = Obx(
              () => Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.image,
                      size: buttonSize,
                    ),
                    splashRadius: buttonSize,
                    color: controller.showFileExtensions.toString() ==
                            imageFileExtensions.toString()
                        ? Theme.of(context).colorScheme.secondary
                        : null,
                    tooltip: 'Show image files only',
                    onPressed: () {
                      if (controller.showFileExtensions.toString() !=
                          imageFileExtensions.toString()) {
                        controller.showFileExtensions
                            .assignAll(imageFileExtensions);
                      } else {
                        controller.showFileExtensions.clear();
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.audio_file,
                      size: buttonSize,
                    ),
                    splashRadius: buttonSize,
                    color: controller.showFileExtensions.toString() ==
                            audioFileExtensions.toString()
                        ? Theme.of(context).colorScheme.secondary
                        : null,
                    tooltip: 'Show audio files only',
                    onPressed: () {
                      if (controller.showFileExtensions.toString() !=
                          audioFileExtensions.toString()) {
                        controller.showFileExtensions
                            .assignAll(audioFileExtensions);
                      } else {
                        controller.showFileExtensions.clear();
                      }
                    },
                  ),
                ],
              ),
            );
            return Column(
              children: [browser, browserOptionsRow],
            );
          }
        }
        return Container();
      },
    );
  }

  Future<List<FileSystemEntryStat>?> checkAndRequestPermission(
      LocalFileSystem fs) async {
    var entry = FileSystemEntry.blank();
    if (Platform.isWindows) {
      Future<Iterable<String>> getDrives() async => LineSplitter.split(
              (await Process.run('wmic', ['logicaldisk', 'get', 'caption'],
                      stdoutEncoding: const SystemEncoding()))
                  .stdout as String)
          .map((string) => string.trim())
          .where((string) => string.isNotEmpty)
          .skip(1);
      var drives = await getDrives();
      var driveEntries = await Future.wait(drives.map((path) async {
        final entry = FileSystemEntry(
            name: path, path: path, relativePath: path, isDirectory: true);
        try {
          return await fs.stat(entry);
        } catch (_) {
          return FileSystemEntryStat(
              entry: entry, lastModified: 0, size: 0, mode: 0);
        }
      }));
      return driveEntries;
    } else if (Platform.isLinux || Platform.isMacOS) {
      entry = FileSystemEntry(
          name: 'HOME', path: '/', relativePath: '/', isDirectory: true);
    } else if (Platform.isAndroid || Platform.isIOS) {
      var status = await Permission.storage.status;
      if (status.isDenied) {
        // We didn't ask for permission yet or the permission has been denied before but not permanently.
        status = await Permission.storage.request();
      }
      if (!status.isGranted) {
        return null;
      }
      await checkAndRequestManageStoragePermission();
      final directories = await getExternalStorageDirectories();
      final roots = await Future.wait(directories!.map((dir) {
        final name = path.basename(dir.path);
        final relativePath = name;
        final dirPath = dir.path;
        final entry = FileSystemEntry(
            name: name,
            path: dirPath,
            relativePath: relativePath,
            isDirectory: true);
        return fs.stat(entry);
      }));
      return roots;
    }
    rootEntry = await fs.stat(entry);
    return List.from([rootEntry]);
  }

  Future<bool> checkAndRequestManageStoragePermission() async {
    var status = await Permission.manageExternalStorage.status;
    if (status.isDenied) {
      status = await Permission.manageExternalStorage.request();
    }
    return status.isGranted;
  }
}
