import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_web/web_only.dart' as web;
import '../../../shared/lib/cloud/api_client.dart';

/// Web: Google's own rendered button (the only way to receive an ID token).
class GoogleSignInButton extends StatefulWidget {
  final void Function(String idToken) onToken;
  final void Function(String message) onError;
  const GoogleSignInButton({super.key, required this.onToken, required this.onError});

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  late final GoogleSignIn _gs;
  StreamSubscription<GoogleSignInAccount?>? _sub;

  @override
  void initState() {
    super.initState();
    _gs = GoogleSignIn(scopes: const ['email'], clientId: CloudConfig.googleWebClientId);
    _sub = _gs.onCurrentUserChanged.listen((acct) async {
      if (acct == null) return;
      final token = (await acct.authentication).idToken;
      if (token != null) {
        widget.onToken(token);
      } else {
        widget.onError("Google didn't return a sign-in token. Try again.");
      }
    });
    // Initialises the plugin so the button can render (and resumes a live Google session).
    _gs.signInSilently();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Center(
        child: web.renderButton(
          configuration: web.GSIButtonConfiguration(
            type: web.GSIButtonType.standard,
            theme: web.GSIButtonTheme.outline,
            size: web.GSIButtonSize.large,
            text: web.GSIButtonText.continueWith,
            shape: web.GSIButtonShape.pill,
            minimumWidth: 342,
          ),
        ),
      ),
    );
  }
}
