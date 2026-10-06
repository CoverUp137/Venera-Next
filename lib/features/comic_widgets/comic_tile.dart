import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:venera_next/components/button.dart';
import 'package:venera_next/components/gesture.dart';
import 'package:venera_next/components/image.dart';
import 'package:venera_next/components/menu.dart';
import 'package:venera_next/components/message.dart';
import 'package:venera_next/components/select.dart';
import 'package:venera_next/features/comic_source/comic_source.dart';
import 'package:venera_next/foundation/app.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/foundation/context.dart';
import 'package:venera_next/foundation/extensions.dart';
import 'package:venera_next/foundation/translations.dart';
import 'package:venera_next/foundation/widget_utils.dart';

import 'rating.dart';

typedef ComicPageBuilder =
    Widget Function({
      required String id,
      required String sourceKey,
      String? cover,
      String? title,
      int? heroID,
    });

typedef AddComicFavoriteHandler = void Function(List<Comic> comics);
typedef ComicTileStateResolver = ComicTileState Function(Comic comic);
typedef ComicTileImageProviderResolver = ImageProvider? Function(Comic comic);
typedef ComicWidgetListenerRegistrar = void Function(VoidCallback listener);
typedef ComicFavoriteDisplayStateResolver =
    ComicFavoriteDisplayState Function();

class ComicTileState {
  const ComicTileState({
    this.isFavorite = false,
    this.historyPage,
    this.historyMaxPage,
    this.readChapter,
    this.readChapterGroup,
    this.readChapterName,
    this.hasNewUpdate = false,
  });

  final bool isFavorite;
  final int? historyPage;
  final int? historyMaxPage;

  /// 读到的章节序号（1-based；分组漫画里是组内第几话）、所属章节组与章节名。
  /// 只在「在缩略图下显示话数」打开时才有值，画在封面图内部的下方。
  final int? readChapter;
  final int? readChapterGroup;
  final String? readChapterName;
  final bool hasNewUpdate;
}

class ComicFavoriteDisplayState {
  const ComicFavoriteDisplayState({
    this.isGallery = false,
    this.galleryColumns,
  });

  final bool isGallery;
  final int? galleryColumns;
}

ComicPageBuilder? _comicPageBuilder;

AddComicFavoriteHandler? _addComicFavoriteHandler;
ComicTileStateResolver? _comicTileStateResolver;
ComicTileImageProviderResolver? _comicTileImageProviderResolver;
ComicWidgetListenerRegistrar? _addComicWidgetStateListener;
ComicWidgetListenerRegistrar? _removeComicWidgetStateListener;
ComicFavoriteDisplayStateResolver? _comicFavoriteDisplayStateResolver;

void configureComicWidgets({
  ComicPageBuilder? comicPageBuilder,
  AddComicFavoriteHandler? addFavorite,
  ComicTileStateResolver? tileStateResolver,
  ComicTileImageProviderResolver? tileImageProviderResolver,
  ComicWidgetListenerRegistrar? addStateListener,
  ComicWidgetListenerRegistrar? removeStateListener,
  ComicFavoriteDisplayStateResolver? favoriteDisplayStateResolver,
}) {
  _comicPageBuilder = comicPageBuilder;
  _addComicFavoriteHandler = addFavorite;
  _comicTileStateResolver = tileStateResolver;
  _comicTileImageProviderResolver = tileImageProviderResolver;
  _addComicWidgetStateListener = addStateListener;
  _removeComicWidgetStateListener = removeStateListener;
  _comicFavoriteDisplayStateResolver = favoriteDisplayStateResolver;
}

void addComicWidgetStateListener(VoidCallback listener) {
  _addComicWidgetStateListener?.call(listener);
}

void removeComicWidgetStateListener(VoidCallback listener) {
  _removeComicWidgetStateListener?.call(listener);
}

ComicFavoriteDisplayState comicFavoriteDisplayState() {
  return _comicFavoriteDisplayStateResolver?.call() ??
      const ComicFavoriteDisplayState();
}

