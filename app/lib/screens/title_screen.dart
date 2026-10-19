import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/common.dart';
import '../widgets/desert.dart';

enum _Mode { title, signIn, signUp }

/// The "MOOD DIARY" splash, reworked: big chunky logo with a sticker, then sign in / sign up.
class TitleScreen extends StatefulWidget {
  const TitleScreen({super.key});

  @override
  State<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends State<TitleScreen> {
  _Mode mode = _Mode.title;
  final email = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();
  String avatar = 'sun';
  bool busy = false;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    name.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    setState(() => busy = true);
    final state = context.read<AppState>();
    await guard(context, () async {
      if (mode == _Mode.signIn) {
        await state.signIn(email.text, password.text);
      } else {
        await state.signUp(email.text, password.text, name.text, avatar);
      }
    });
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: DesertBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Column(
                  children: [
                    const _Logo(),
                    const SizedBox(height: 36),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: mode == _Mode.title ? _buttons() : _form(),
                    ),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buttons() {
    return Column(
      key: const ValueKey('buttons'),
      children: [
        ChunkyButton(label: 'Sign in', onPressed: () => setState(() => mode = _Mode.signIn)),
        const SizedBox(height: 16),
        ChunkyButton(label: 'Sign up', filled: false, onPressed: () => setState(() => mode = _Mode.signUp)),
      ],
    );
  }

  Widget _form() {
    final signUp = mode == _Mode.signUp;
    return CreamCard(
      key: ValueKey(mode),
      padding: const EdgeInsets.all(18),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(signUp ? 'Create your hero' : 'Welcome back, adventurer',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 14),
            if (signUp) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final s in AvatarStyle.values)
                    GestureDetector(
                      onTap: () => setState(() => avatar = s.name),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: avatar == s.name ? Desert.orange : Colors.transparent, width: 3),
                        ),
                        child: AvatarFace(s.name, size: 36),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(controller: name, decoration: const InputDecoration(hintText: 'Hero name')),
              const SizedBox(height: 10),
            ],
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(hintText: 'Email'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: password,
              obscureText: true,
              autofillHints: [signUp ? AutofillHints.newPassword : AutofillHints.password],
              decoration: InputDecoration(hintText: signUp ? 'Password (8+ characters)' : 'Password'),
              onSubmitted: (_) => submit(),
            ),
            const SizedBox(height: 18),
            ChunkyButton(label: signUp ? 'Begin quest' : 'Enter', busy: busy, onPressed: submit),
            TextButton(
              onPressed: () => setState(() => mode = _Mode.title),
              child: const Text('Back', style: TextStyle(color: Desert.inkSoft, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    const shadow = [Shadow(color: Desert.outline, offset: Offset(0, 4))];
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Column(
          children: [
            Text('LIFE',
                style: TextStyle(fontSize: 76, height: 0.95, fontWeight: FontWeight.w900, color: Colors.white, shadows: shadow)),
            Text('RPG',
                style: TextStyle(fontSize: 76, height: 0.95, fontWeight: FontWeight.w900, color: Colors.white, shadows: shadow)),
          ],
        ),
        Positioned(
          left: -26,
          top: -24,
          child: Transform.rotate(
            angle: -0.18,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Desert.orange,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Text('real life',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic)),
            ),
          ),
        ),
      ],
    );
  }
}
