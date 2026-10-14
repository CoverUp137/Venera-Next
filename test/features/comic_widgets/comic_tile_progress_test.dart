import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/features/comic_source/comic_source.dart';
import 'package:venera_next/features/comic_widgets/comic_widgets.dart';
import 'package:venera_next/foundation/appdata.dart';

void main() {
  testWidgets('chapter progress badge shows read chapter and total chapters', (
    tester,
  ) async {
    const comic = Comic(
      'Cat Eye',
      '',
      'cat-eye',
      null,
      null,
      '',
      'test-source',
      null,
      null,
    );
    final oldDisplayMode = appdata.settings['comicDisplayMode'];
    final oldFavoriteStatus = appdata.settings['showFavoriteStatusOnTile'];
    final oldHistoryStatus = appdata.settings['showHistoryStatusOnTile'];
    final oldUpdateStatus = appdata.settings['showUpdateStatusOnTile'];
    appdata.settings['comicDisplayMode'] = 'brief';
    appdata.settings['showFavoriteStatusOnTile'] = false;
    appdata.settings['showHistoryStatusOnTile'] = false;
    appdata.settings['showUpdateStatusOnTile'] = false;
    addTearDown(() {
      appdata.settings['comicDisplayMode'] = oldDisplayMode;
      appdata.settings['showFavoriteStatusOnTile'] = oldFavoriteStatus;
      appdata.settings['showHistoryStatusOnTile'] = oldHistoryStatus;
      appdata.settings['showUpdateStatusOnTile'] = oldUpdateStatus;
    });

    var state = const ComicTileState(chapterIndex: 78, chapterTotal: 343);
    configureComicWidgets(tileStateResolver: (_) => state);
    addTearDown(configureComicWidgets);

    Widget tile() {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 120,
              height: 180,
              child: ComicTile(comic: comic),
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(tile());
    await tester.pump();
    expect(find.text('78/343'), findsOneWidget);

    // 没记过目录长度（老记录、没打开过详情页）时不画角标，也不拿别的数字凑
    state = const ComicTileState(chapterIndex: 78);
    await tester.pumpWidget(tile());
    await tester.pump();
    expect(find.text('78/343'), findsNothing);

    // 只有总数、还没读到（ep 缺失）时同样不画
    state = const ComicTileState(chapterTotal: 343);
    await tester.pumpWidget(tile());
    await tester.pump();
    expect(find.textContaining('/343'), findsNothing);
  });
}
