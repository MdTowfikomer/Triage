import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:triage_flutter/contacts/favorite_contacts_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'starts empty and resolves user-saved aliases deterministically',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repository = FavoriteContactsRepository(
        await SharedPreferences.getInstance(),
      );

      expect(repository.getAll(), isEmpty);
      expect(repository.resolve('ami'), isNull);

      await repository.save(
        const FavoriteContact(
          displayName: 'Nani',
          phoneNumber: '+911234567890',
          aliases: ['grandma', 'nani amma'],
        ),
      );
      expect(repository.resolve('nani amma')?.phoneNumber, '+911234567890');
    },
  );

  test(
    'exact name wins over a similar name and duplicate numbers collapse',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repository = FavoriteContactsRepository(
        await SharedPreferences.getInstance(),
      );
      await repository.save(
        const FavoriteContact(
          displayName: 'Faizaan',
          phoneNumber: '9959808388',
        ),
      );
      await repository.save(
        const FavoriteContact(
          displayName: 'Faizaan copy',
          phoneNumber: '+919959808388',
        ),
      );
      expect(repository.getAll(), hasLength(1));
      await repository.save(
        const FavoriteContact(
          displayName: 'Faizaan Khan',
          phoneNumber: '9959808399',
        ),
      );
      expect(repository.resolve('Faizaan copy')?.phoneNumber, '9959808388');
      expect(
        repository.chooseFromReply('second', repository.getAll())?.phoneNumber,
        '9959808399',
      );
      expect(
        repository
            .chooseFromReply('Faizaan copy', repository.getAll())
            ?.phoneNumber,
        '9959808388',
      );
    },
  );

  test('different numbers with identical names remain distinct', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = FavoriteContactsRepository(
      await SharedPreferences.getInstance(),
    );
    await repository.save(
      const FavoriteContact(displayName: 'Faizaan', phoneNumber: '1111111111'),
    );
    await repository.save(
      const FavoriteContact(displayName: 'Faizaan', phoneNumber: '2222222222'),
    );
    expect(repository.findMatches('Faizaan'), hasLength(2));
    expect(
      repository.chooseFromReply('first', repository.getAll())?.phoneNumber,
      '1111111111',
    );
    await repository.delete('Faizaan', phoneNumber: '1111111111');
    expect(repository.getAll().single.phoneNumber, '2222222222');
  });
}