Widget _buildComicPage({
  required String id,
  required String sourceKey,
  String? cover,
  String? title,
  int? heroID,
}) {
  final builder =
      _comicPageBuilder ??
      (throw StateError("Comic page builder is not configured."));
  return builder(
    id: id,
    sourceKey: sourceKey,
    cover: cover,
    title: title,
    heroID: heroID,
  );
}

void _openComicPage({
  BuildContext? context,
  required String id,
  required String sourceKey,
  String? cover,
  String? title,
  int? heroID,
}) {
  final targetContext = context ?? App.mainNavigatorKey?.currentContext;
  targetContext?.to(
    () => _buildComicPage(
      id: id,
      sourceKey: sourceKey,
      cover: cover,
      title: title,
      heroID: heroID,
    ),
  );
}

void _addComicToFavorites(List<Comic> comics) {
  final handler =
      _addComicFavoriteHandler ??
      (throw StateError("Add comic favorite handler is not configured."));
  handler(comics);
}

ImageProvider? _findImageProvider(Comic comic) {
  return _comicTileImageProviderResolver?.call(comic);
}

ComicTileState _tileState(Comic comic) {
  return _comicTileStateResolver?.call(comic) ?? const ComicTileState();
}

Widget _buildUpdateBadge(BuildContext context, {double size = 24}) {
  return Container(
    height: size,
    width: size,
    color: Colors.deepOrange.shade700,
    child: Icon(Icons.update, size: size * 2 / 3, color: Colors.white),
  );
}

enum ComicTileDisplayMode { detailed, gallery }

class ComicTile extends StatelessWidget {
  const ComicTile({
    super.key,
    required this.comic,
    this.enableLongPressed = true,
    this.badge,
    this.menuOptions,
    this.onTap,
    this.onLongPressed,
    this.onBlocked,
    this.heroID,
    this.displayMode,
  });

  final Comic comic;

  final bool enableLongPressed;

  final String? badge;

  final List<MenuEntry>? menuOptions;

  final VoidCallback? onTap;

  final VoidCallback? onLongPressed;

  final VoidCallback? onBlocked;

  final int? heroID;

  final ComicTileDisplayMode? displayMode;

  void _onTap() {
    if (onTap != null) {
      onTap!();
      return;
    }
    _openComicPage(
      id: comic.id,
      sourceKey: comic.sourceKey,
      cover: comic.cover,
      title: comic.title,
      heroID: heroID,
    );
  }

  void _onLongPressed(context) {
    if (onLongPressed != null) {
      onLongPressed!();
      return;
    }
    onLongPress(context);
  }

  void onLongPress(BuildContext context) {
    var renderBox = context.findRenderObject() as RenderBox;
    var size = renderBox.size;
    var location = renderBox.localToGlobal(
      Offset((size.width - 242) / 2, size.height / 2),
    );
    showMenu(location, context);
  }

  void onSecondaryTap(TapDownDetails details, BuildContext context) {
    showMenu(details.globalPosition, context);
  }

