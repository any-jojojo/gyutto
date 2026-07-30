import 'package:cloud_functions/cloud_functions.dart';

class FirebaseFunctionsService {
  FirebaseFunctionsService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<Map<String, dynamic>> call(
    String name,
    Map<String, dynamic> parameters,
  ) async {
    final callable = _functions.httpsCallable(name);
    final result = await callable.call<Map<String, dynamic>>(parameters);

    return result.data;
  }
}
