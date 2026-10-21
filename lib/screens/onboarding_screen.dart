import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import 'main_shell.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int page = 0;

  void next() {
    final last = 2;
    if (page < last) {
      setState(() => page++);
    } else {
      _done();
    }
  }

  void _done() {
    context.read<AppState>().updateSettings(
        context.read<AppState>().settings.copyWith(onboarded: true));
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pages = [
      _Page(
        icon: Icons.lightbulb_rounded,
        title: 'Bienvenue dans NabuInvent AI',
        subtitle:
            'Ton agent inventeur, bricoleur et créatif, toujours prêt à '
            'transformer une idée en projet concret.',
      ),
      _Page(
        icon: Icons.engineering_rounded,
        title: 'Conçois sans limite',
        subtitle:
            'Décris un problème ou un besoin. L\'IA locale ou le cloud te propose '
            'des inventions, des plans détaillés et des évaluations.',
      ),
      _Page(
        icon: Icons.build_rounded,
        title: 'Passe à l\'action',
        subtitle:
            'Étapes pas à pas, matériaux, coût et sécurité : passe de l\'idée '
            'au prototype en toute confiance.',
      ),
    ];
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
            children: [
              Expanded(
                child: PageView(
                  controller: PageController(viewportFraction: 0.99),
                  physics: const NeverScrollableScrollPhysics(),
                  children: pages,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < pages.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: i == page ? 22 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: i == page
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  TextButton(
                    onPressed: _done,
                    child: const Text('Passer'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: next,
                    icon: Icon(page == 2 ? Icons.check : Icons.arrow_forward),
                    label: Text(page == 2 ? 'C\'est parti' : 'Suivant'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _Page({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
          ),
          child: Icon(icon, size: 52, color: theme.colorScheme.primary),
        ),
        const SizedBox(height: 34),
        Text(title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        Text(subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant, height: 1.35)),
      ],
    );
  }
}