import 'package:flutter/material.dart';
import 'package:kids_church_mobile/models/models.dart';
import 'package:kids_church_mobile/state/app_controller.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.initializing) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        Widget page;
        if (!controller.isConfigured) {
          page = ServerSetupScreen(controller: controller);
        } else if (!controller.isAuthenticated) {
          page = LoginScreen(controller: controller);
        } else if (controller.selectedSession == null) {
          page = SessionScreen(controller: controller);
        } else {
          page = AttendanceScreen(controller: controller);
        }

        return Stack(
          children: [
            page,
            if (controller.busy)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x33000000),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        );
      },
    );
  }
}

class ServerSetupScreen extends StatefulWidget {
  const ServerSetupScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<ServerSetupScreen> createState() => _ServerSetupScreenState();
}

class _ServerSetupScreenState extends State<ServerSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _url = TextEditingController();

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connect Kids Church')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Icon(Icons.church_outlined, size: 72, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 20),
            Text('Connect to the test server', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text(
              'Paste the Apps Script web-app URL ending in /exec. The app will verify it before saving.',
            ),
            const SizedBox(height: 24),
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _url,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Apps Script deployment URL',
                  hintText: 'https://script.google.com/macros/s/.../exec',
                ),
                validator: (value) => (value ?? '').trim().isEmpty ? 'Enter the deployment URL.' : null,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: widget.controller.busy
                  ? null
                  : () {
                      if (_formKey.currentState?.validate() != true) return;
                      widget.controller.configureServer(_url.text);
                    },
              icon: const Icon(Icons.link),
              label: const Text('Test connection'),
            ),
            ErrorPanel(controller: widget.controller),
          ],
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _hidePassword = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kids Church')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.church, size: 72, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 20),
                    Text('Volunteer sign in', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (value) => (value ?? '').trim().contains('@') ? null : 'Enter your email.',
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _password,
                      obscureText: _hidePassword,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _hidePassword = !_hidePassword),
                          icon: Icon(_hidePassword ? Icons.visibility : Icons.visibility_off),
                        ),
                      ),
                      validator: (value) => (value ?? '').isEmpty ? 'Enter your password.' : null,
                    ),
                    const SizedBox(height: 18),
                    FilledButton(onPressed: widget.controller.busy ? null : _submit, child: const Text('Sign in')),
                    ErrorPanel(controller: widget.controller),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    widget.controller.login(_email.text, _password.text);
  }
}

