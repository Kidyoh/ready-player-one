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
                    const SizedBox(height: 14),
                    const Text(
                      'Workouts, reading and code earn XP.\nYour goals become quests.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    const SizedBox(height: 30),
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
                style: display(22)),
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
    const shadow = [Shadow(color: Desert.outline, offset: Offset(0, 5))];
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          children: [
            Text('LIFE', style: display(84, color: Colors.white, weight: FontWeight.w700, shadows: shadow).copyWith(height: 0.9)),
            Text('RPG', style: display(84, color: Desert.mustard, weight: FontWeight.w700, shadows: shadow).copyWith(height: 0.9)),
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
              child: Text('real life', style: display(18, color: Colors.white, weight: FontWeight.w600)),
            ),
          ),
        ),
      ],
    );
  }
}
