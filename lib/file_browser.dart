library file_browser;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:file_browser/controllers/file_browser.dart';
import 'package:file_browser/filesystem_interface.dart';
import 'package:file_browser/list_view.dart';
import 'package:file_browser/local_filesystem.dart';

class FileBrowser extends StatelessWidget {
  late final FileBrowserController controller;
  late final ListViewStyle style;

  FileBrowser({
    Key? key,
    List<FileSystemEntryStat>? roots,
    FileBrowserController? controller,
    ListViewStyle style = const ListViewStyle(),
  }) : super(key: key) {
    if (controller != null) {
      this.controller = controller;
    } else {
      if (roots == null) {
        throw 'Must specify roots or controller';
      }
      this.controller = FileBrowserController(fs: LocalFileSystem());
      this.controller.updateRoots(roots);
      this.controller.showDirectoriesFirst.value = true;
    }
    this.style = style;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return ListViewLayout(
        controller: controller,
        rootEntry: controller.currentDir.value,
        listStyle: style,
      );
    });
  }
}
