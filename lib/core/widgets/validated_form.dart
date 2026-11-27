import 'package:flutter/material.dart';

/// Shared form-level validation controller.
///
/// Keeps validation silent (`AutovalidateMode.disabled`) until the user first
/// attempts to submit the form, then switches to
/// `AutovalidateMode.onUserInteraction` so errors clear or update as the user
/// corrects invalid fields.
class ValidatedFormController {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  bool _hasSubmitted = false;

  bool get hasSubmitted => _hasSubmitted;

  AutovalidateMode get autovalidateMode => _hasSubmitted
      ? AutovalidateMode.onUserInteraction
      : AutovalidateMode.disabled;

  /// Marks the form as submitted (calling [onFirstSubmit] only once) and
  /// triggers [FormState.validate].
  bool validate(VoidCallback onFirstSubmit) {
    if (!_hasSubmitted) {
      _hasSubmitted = true;
      onFirstSubmit();
    }
    return formKey.currentState?.validate() ?? false;
  }

  /// Resets submission state and clears any displayed field errors.
  void reset() {
    _hasSubmitted = false;
    formKey.currentState?.reset();
  }
}