  void showMenu(Offset location, BuildContext context) {
    showMenuX(App.rootContext, location, [
      MenuEntry(
        icon: Icons.chrome_reader_mode_outlined,
        text: 'Details'.tl,
        onClick: () {
          _openComicPage(
            id: comic.id,
            sourceKey: comic.sourceKey,
            cover: comic.cover,
            title: comic.title,
          );
        },
      ),
      MenuEntry(
        icon: Icons.copy,
        text: 'Copy Title'.tl,
        onClick: () {
          Clipboard.setData(ClipboardData(text: comic.title));
          App.rootContext.showMessage(message: 'Title copied'.tl);
        },
      ),
      MenuEntry(
        icon: Icons.stars_outlined,
        text: 'Add to favorites'.tl,
        onClick: () {
          _addComicToFavorites([comic]);
        },
      ),
      MenuEntry(
        icon: Icons.block,
        text: 'Block'.tl,
        onClick: () => block(context),
      ),
      ...?menuOptions,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final type = switch (displayMode) {
      ComicTileDisplayMode.detailed => 'detailed',
      ComicTileDisplayMode.gallery => 'gallery',
      null => appdata.settings['comicDisplayMode'],
    };

    final state = _tileState(comic);
    final chapterInfo = _readChapterInfo(state);

    Widget child = switch (type) {
      'detailed' => _buildDetailedMode(context, chapterInfo),
      'gallery' => _buildGalleryMode(context, chapterInfo),
      _ => _buildBriefMode(context, chapterInfo),
    };
    final isFavorite = state.isFavorite;
    final historyPage = state.historyPage == 0 ? 1 : state.historyPage;
    final hasUpdate = state.hasNewUpdate;

    if (!isFavorite && historyPage == null && !hasUpdate) {
      return child;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = type == 'gallery' && constraints.maxWidth < 88;
        final badgeSize = compact ? 18.0 : 24.0;
        return Stack(
          children: [
            Positioned.fill(child: child),
            Positioned(
              left: type == 'detailed'
                  ? 16
                  : compact
                  ? 4
                  : 6,
              top: compact ? 6 : 8,
              child: Container(
                height: badgeSize,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                ),
                clipBehavior: Clip.antiAlias,
                child: Row(
                  children: [
                    if (isFavorite)
                      Container(
                        height: badgeSize,
                        width: badgeSize,
                        color: Colors.green,
                        child: Icon(
                          Icons.bookmark_rounded,
                          size: badgeSize * 2 / 3,
                          color: Colors.white,
                        ),
                      ),
                    if (historyPage != null)
                      Container(
                        height: badgeSize,
                        color: Colors.blue.toOpacity(0.9),
                        constraints: BoxConstraints(minWidth: badgeSize),
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 2 : 4,
                        ),
                        child: CustomPaint(
                          painter: _ReadingHistoryPainter(
                            historyPage,
                            state.historyMaxPage,
                          ),
                        ),
                      ),
                    if (hasUpdate) _buildUpdateBadge(context, size: badgeSize),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildImage(BuildContext context, _ReadChapterInfo? chapterInfo) {
    var image = _findImageProvider(comic);
    if (image == null) {
      return const SizedBox();
    }
    Widget cover = AnimatedImage(
      image: image,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
    );
    if (chapterInfo == null) {
      return cover;
    }
    // 话数画在封面图内部的下方（左上角那个历史进度角标仍归
    // showHistoryStatusOnTile 管，两个开关互不影响）
    return LayoutBuilder(
      builder: (context, constraints) {
        final fontSize = constraints.maxWidth < 80
            ? 8.0
            : constraints.maxWidth < 150
            ? 10.0
            : 11.0;
        return Stack(
          children: [
            cover,
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(3, 1, 3, 2),
                color: Colors.black.toOpacity(0.55),
                child: _ChapterLabel(
                  number: chapterInfo.number,
                  name: chapterInfo.name,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: fontSize,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailedMode(
    BuildContext context,
    _ReadChapterInfo? chapterInfo,
  ) {
    return LayoutBuilder(
      builder: (context, constrains) {
        final height = constrains.maxHeight - 16;

        Widget image = Container(
          width: height * 0.68,
          height: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: context.colorScheme.outlineVariant,
                blurRadius: 1,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: _buildImage(context, chapterInfo),
        );

        if (heroID != null) {
          image = Hero(tag: "cover$heroID", child: image);
        }

        return ClickInkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _onTap,
          onLongPress: enableLongPressed ? () => _onLongPressed(context) : null,
          onSecondaryTapDown: (detail) => onSecondaryTap(detail, context),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 24, 8),
            child: Row(
              children: [
                image,
                SizedBox.fromSize(size: const Size(16, 5)),
                Expanded(
                  child: _ComicDescription(
                    title: comic.maxPage == null
                        ? comic.title.replaceAll("\n", "")
                        : "[${comic.maxPage}P]${comic.title.replaceAll("\n", "")}",
                    subtitle: comic.subtitle ?? '',
                    description: comic.description,
                    badge: badge ?? comic.language,
                    tags: comic.tags,
                    maxLines: 2,
                    enableTranslate:
                        ComicSource.find(
                          comic.sourceKey,
                        )?.enableTagsTranslate ??
                        false,
                    rating: comic.stars,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBriefMode(BuildContext context, _ReadChapterInfo? chapterInfo) {
    return LayoutBuilder(
      builder: (context, constraints) {
        Widget image = Container(
          decoration: BoxDecoration(
            color: context.colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.toOpacity(0.2),
                blurRadius: 2,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: _buildImage(context, chapterInfo),
        );

        if (heroID != null) {
          image = Hero(tag: "cover$heroID", child: image);
        }

        return ClickInkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: _onTap,
          onLongPress: enableLongPressed ? () => _onLongPressed(context) : null,
          onSecondaryTapDown: (detail) => onSecondaryTap(detail, context),
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(child: image),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: (() {
                        final subtitle = comic.subtitle
                            ?.replaceAll('\n', '')
                            .trim();
                        final text = comic.description.isNotEmpty
                            ? comic.description.split('|').join('\n')
                            : (subtitle?.isNotEmpty == true ? subtitle : null);
                        final fortSize = constraints.maxWidth < 80
                            ? 8.0
                            : constraints.maxWidth < 150
                            ? 10.0
                            : 12.0;

                        if (text == null) {
                          return const SizedBox();
                        }

                        var children = <Widget>[];
                        var lines = text.split('\n');
                        lines.removeWhere((e) => e.trim().isEmpty);
                        if (lines.length > 3) {
                          lines = lines.sublist(0, 3);
                        }
                        for (var line in lines) {
                          children.add(
                            Container(
                              margin: const EdgeInsets.fromLTRB(2, 0, 2, 2),
                              padding: constraints.maxWidth < 80
                                  ? const EdgeInsets.fromLTRB(3, 1, 3, 1)
                                  : constraints.maxWidth < 150
                                  ? const EdgeInsets.fromLTRB(4, 2, 4, 2)
                                  : const EdgeInsets.fromLTRB(5, 2, 5, 2),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.black.toOpacity(0.5),
                              ),
                              constraints: BoxConstraints(
                                maxWidth: constraints.maxWidth,
                              ),
                              child: Text(
                                line,
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: fortSize,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.right,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          );
                        }
                        return Padding(
                          // 封面底部那行话数占着位置，简介往上让一让
                          padding: EdgeInsets.only(
                            bottom: chapterInfo == null ? 0 : 16,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: children,
                          ),
                        );
                      })(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                child: Text(
                  comic.title.replaceAll('\n', ''),
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ).paddingHorizontal(6).paddingVertical(8),
        );
      },
    );
  }

  Widget _buildGalleryMode(
    BuildContext context,
    _ReadChapterInfo? chapterInfo,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 88;
        Widget image = Container(
          decoration: BoxDecoration(
            color: context.colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.toOpacity(0.16),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: _buildImage(context, chapterInfo),
        );

        if (heroID != null) {
          image = Hero(tag: 'cover$heroID', child: image);
        }

        return ClickInkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: _onTap,
          onLongPress: enableLongPressed ? () => _onLongPressed(context) : null,
          onSecondaryTapDown: (detail) => onSecondaryTap(detail, context),
          child: Padding(
            padding: compact
                ? const EdgeInsets.fromLTRB(4, 5, 4, 4)
                : const EdgeInsets.fromLTRB(6, 8, 6, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: image),
                SizedBox(height: compact ? 3 : 5),
                SizedBox(
                  height: compact ? 24 : 36,
                  child: Text(
                    comic.title.replaceAll('\n', ''),
                    maxLines: compact ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 10 : 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<String> _splitText(String text) {
    // split text by comma, brackets
    var words = <String>[];
    var buffer = StringBuffer();
    var inBracket = false;
    String? prevBracket;
    for (var i = 0; i < text.length; i++) {
      var c = text[i];
      if (c == '[' || c == '(') {
        if (inBracket) {
          buffer.write(c);
        } else {
          if (buffer.isNotEmpty) {
            words.add(buffer.toString().trim());
            buffer.clear();
          }
          inBracket = true;
          prevBracket = c;
        }
      } else if (c == ']' || c == ')') {
        if (prevBracket == '[' && c == ']' || prevBracket == '(' && c == ')') {
          if (buffer.isNotEmpty) {
            words.add(buffer.toString().trim());
            buffer.clear();
          }
          inBracket = false;
        } else {
          buffer.write(c);
        }
      } else if (c == ',') {
        if (inBracket) {
          buffer.write(c);
        } else {
          words.add(buffer.toString().trim());
          buffer.clear();
        }
      } else {
        buffer.write(c);
      }
    }
    if (buffer.isNotEmpty) {
      words.add(buffer.toString().trim());
    }
    words.removeWhere((element) => element == "");
    words = words.toSet().toList();
    return words;
  }

  void block(BuildContext comicTileContext) {
    showDialog(
      context: App.rootContext,
      builder: (context) {
        var words = <String>[];
        var all = <String>[];
        all.addAll(_splitText(comic.title));
        if (comic.subtitle != null && comic.subtitle != "") {
          all.add(comic.subtitle!);
        }
        all.addAll(comic.tags ?? []);
        return StatefulBuilder(
          builder: (context, setState) {
            return ContentDialog(
              title: 'Block'.tl,
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: math.min(400, context.height - 136),
                ),
                child: SingleChildScrollView(
                  child: Wrap(
                    runSpacing: 8,
                    spacing: 8,
                    children: [
                      for (var word in all)
                        OptionChip(
                          text: (comic.tags?.contains(word) ?? false)
                              ? word.translateTagIfNeed
                              : word,
                          isSelected: words.contains(word),
                          onTap: () {
                            setState(() {
                              if (!words.contains(word)) {
                                words.add(word);
                              } else {
                                words.remove(word);
                              }
                            });
                          },
                        ),
                    ],
                  ),
                ).paddingHorizontal(16),
              ),
              actions: [
                Button.filled(
                  onPressed: () {
                    context.pop();
                    for (var word in words) {
                      appdata.settings['blockedWords'].add(word);
                    }
                    appdata.saveData();
                    context.showMessage(message: 'Blocked'.tl);
                    onBlocked?.call();
                  },
                  child: Text('Block'.tl),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _ComicDescription extends StatelessWidget {
  const _ComicDescription({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.enableTranslate,
    this.badge,
    this.maxLines = 2,
    this.tags,
    this.rating,
  });

  final String title;
  final String subtitle;
  final String description;
  final String? badge;
  final List<String>? tags;
  final int maxLines;
  final bool enableTranslate;
  final double? rating;

  @override
  Widget build(BuildContext context) {
    if (tags != null) {
      tags!.removeWhere((element) => element.removeAllBlank == "");
      for (var s in tags!) {
        s = s.replaceAll("\n", " ");
      }
    }
    var enableTranslate =
        App.locale.languageCode == 'zh' && this.enableTranslate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title.trim(),
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14.0),
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          softWrap: true,
        ),
        if (subtitle != "")
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10.0,
              color: context.colorScheme.onSurface.toOpacity(0.7),
            ),
            maxLines: 1,
            softWrap: true,
            overflow: TextOverflow.ellipsis,
          ),
        const SizedBox(height: 4),
        if (tags != null && tags!.isNotEmpty)
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxHeight < 22) {
                  return Container();
                }
                int cnt = (constraints.maxHeight - 22).toInt() ~/ 25;
                return Container(
                  clipBehavior: Clip.antiAlias,
                  height: 21 + cnt * 24,
                  width: double.infinity,
                  decoration: const BoxDecoration(),
                  child: Wrap(
                    runAlignment: WrapAlignment.start,
                    clipBehavior: Clip.antiAlias,
                    crossAxisAlignment: WrapCrossAlignment.end,
                    spacing: 4,
                    runSpacing: 3,
                    children: [
                      for (var s in tags!)
                        Container(
                          height: 21,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          constraints: BoxConstraints(
                            maxWidth: constraints.maxWidth * 0.45,
                          ),
                          decoration: BoxDecoration(
                            color: s == "Unavailable"
                                ? context.colorScheme.errorContainer
                                : context.colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            widthFactor: 1,
                            child: Text(
                              enableTranslate
                                  ? TagsTranslation.translateTag(s)
                                  : s.split(':').last,
                              style: const TextStyle(fontSize: 12),
                              softWrap: true,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ),
                    ],
                  ),
                ).toAlign(Alignment.topCenter);
              },
            ),
          )
        else
          const Spacer(),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (rating != null) StarRating(value: rating!, size: 18),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 12.0),
                    maxLines: (tags == null || tags!.isEmpty) ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                ),
                child: Center(
                  child: Text(
                    "${badge![0].toUpperCase()}${badge!.substring(1).toLowerCase()}",
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// 封面上那行「读到哪」：话数（普通章节「56话」，分组漫画「第 2 组 3话」）加章节名。
/// 没读到（开关关着，或这本没有历史记录）返回 null，什么都不画。
_ReadChapterInfo? _readChapterInfo(ComicTileState state) {
  final chapter = state.readChapter;
  if (chapter == null || chapter < 1) {
    return null;
  }
  var number = "Ch. @ep".tlParams({"ep": chapter});
  final group = state.readChapterGroup;
  if (group != null) {
    number = "${"Group @group".tlParams({"group": group})} $number";
  }
  return _ReadChapterInfo(
    number: number,
    name: _cleanChapterName(state.readChapterName),
  );
}

/// 源给的章节名可能带换行/多余空白，压成一行。
String _cleanChapterName(String? name) {
  return name == null ? '' : name.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// 封面下方那行阅读进度的内容。
class _ReadChapterInfo {
  const _ReadChapterInfo({required this.number, required this.name});

  /// 话数（分组漫画带「第 N 组」前缀）。
  final String number;

  /// 章节名，拿不到时是空串。
  final String name;
}

/// 封面上那行「话数 章节名」：整行放得下就居中显示，
/// 放不下就让章节名横向滚动（话数固定不动）。
class _ChapterLabel extends StatelessWidget {
  const _ChapterLabel({
    required this.number,
    required this.name,
    required this.style,
  });

  final String number;
  final String name;
  final TextStyle style;

  static const double _gap = 6;

  double _widthOf(String text) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.width;
  }

  @override
  Widget build(BuildContext context) {
    if (name.isEmpty) {
      return Text(
        number,
        style: style,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final whole = '$number $name';
        if (!constraints.maxWidth.isFinite ||
            _widthOf(whole) <= constraints.maxWidth) {
          return Text(
            whole,
            style: style,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }
        return Row(
          children: [
            Text(number, style: style, maxLines: 1, softWrap: false),
            const SizedBox(width: _gap),
            Expanded(
              child: _ScrollingText(text: name, style: style),
            ),
          ],
        );
      },
    );
  }
}

/// 一行放不下的文字：横向循环滚动（跑马灯）。
/// 文字比可用宽度窄、或系统开了「减少动态效果」时，直接静态显示。
class _ScrollingText extends StatefulWidget {
  const _ScrollingText({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  State<_ScrollingText> createState() => _ScrollingTextState();
}

class _ScrollingTextState extends State<_ScrollingText>
    with SingleTickerProviderStateMixin {
  /// 两遍文字之间的间隔。
  static const double _gap = 36;

  /// 每秒滚动多少像素。
  static const double _speed = 24;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _textWidth(BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      maxLines: 1,
      textDirection: Directionality.of(context),
    )..layout();
    return painter.width;
  }

  void _startScrolling(double distance) {
    final ms = (distance / _speed * 1000).round().clamp(1000, 120000);
    _controller.duration = Duration(milliseconds: ms.toInt());
    if (_controller.isAnimating) {
      return;
    }
    // 在 build 里直接 repeat() 会在同一帧通知监听者，放到下一帧再起
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_controller.isAnimating) {
        _controller.repeat();
      }
    });
  }

  Widget _text({bool softWrap = true, int? maxLines, TextOverflow? overflow}) {
    return Text(
      widget.text,
      style: widget.style,
      maxLines: maxLines,
      softWrap: softWrap,
      overflow: overflow,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = _textWidth(context);
        final available = constraints.maxWidth;
        if (!available.isFinite ||
            width <= available ||
            MediaQuery.of(context).disableAnimations) {
          return ClipRect(
            child: _text(maxLines: 1, overflow: TextOverflow.clip),
          );
        }
        final distance = width + _gap;
        _startScrolling(distance);
        return ClipRect(
          child: OverflowBox(
            alignment: Alignment.centerLeft,
            maxWidth: double.infinity,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => Transform.translate(
                offset: Offset(-distance * _controller.value, 0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _text(softWrap: false),
                    const SizedBox(width: _gap),
                    _text(softWrap: false),
                    const SizedBox(width: _gap),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ReadingHistoryPainter extends CustomPainter {
  final int page;
  final int? maxPage;

  const _ReadingHistoryPainter(this.page, this.maxPage);

  @override
  void paint(Canvas canvas, Size size) {
    if (maxPage == null) {
      // 在中央绘制page
      final textPainter = TextPainter(
        text: TextSpan(
          text: "$page",
          style: TextStyle(fontSize: size.width * 0.8, color: Colors.white),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          (size.width - textPainter.width) / 2,
          (size.height - textPainter.height) / 2,
        ),
      );
    } else if (page == maxPage) {
      // 在中央绘制勾
      final paint = Paint()
        ..color = Colors.white
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(size.width * 0.2, size.height * 0.5),
        Offset(size.width * 0.45, size.height * 0.75),
        paint,
      );
      canvas.drawLine(
        Offset(size.width * 0.45, size.height * 0.75),
        Offset(size.width * 0.85, size.height * 0.3),
        paint,
      );
    } else {
      // 在左上角绘制page, 在右下角绘制maxPage
      final textPainter = TextPainter(
        text: TextSpan(
          text: "$page",
          style: TextStyle(fontSize: size.width * 0.8, color: Colors.white),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, const Offset(0, 0));
      final textPainter2 = TextPainter(
        text: TextSpan(
          text: "/$maxPage",
          style: TextStyle(fontSize: size.width * 0.5, color: Colors.white),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter2.layout();
      textPainter2.paint(
        canvas,
        Offset(
          size.width - textPainter2.width,
          size.height - textPainter2.height,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is! _ReadingHistoryPainter ||
        oldDelegate.page != page ||
        oldDelegate.maxPage != maxPage;
  }
}

class SimpleComicTile extends StatelessWidget {
  const SimpleComicTile({
    super.key,
    required this.comic,
    this.onTap,
    this.withTitle = false,
    this.heroID,
    this.gaplessPlayback = false,
  });

  final Comic comic;

  final void Function()? onTap;

  final bool withTitle;

  final int? heroID;

  final bool gaplessPlayback;

  @override
  Widget build(BuildContext context) {
    var image = _findImageProvider(comic);

    Widget child = image == null
        ? const SizedBox()
        : AnimatedImage(
            image: image,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
            gaplessPlayback: gaplessPlayback,
          );

    child = Container(
      width: 98,
      height: 136,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Theme.of(context).colorScheme.secondaryContainer,
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );

    if (_tileState(comic).hasNewUpdate) {
      child = Stack(
        children: [
          child,
          Positioned(
            left: 0,
            top: 0,
            child: Container(
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(
                  bottomRight: Radius.circular(4),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: _buildUpdateBadge(context),
            ),
          ),
        ],
      );
    }

    if (heroID != null) {
      child = Hero(tag: "cover$heroID", child: child);
    }

    child = AnimatedTapRegion(
      borderRadius: 8,
      onTap:
          onTap ??
          () {
            _openComicPage(
              context: context,
              id: comic.id,
              sourceKey: comic.sourceKey,
              cover: comic.cover,
              title: comic.title,
              heroID: heroID,
            );
          },
      child: child,
    );

    if (withTitle) {
      child = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          child,
          const SizedBox(height: 4),
          SizedBox(
            width: 92,
            child: Center(
              child: Text(
                comic.title.replaceAll('\n', ''),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      );
    }

    return child;
  }
}
