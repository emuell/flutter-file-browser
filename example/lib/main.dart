import 'dart:io';
import 'dart:convert';

import 'package:file_browser/controllers/file_browser.dart';
import 'package:file_browser/file_browser.dart';
import 'package:file_browser/filesystem_interface.dart';
import 'package:file_browser/list_view.dart';
import 'package:file_browser/local_filesystem.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';

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

  Demo({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: checkAndRequestPermission(fs),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final data = snapshot.data as List<FileSystemEntryStat>?;
          if (data != null) {
            final controller = FileBrowserController(fs: fs);
            controller.updateRoots(data);
            controller.showDirectoriesFirst(true);
            const style = ListViewStyle(
              thumbnailPadding: 4,
              thumbnailSize: 22,
              padding: EdgeInsets.all(8),
              textStyle: TextStyle(fontWeight: FontWeight.w400, fontSize: 13),
              infoTextStyle:
                  TextStyle(fontWeight: FontWeight.w200, fontSize: 11),
            );
            return FileBrowser(controller: controller, style: style);
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
