import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
	const SettingsPage({super.key});

	@override
	State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
	static const LinearGradient _backgroundGradient = LinearGradient(
		begin: Alignment.topLeft,
		end: Alignment.bottomRight,
		colors: [Color(0xFF0A1929), Color(0xFF1C3A5E)],
	);

	bool _isDefaultDialer = true;
	bool _recordCalls = false;
	bool _darkMode = true;

	void _toggleDefaultDialer(bool value) {
		setState(() => _isDefaultDialer = value);
	}

	void _toggleRecordCalls(bool value) {
		setState(() => _recordCalls = value);
	}

	void _toggleDarkMode(bool value) {
		setState(() => _darkMode = value);
	}

	void _showAboutDialog() {
		showDialog<void>(
			context: context,
			builder: (BuildContext context) {
				return AlertDialog(
					backgroundColor: const Color(0xFF0F2236),
					shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
					title: const Text(
						'About Dialer Pro',
						style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
					),
					content: const Text(
						'Dialer Pro is your modern calling companion with powerful contact management, call history insights, and recording tools.',
						style: TextStyle(color: Color(0xFFB0BEC5), height: 1.5),
					),
					actions: [
						TextButton(
							onPressed: () => Navigator.of(context).pop(),
							child: const Text('Close'),
						),
					],
				);
			},
		);
	}

	@override
	Widget build(BuildContext context) {
		final TextTheme textTheme = Theme.of(context).textTheme;

		return Scaffold(
			backgroundColor: Colors.transparent,
			body: Container(
				decoration: const BoxDecoration(gradient: _backgroundGradient),
				child: SafeArea(
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							Padding(
								padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										Text(
											'Settings',
											style: textTheme.headlineSmall?.copyWith(
												color: Colors.white,
												fontWeight: FontWeight.bold,
											),
										),
										const SizedBox(height: 8),
										Text(
											'Personalize your dialer experience and manage preferences',
											style: textTheme.bodyMedium?.copyWith(
												color: const Color(0xFF90B0CB),
												height: 1.4,
											),
										),
									],
								),
							),
							Expanded(
								child: ListView(
									padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
									children: [
										_SettingsSwitchTile(
											title: 'Set as Default Dialer',
											subtitle: 'Use Dialer Pro for all incoming and outgoing calls',
											value: _isDefaultDialer,
											onChanged: _toggleDefaultDialer,
										),
										const SizedBox(height: 16),
										_SettingsSwitchTile(
											title: 'Record Calls',
											subtitle: 'Automatically capture and store call recordings securely',
											value: _recordCalls,
											onChanged: _toggleRecordCalls,
										),
										const SizedBox(height: 16),
										_SettingsSwitchTile(
											title: 'Dark Mode',
											subtitle: 'Keep the experience consistent with deep blue gradients',
											value: _darkMode,
											onChanged: _toggleDarkMode,
										),
										const SizedBox(height: 24),
										_SettingsActionTile(
											title: 'About App',
											subtitle: 'Version 1.0.0 · Learn more about the product',
											onTap: _showAboutDialog,
										),
									],
								),
							),
						],
					),
				),
			),
		);
	}
}

class _SettingsSwitchTile extends StatelessWidget {
	const _SettingsSwitchTile({
		required this.title,
		required this.subtitle,
		required this.value,
		required this.onChanged,
	});

	final String title;
	final String subtitle;
	final bool value;
	final ValueChanged<bool> onChanged;

	@override
	Widget build(BuildContext context) {
		final TextTheme textTheme = Theme.of(context).textTheme;

		return Container(
			padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
			decoration: BoxDecoration(
				color: Colors.white.withOpacity(0.08),
				borderRadius: BorderRadius.circular(20),
				border: Border.all(color: Colors.white.withOpacity(0.08)),
				boxShadow: [
					BoxShadow(
						color: Colors.black.withOpacity(0.22),
						blurRadius: 18,
						offset: const Offset(0, 12),
					),
				],
			),
			child: Row(
				children: [
					Expanded(
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.start,
							children: [
								Text(
									title,
									style: textTheme.titleMedium?.copyWith(
										color: Colors.white,
										fontWeight: FontWeight.w700,
									),
								),
								const SizedBox(height: 6),
								Text(
									subtitle,
									style: textTheme.bodySmall?.copyWith(
										color: const Color(0xFF90B0CB),
										height: 1.4,
									),
								),
							],
						),
					),
					const SizedBox(width: 12),
					Switch.adaptive(
						value: value,
						onChanged: onChanged,
						activeColor: Colors.white,
						activeTrackColor: const Color(0xFF42A5F5),
						inactiveTrackColor: Colors.white.withOpacity(0.24),
					),
				],
			),
		);
	}
}

class _SettingsActionTile extends StatelessWidget {
	const _SettingsActionTile({
		required this.title,
		required this.subtitle,
		required this.onTap,
	});

	final String title;
	final String subtitle;
	final VoidCallback onTap;

	@override
	Widget build(BuildContext context) {
		final TextTheme textTheme = Theme.of(context).textTheme;

		return InkWell(
			borderRadius: BorderRadius.circular(20),
			onTap: onTap,
			child: Container(
				padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
				decoration: BoxDecoration(
					color: Colors.white.withOpacity(0.08),
					borderRadius: BorderRadius.circular(20),
					border: Border.all(color: Colors.white.withOpacity(0.08)),
					boxShadow: [
						BoxShadow(
							color: Colors.black.withOpacity(0.22),
							blurRadius: 18,
							offset: const Offset(0, 12),
						),
					],
				),
				child: Row(
					children: [
						Expanded(
							child: Column(
								crossAxisAlignment: CrossAxisAlignment.start,
								children: [
									Text(
										title,
										style: textTheme.titleMedium?.copyWith(
											color: Colors.white,
											fontWeight: FontWeight.w700,
										),
									),
									const SizedBox(height: 6),
									Text(
										subtitle,
										style: textTheme.bodySmall?.copyWith(
											color: const Color(0xFF90B0CB),
											height: 1.4,
										),
									),
								],
							),
						),
						const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 18),
					],
				),
			),
		);
	}
}
