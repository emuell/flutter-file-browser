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
            child: Container(
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
  final FileSystemEntry rootEntry;

  const ListViewLayout({
    Key? key,
    required this.controller,
    required this.rootEntry,
    this.listStyle = const ListViewStyle(),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: controller.sortedListing(rootEntry),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final data = snapshot.data as List<FileSystemEntryStat>;
            final showParentEntry = !controller.isRootEntry(rootEntry);
            return ListView.separated(
              shrinkWrap: true,
              itemCount: data.length + (showParentEntry ? 1 : 0),
              padding: EdgeInsets.zero,
              itemBuilder: (context, index) {
                FileSystemEntryStat stats;
                bool showInfo = true;
                if (showParentEntry && index == 0) {
                  showInfo = false;
                  var parentPath = path.dirname(rootEntry.path);
                  // Check if this is root. If it is, then we end up with root again
                  parentPath = parentPath == rootEntry.path ? '' : parentPath;
                  final parentEntry = FileSystemEntry(
                      name: '..',
                      isDirectory: true,
                      path: parentPath,
                      relativePath: path.dirname(rootEntry.relativePath));
                  stats = FileSystemEntryStat(
                      entry: parentEntry, lastModified: 0, size: 0, mode: 0);
                } else {
                  final idx = index - (showParentEntry ? 1 : 0);
                  stats = data[idx];
                  showInfo = !controller.roots.contains(stats);
                }
                return Obx(() {
                  final listItem = InkWell(
                    splashColor: controller.selected.isEmpty
                        ? Theme.of(context).highlightColor
                        : Colors.transparent,
                    onTap: () {
                      if (stats.entry.isDirectory) {
                        if (showParentEntry &&
                            index == 0 &&
                            controller.rootPathsSet
                                .contains(stats.entry.path)) {
                          controller.currentDir.value = FileSystemEntry.blank();
                        } else if (stats.entry.isDirectory) {
                          controller.currentDir.value = stats.entry;
                        }
                      } else {
                        controller.toggleSelect(stats.entry);
                      }
                    },
                    onLongPress: () {
                      controller.toggleSelect(stats.entry);
                    },
                    child: Container(
                      color: controller.selected.contains(stats.entry)
                          ? Theme.of(context).highlightColor
                          : Colors.transparent,
                      margin: EdgeInsets.zero,
                      padding: EdgeInsets.zero,
                      child: ListViewEntry(
                          fs: controller.fs,
                          entry: stats,
                          style: listStyle,
                          showInfo: showInfo),
                    ),
                  );
                  if (!stats.entry.isDirectory) {
                    return Draggable<FileSystemEntry>(
                      data: stats.entry.isDirectory ? null : stats.entry,
                      feedbackOffset: const Offset(0, 10),
                      feedback: Text(
                        stats.entry.name,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      child: listItem,
                    );
                  } else {
                    return listItem;
                  }
                });
              },
              separatorBuilder: (context, index) => const Divider(height: 1.0),
            );
          } else {
            return Container();
          }
        });
  }
}