class SessionScreen extends StatelessWidget {
  const SessionScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose a service'),
        actions: [
          IconButton(onPressed: controller.refreshSessions, icon: const Icon(Icons.refresh), tooltip: 'Refresh'),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') controller.logout();
              if (value == 'server') controller.disconnectServer();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'logout', child: Text('Sign out')),
              PopupMenuItem(value: 'server', child: Text('Change server')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await controller.refreshSessions();
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Text(
                  'Signed in as ${controller.volunteer?.name ?? ''}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              ErrorPanel(controller: controller),
              if (controller.pendingCount > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: ListTile(
                      leading: const Icon(Icons.cloud_off),
                      title: Text('${controller.pendingCount} attendance changes are waiting to sync'),
                      trailing: TextButton(onPressed: controller.flushPending, child: const Text('Retry')),
                    ),
                  ),
                ),
              if (controller.sessions.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('No active service sessions are available.')),
                ),
              for (final session in controller.sessions)
                Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Text(session.slot.isEmpty ? '?' : session.slot)),
                    title: Text(session.label.isEmpty ? '${session.date} ${session.slot}' : session.label),
                    subtitle: Text([session.track, session.name].where((item) => item.isNotEmpty).join(' • ')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => controller.selectSession(session),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class AttendanceScreen extends StatelessWidget {
  const AttendanceScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final session = controller.selectedSession!;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(onPressed: controller.leaveAttendance, icon: const Icon(Icons.arrow_back)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Attendance'),
            Text(session.label, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
        actions: [
          if (controller.syncing)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(onPressed: controller.flushPending, icon: const Icon(Icons.sync), tooltip: 'Sync'),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Row(
                children: [
                  Expanded(child: _CountCard(label: 'Present', value: controller.presentCount.toString())),
                  const SizedBox(width: 10),
                  Expanded(child: _CountCard(label: 'Pending', value: controller.pendingCount.toString())),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: TextField(
                onChanged: controller.setSearchQuery,
                decoration: const InputDecoration(
                  hintText: 'Search children',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
              ),
            ),
            ErrorPanel(controller: controller),
            Expanded(
              child: RefreshIndicator(
                onRefresh: controller.onAppResumed,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: controller.visibleChildren.length,
                  itemBuilder: (context, index) {
                    final child = controller.visibleChildren[index];
                    final present = controller.presentByChildId[child.childId] == true;
                    final pending = controller.childHasPending(child.childId);
                    return Card(
                      child: ListTile(
                        onTap: () => _showDetails(context, child),
                        leading: _ChildAvatar(child: child),
                        title: Text(child.fullName),
                        subtitle: Row(
                          children: [
                            if (child.age.isNotEmpty) Text('Age ${child.age}'),
                            if (child.hasMedicalInfo || child.hasOtherInfo) ...[
                              const SizedBox(width: 8),
                              Icon(Icons.info_outline, size: 17, color: Theme.of(context).colorScheme.error),
                            ],
                            if (pending) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.cloud_upload_outlined, size: 17),
                              const SizedBox(width: 3),
                              const Text('Pending'),
                            ],
                          ],
                        ),
                        trailing: Switch(
                          value: present,
                          onChanged: (value) => controller.toggleAttendance(child, value),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetails(BuildContext context, ChildSummary child) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: FutureBuilder<ChildDetails?>(
            future: controller.loadChildDetails(child.childId),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const SizedBox(height: 220, child: Center(child: CircularProgressIndicator()));
              }
              final details = snapshot.data;
              if (details == null) {
                return const SizedBox(height: 180, child: Center(child: Text('Could not load child details.')));
              }
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(details.fullName, style: Theme.of(context).textTheme.headlineSmall),
                    if (details.age.isNotEmpty) Text('Age ${details.age}'),
                    const Divider(height: 28),
                    _DetailSection(title: 'Medical information', value: details.medicalInfo),
                    _DetailSection(title: 'Other important information', value: details.otherInfo),
                    _ContactTile(label: 'Parent A', contact: details.parentA),
                    _ContactTile(label: 'Parent B', contact: details.parentB),
                    for (final guardian in details.additionalGuardians)
                      _ContactTile(label: 'Additional guardian', contact: guardian),
                    const SizedBox(height: 12),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class ErrorPanel extends StatelessWidget {
  const ErrorPanel({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.errorMessage.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Material(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          leading: const Icon(Icons.error_outline),
          title: Text(controller.errorMessage),
          trailing: IconButton(onPressed: controller.clearError, icon: const Icon(Icons.close)),
        ),
      ),
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text(label), Text(value, style: Theme.of(context).textTheme.titleLarge)],
        ),
      ),
    );
  }
}

class _ChildAvatar extends StatelessWidget {
  const _ChildAvatar({required this.child});

  final ChildSummary child;

  @override
  Widget build(BuildContext context) {
    final fallback = CircleAvatar(child: Text(child.firstName.isEmpty ? '?' : child.firstName[0].toUpperCase()));
    if (child.photoUrl.isEmpty) return fallback;
    return CircleAvatar(
      foregroundImage: NetworkImage(child.photoUrl),
      onForegroundImageError: (_, __) {},
      child: Text(child.firstName.isEmpty ? '?' : child.firstName[0].toUpperCase()),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 3),
          Text(value),
        ],
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.label, required this.contact});

  final String label;
  final GuardianContact contact;

  @override
  Widget build(BuildContext context) {
    if (contact.name.isEmpty && contact.phone.isEmpty) return const SizedBox.shrink();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.contact_phone_outlined),
      title: Text(contact.name.isEmpty ? label : contact.name),
      subtitle: Text([label, contact.phone].where((item) => item.isNotEmpty).join(' • ')),
    );
  }
}
