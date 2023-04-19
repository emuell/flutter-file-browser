import 'package:flutter/material.dart';
import 'package:filesize/filesize.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;

import 'package:file_browser/controllers/file_browser.dart';
import 'package:file_browser/filesystem_interface.dart';

class ListViewStyle {
  final double thumbnailPadding;
  final double thumbnailSize;
  final EdgeInsets padding;
  final TextStyle infoTextStyle;
  final TextStyle textStyle;

  const ListViewStyle({
    this.thumbnailPadding = 10.0,
    this.thumbnailSize = 32.0,
    this.padding = const EdgeInsets.all(8),
    this.textStyle = const TextStyle(
      fontSize: 14.0,
      color: Colors.black,
    ),
    this.infoTextStyle = const TextStyle(
      fontSize: 12,
      color: Colors.grey,
    ),
  });
}

class ListThumbnail extends StatelessWidget {
  final FileSystemInterface fs;
  final FileSystemEntry entry;
  final double height;

  const ListThumbnail({
    Key? key,
    required this.fs,
    required this.entry,
    this.height = 36,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: fs.getThumbnail(entry, height: height),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final thumbnail = snapshot.data as Widget;
          return thumbnail;
        } else {
          return Container();
        }
      },
    );
  }
}

class ListViewEntry extends StatelessWidget {
  final FileSystemInterface fs;
  final FileSystemEntryStat entry;
  final ListViewStyle style;
  final bool showInfo;

  const ListViewEntry(
      {Key? key,
      required this.fs,
      required this.entry,
      required this.style,
      this.showInfo = true})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: style.padding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
              margin: EdgeInsets.all(style.thumbnailPadding),
              alignment: Alignment.center,
              width: style.thumbnailSize,
              height: style.thumbnailSize,
              child: ListThumbnail(
                fs: fs,
                entry: entry.entry,
                height: style.thumbnailSize,
              )),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    entry.entry.name,
                    style: style.textStyle,
                  ),
                ),
                if (showInfo)
                  Flexible(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          filesize(entry.size, 0),
                          style: style.infoTextStyle,
                        ),
                        SizedBox(
                          width: 2 * (style.infoTextStyle.wordSpacing ?? 8.0),
                        ),
                        Text(
                          DateFormat('yyyy-MM-dd').format(
                            DateTime.fromMillisecondsSinceEpoch(
                                entry.lastModified),
                          ),
                          style: style.infoTextStyle,
                        )
                      ],
                    ),
                  )
              ],
            ),
          )
        ],
      ),
    );
  }
}

class ListViewLayout extends StatelessWidget {
  final FileBrowserController controller;
  final ListViewStyle listStyle;
  final entries = RxList<FileSystemEntryStat>([]);
  final entriesError = RxString('');

  ListViewLayout({
    Key? key,
    required this.controller,
    this.listStyle = const ListViewStyle(),
  }) : super(key: key) {
    // fetch directory listing
    controller.fetchDirectoryEntries().then((value) {
      entries.assignAll(value);
    }).catchError((e) {
      entriesError.value = 'Failed to fetch files: ${e.toString()}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      () {
        // show fetch errors
        if (entriesError.isNotEmpty) {
          return Center(
            child: Text(
              entriesError.value,
              style: listStyle.textStyle
                  .copyWith(color: Theme.of(context).colorScheme.error),
            ),
          );
        }
        // show contents
        final rootDirectory = controller.currentDir.value;
        final showParentEntry = !controller.isRootEntry(rootDirectory);
        return ListView.separated(
          shrinkWrap: true,
          itemCount: entries.length + (showParentEntry ? 1 : 0),
          padding: EdgeInsets.zero,
          itemBuilder: (context, index) {
            bool showInfo = true;
            FileSystemEntryStat itemfileStat;
            if (showParentEntry && index == 0) {
              showInfo = false;
              var parentPath = path.dirname(rootDirectory.path);
              // Check if this is root. If it is, then we end up with root again
              parentPath = parentPath == rootDirectory.path ? '' : parentPath;
              final parentEntry = FileSystemEntry(
                  name: '..',
                  isDirectory: true,
                  path: parentPath,
                  relativePath: path.dirname(rootDirectory.relativePath));
              itemfileStat = FileSystemEntryStat(
                  entry: parentEntry, lastModified: 0, size: 0, mode: 0);
            } else {
              final idx = index - (showParentEntry ? 1 : 0);
              itemfileStat = entries[idx];
              showInfo = !controller.roots.contains(itemfileStat);
            }
            return Obx(
              () {
                final listItem = InkWell(
                  key: Key(itemfileStat.entry.path),
                  splashColor: controller.selectedEntries.isEmpty
                      ? Theme.of(context).highlightColor
                      : Colors.transparent,
                  onTap: () {
                    if (itemfileStat.entry.isDirectory) {
                      if (showParentEntry &&
                          index == 0 &&
                          controller.rootPathsSet
                              .contains(itemfileStat.entry.path)) {
                        controller.currentDir.value = FileSystemEntry.blank();
                      } else if (itemfileStat.entry.isDirectory) {
                        controller.currentDir.value = itemfileStat.entry;
                      }
                    } else {
                      controller.toggleSelect(itemfileStat.entry);
                    }
                  },
                  onLongPress: () {
                    controller.toggleSelect(itemfileStat.entry);
                  },
                  child: Container(
                    color:
                        controller.selectedEntries.contains(itemfileStat.entry)
                            ? Theme.of(context).highlightColor
                            : Colors.transparent,
                    margin: EdgeInsets.zero,
                    padding: EdgeInsets.zero,
                    child: ListViewEntry(
                        fs: controller.fs,
                        entry: itemfileStat,
                        style: listStyle,
                        showInfo: showInfo),
                  ),
                );
                if (!itemfileStat.entry.isDirectory) {
                  return Draggable<FileSystemEntry>(
                    data: itemfileStat.entry.isDirectory
                        ? null
                        : itemfileStat.entry,
                    feedbackOffset: const Offset(0, 10),
                    feedback: Text(
                      itemfileStat.entry.name,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    child: listItem,
                  );
                } else {
                  return listItem;
                }
              },
            );
          },
          separatorBuilder: (context, index) => const Divider(height: 1.0),
        );
      },
    );
  }
}
