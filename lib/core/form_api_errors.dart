import '../forms/entity_form.dart';
import 'api_exceptions.dart';

FormResult apiFormResult(Object error, Map<String, String> fieldLabels) {
  if (error is ValidationException) {
    for (final entry in error.errors.entries) {
      final label = fieldLabels[entry.key];
      if (label != null) {
        return FormResult(
          values: const {},
          errorField: label,
          errorMessage: entry.value,
        );
      }
    }
    return FormResult(values: const {}, errorMessage: error.message);
  }

  return FormResult(values: const {}, errorMessage: errorText(error));
}
