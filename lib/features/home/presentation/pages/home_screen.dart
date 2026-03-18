import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Dance Eval',
                style: theme.textTheme.headlineLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'AI-powered movement evaluation',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.secondary,
                ),
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: () => context.go('/capture'),
                child: const Text('Start Dancing'),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.upload_file),
                label: const Text('Upload Video'),
                onPressed: () => context.go('/upload'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.secondary,
                  side: BorderSide(color: theme.colorScheme.secondary),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
