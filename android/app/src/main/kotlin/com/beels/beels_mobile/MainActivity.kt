package com.beels.beels_mobile

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (not FlutterActivity) is required by local_auth:
// the BiometricPrompt API only attaches to FragmentActivity subclasses.
class MainActivity: FlutterFragmentActivity()