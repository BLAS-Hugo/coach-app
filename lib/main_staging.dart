import 'package:coach_app/app/app.dart';
import 'package:coach_app/bootstrap.dart';

Future<void> main() async {
  await bootstrap(() => const App());
}
