import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/features/reader/reader_page.dart';
import 'package:venera_next/foundation/comic_type.dart';
import 'package:venera_next/foundation/log.dart';

void main() {
  test('a completed replacement releases an unfinished animation', () async {
    final controller = _Controller();
    final reader = _Location()..imageViewController = controller;
    reader.toPage(150);
    reader.toPage(200);
    controller.animations[1].complete();
    await pumpEventQueue();
    expect(reader.isPageAnimating, isFalse);
    reader.toPage(250);
    controller.animations[0].complete();
    await pumpEventQueue();
    expect(reader.isPageAnimating, isTrue);
    controller.animations[2].complete();
    await pumpEventQueue();
    expect(reader.isPageAnimating, isFalse);
  });

  test(
    'direct navigation cancels animation state and preserves destination',
    () async {
      final controller = _Controller();
      final reader = _Location()..imageViewController = controller;
      reader.toPage(150);
      reader.toPage(200, animated: false);
      expect(reader.isPageAnimating, isFalse);
      expect(controller.destination, 200);
      controller.animations.single.complete();
      await pumpEventQueue();
      expect(reader.page, 200);
      expect(reader.isPageAnimating, isFalse);
    },
  );

  for (final synchronous in [false, true]) {
    test(
      'failed animation releases input (synchronous=$synchronous)',
      () async {
        Log.isMuted = true;
        try {
          final controller = _Controller()..throwSynchronously = synchronous;
          final reader = _Location()..imageViewController = controller;
          reader.toPage(200);
          if (!synchronous) {
            controller.animations.single.completeError(
              StateError('interrupted'),
            );
          }
          await pumpEventQueue();
          expect(reader.isPageAnimating, isFalse);
        } finally {
          Log.isMuted = false;
          Log.clear();
        }
      },
    );
  }
}

class _Location with ReaderLocation {
  @override
  int get maxPage => 300;
  @override
  int get totalPages => 300;
  @override
  int get maxChapter => 1;
  @override
  bool get isLoading => false;
  @override
  String get cid => 'book';
  @override
  ComicType get type => ComicType.local;
  @override
  bool enablePageAnimation(String cid, ComicType type) => true;
  @override
  void update() {}
  @override
  void onPageChanged() {}
}

class _Controller implements ReaderImageViewController {
  final animations = <Completer<void>>[];
  bool throwSynchronously = false;
  int? destination;

  @override
  Future<void> animateToPage(int page) {
    if (throwSynchronously) throw StateError('interrupted');
    final animation = Completer<void>();
    animations.add(animation);
    return animation.future;
  }

  @override
  void toPage(int page) => destination = page;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
