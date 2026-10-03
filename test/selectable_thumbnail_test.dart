import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immich_geotagger/widgets/photo_location_widgets.dart';

void main() {
  testWidgets('whole photo and indicator both toggle selection',
      (tester) async {
    var selected = false;
    final changes = <bool>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(builder: (context, setState) {
          return SelectableThumbnail(
            label: 'camera.jpg',
            selected: selected,
            onChanged: (value) {
              changes.add(value);
              setState(() => selected = value);
            },
            child: const SizedBox(width: 96, height: 96),
          );
        }),
      ),
    ));

    final photo = find.byType(SelectableThumbnail);
    final origin = tester.getTopLeft(photo);
    await tester.tapAt(origin + const Offset(8, 88));
    await tester.pumpAndSettle();
    expect(selected, isTrue);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);

    await tester.tapAt(origin + const Offset(78, 18));
    await tester.pumpAndSettle();
    expect(selected, isFalse);
    expect(changes, [true, false]);
    expect(find.byIcon(Icons.check_rounded), findsNothing);
  });

  testWidgets('screen readers receive filename and selection state',
      (tester) async {
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);
    var selected = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
            builder: (context, setState) => SelectableThumbnail(
                  label: 'camera.jpg',
                  selected: selected,
                  onChanged: (value) => setState(() => selected = value),
                  child: const SizedBox(width: 96, height: 96),
                )),
      ),
    ));

    final photo = find.byType(SelectableThumbnail);
    expect(
      tester.getSemantics(photo),
      containsSemantics(
        label: 'camera.jpg',
        isButton: true,
        hasCheckedState: true,
        isChecked: false,
        hasTapAction: true,
      ),
    );
    await tester.tap(photo);
    await tester.pumpAndSettle();
    expect(tester.getSemantics(photo), containsSemantics(isChecked: true));
  });
}
