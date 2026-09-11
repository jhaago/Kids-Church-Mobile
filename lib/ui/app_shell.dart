import 'package:flutter/material.dart';
import 'package:kids_church_mobile/models/models.dart';
import 'package:kids_church_mobile/state/app_controller.dart';
import 'package:kids_church_mobile/ui/kids_church_theme.dart';
import 'package:url_launcher/url_launcher.dart';

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
              if (value == 'logout') {
                controller.logout();
              }
              if (value == 'server') {
                controller.disconnectServer();
              }
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

  static const _tabs = [
    (AppTab.attendance, 'Attendance', Icons.fact_check_outlined),
    (AppTab.roster, 'Roster', Icons.assignment_outlined),
    (AppTab.schedule, 'Schedule', Icons.calendar_month_outlined),
    (AppTab.kids, 'Kids', Icons.person_outline),
    (AppTab.resources, 'Resources', Icons.list_alt_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final session = controller.selectedSession!;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 12,
        title: OutlinedButton.icon(
          onPressed: controller.leaveAttendance,
          icon: const Icon(Icons.calendar_month_outlined, size: 20),
          label: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 205),
            child: Text(session.label, overflow: TextOverflow.ellipsis),
          ),
        ),
        actions: [
          IconButton(onPressed: controller.refreshCurrentTab, icon: const Icon(Icons.refresh), tooltip: 'Refresh'),
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle_outlined),
            onSelected: (value) {
              if (value == 'profile') {
                _showProfile(context);
              }
              if (value == 'logout') {
                controller.logout();
              }
              if (value == 'server') {
                controller.disconnectServer();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'profile', child: Text('My Profile')),
              PopupMenuItem(value: 'logout', child: Text('Logout')),
              PopupMenuItem(value: 'server', child: Text('Change server')),
            ],
          ),
        ],
      ),
      body: SafeArea(child: _tabBody()),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabs.indexWhere((entry) => entry.$1 == controller.selectedTab),
        onDestinationSelected: (index) => controller.selectTab(_tabs[index].$1),
        destinations: [
          for (final entry in _tabs) NavigationDestination(icon: Icon(entry.$3), label: entry.$2),
        ],
      ),
    );
  }

  Widget _tabBody() => switch (controller.selectedTab) {
        AppTab.attendance => _ChildrenPage(controller: controller, presentOnly: false),
        AppTab.kids => _ChildrenPage(controller: controller, presentOnly: true),
        AppTab.roster => _RosterPage(controller: controller),
        AppTab.schedule => _SchedulePage(controller: controller),
        AppTab.resources => _ResourcesPage(controller: controller),
      };

  void _showProfile(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => FutureBuilder<VolunteerProfile?>(
        future: controller.loadProfile(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox(height: 260, child: Center(child: CircularProgressIndicator()));
          }
          final profile = snapshot.data;
          if (profile == null) {
            return const SizedBox(height: 200, child: Center(child: Text('Could not load profile.')));
          }
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircleAvatar(
                  radius: 42,
                  foregroundImage: profile.photoUrl.isEmpty ? null : NetworkImage(profile.photoUrl),
                  child: Text(_initials(profile.volunteer.name), style: const TextStyle(fontSize: 24)),
                ),
                const SizedBox(height: 14),
                Text(profile.volunteer.name, style: Theme.of(context).textTheme.headlineSmall),
                Text(profile.volunteer.email, style: const TextStyle(color: KidsChurchColors.muted)),
                const SizedBox(height: 6),
                _Badge(profile.volunteer.role.isEmpty ? 'Volunteer' : profile.volunteer.role),
                const SizedBox(height: 20),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class _ChildrenPage extends StatelessWidget {
  const _ChildrenPage({required this.controller, required this.presentOnly});
  final AppController controller;
  final bool presentOnly;

  @override
  Widget build(BuildContext context) {
    final children = presentOnly ? controller.presentChildren : controller.visibleChildren;
    return RefreshIndicator(
      onRefresh: controller.refreshCurrentTab,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
        children: [
          Row(children: [
            Expanded(child: Text(presentOnly ? 'Kids' : 'Attendance', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800))),
            _Badge('Present: ${controller.presentCount}'),
            if (controller.pendingCount > 0) ...[const SizedBox(width: 6), _Badge('Sync: ${controller.pendingCount}')],
          ]),
          const SizedBox(height: 12),
          TextField(
            onChanged: controller.setSearchQuery,
            decoration: InputDecoration(
              hintText: presentOnly ? 'Search present kids...' : 'Search Beechboro kids...',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            const Text('Sort: ', style: TextStyle(color: KidsChurchColors.muted)),
            _SortButton(label: 'First', selected: controller.childSort == ChildSort.firstName, onTap: () => controller.setChildSort(ChildSort.firstName)),
            const SizedBox(width: 6),
            _SortButton(label: 'Surname', selected: controller.childSort == ChildSort.surname, onTap: () => controller.setChildSort(ChildSort.surname)),
          ]),
          ErrorPanel(controller: controller),
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: _panelDecoration(),
            child: children.isEmpty
                ? Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(presentOnly ? 'No children are marked present.' : 'No children found.')))
                : Column(children: [for (final child in children) _ChildRow(controller: controller, child: child, canMark: !presentOnly)]),
          ),
        ],
      ),
    );
  }
}

class _ChildRow extends StatelessWidget {
  const _ChildRow({required this.controller, required this.child, required this.canMark});
  final AppController controller;
  final ChildSummary child;
  final bool canMark;

  @override
  Widget build(BuildContext context) {
    final present = controller.presentByChildId[child.childId] == true;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      decoration: BoxDecoration(
        color: present ? const Color(0x332ECC71) : KidsChurchColors.surface,
        border: Border.all(color: present ? const Color(0x662ECC71) : KidsChurchColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        onTap: () => _showChildDetails(context, controller, child),
        leading: _ChildAvatar(child: child),
        title: Row(children: [
          Flexible(child: Text(child.fullName, style: const TextStyle(fontWeight: FontWeight.w700))),
          if (child.hasMedicalInfo) const Padding(padding: EdgeInsets.only(left: 6), child: Text('⚕️')),
          if (child.hasOtherInfo) const Padding(padding: EdgeInsets.only(left: 4), child: Text('❗')),
        ]),
        subtitle: controller.childHasPending(child.childId) ? const Text('Waiting to sync') : null,
        trailing: canMark
            ? OutlinedButton(
                style: present ? OutlinedButton.styleFrom(backgroundColor: const Color(0x332ECC71), side: const BorderSide(color: Color(0x662ECC71))) : null,
                onPressed: () => controller.toggleAttendance(child, !present),
                child: Text(present ? 'Present' : 'Mark'),
              )
            : const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _RosterPage extends StatelessWidget {
  const _RosterPage({required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    final bundle = controller.roster;
    return _ContentList(
      controller: controller,
      title: 'Roster',
      empty: bundle == null ? 'Loading roster…' : 'No roster items to show.',
      children: [
        if (bundle != null && bundle.blockouts.isNotEmpty) _Section(title: 'My blockout dates', children: [
          for (final blockout in bundle.blockouts)
            ListTile(title: Text('${blockout.startDate} – ${blockout.endDate}'), subtitle: blockout.reason.isEmpty ? null : Text(blockout.reason)),
        ]),
        if (bundle != null) _Section(title: 'My roster', children: [
          for (final item in bundle.roster)
            ListTile(
              title: Text(item.role.isEmpty ? 'Kids Church' : item.role, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text([item.date, item.status, item.notes].where((value) => value.isNotEmpty).join(' • ')),
              trailing: item.status.toLowerCase() == 'pending'
                  ? Wrap(spacing: 5, children: [
                      FilledButton(onPressed: () => controller.respondToRoster(item, 'confirm'), child: const Text('Confirm')),
                      OutlinedButton(onPressed: () => _reject(context, item), child: const Text('Reject')),
                    ])
                  : _Badge(item.status),
            ),
        ]),
      ],
    );
  }

  Future<void> _reject(BuildContext context, RosterItem item) async {
    final notes = TextEditingController();
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Reject roster slot'),
      content: TextField(controller: notes, maxLines: 3, decoration: const InputDecoration(hintText: 'Please add a reason')),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Submit rejection'))],
    ));
    if (confirmed == true && notes.text.trim().isNotEmpty) {
      await controller.respondToRoster(item, 'reject', notes: notes.text.trim());
    }
    notes.dispose();
  }
}

class _SchedulePage extends StatelessWidget {
  const _SchedulePage({required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) => _ContentList(
        controller: controller,
        title: 'Schedule',
        empty: controller.scheduleRoles.isEmpty ? 'No schedule for this date.' : '',
        children: [for (final role in controller.scheduleRoles) _Section(title: role.role, children: [
          for (final volunteer in role.volunteers)
            ListTile(leading: const Icon(Icons.person_outline), title: Text(volunteer.name), subtitle: Text([volunteer.status, volunteer.notes].where((v) => v.isNotEmpty).join(' • '))),
          for (final item in role.items)
            ListTile(
              leading: const Icon(Icons.schedule),
              title: Text(item.title.isEmpty ? item.series : item.title, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text([item.time, item.series, item.notes, item.resourceName].where((v) => v.isNotEmpty).join(' • ')),
              trailing: item.resourceLink.isEmpty ? null : IconButton(icon: const Icon(Icons.open_in_new), onPressed: () => _openUrl(item.resourceLink)),
            ),
        ])],
      );
}

class _ResourcesPage extends StatelessWidget {
  const _ResourcesPage({required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    final resources = controller.resources;
    return _ContentList(
      controller: controller,
      title: 'Resources',
      empty: resources == null ? 'Loading resources…' : 'No resources available.',
      children: resources == null ? const [] : [
        if (resources.topLinks.isNotEmpty) _Section(title: 'Links', children: [for (final item in resources.topLinks) _ResourceRow(item: item)]),
        for (final type in resources.types) _Section(title: type, children: [for (final item in resources.itemsByType[type]!) _ResourceRow(item: item)]),
      ],
    );
  }
}

class _ResourceRow extends StatelessWidget {
  const _ResourceRow({required this.item});
  final ResourceItem item;
  @override
  Widget build(BuildContext context) => ListTile(
        leading: const Icon(Icons.description_outlined),
        title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: item.description.isEmpty ? null : Text(item.description, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: item.link.isEmpty ? null : IconButton(icon: const Icon(Icons.open_in_new), onPressed: () => _openUrl(item.link)),
      );
}

class _ContentList extends StatelessWidget {
  const _ContentList({required this.controller, required this.title, required this.empty, required this.children});
  final AppController controller;
  final String title;
  final String empty;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: controller.refreshCurrentTab,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
            ErrorPanel(controller: controller),
            if (children.isEmpty) Padding(padding: const EdgeInsets.all(32), child: Center(child: Text(empty, style: const TextStyle(color: KidsChurchColors.muted)))),
            ...children,
          ],
        ),
      );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(10),
        decoration: _panelDecoration(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(padding: const EdgeInsets.fromLTRB(6, 3, 6, 8), child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900))),
          ...children,
        ]),
      );
}

class _Badge extends StatelessWidget {
  const _Badge(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: const Color(0x0FFFFFFF), border: Border.all(color: KidsChurchColors.border), borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: const TextStyle(color: KidsChurchColors.muted, fontSize: 12)),
      );
}

class _SortButton extends StatelessWidget {
  const _SortButton({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => OutlinedButton(
        style: selected ? OutlinedButton.styleFrom(backgroundColor: const Color(0x2E2ECC71), side: const BorderSide(color: Color(0x732ECC71))) : null,
        onPressed: onTap,
        child: Text(label),
      );
}

BoxDecoration _panelDecoration() => BoxDecoration(
      color: KidsChurchColors.surfaceAlt,
      border: Border.all(color: KidsChurchColors.border),
      borderRadius: BorderRadius.circular(18),
    );

void _showChildDetails(BuildContext context, AppController controller, ChildSummary child) {
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
            return SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(details.fullName, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              if (details.age.isNotEmpty) Text('Age ${details.age}'),
              const Divider(height: 28),
              _DetailSection(title: 'Medical information', value: details.medicalInfo),
              _DetailSection(title: 'Other important information', value: details.otherInfo),
              _ContactTile(label: 'Parent A', contact: details.parentA),
              _ContactTile(label: 'Parent B', contact: details.parentB),
              for (final guardian in details.additionalGuardians) _ContactTile(label: 'Additional guardian', contact: guardian),
            ]));
          },
        ),
      ),
    ),
  );
}

String _initials(String name) => name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).take(2).map((part) => part[0]).join().toUpperCase();

Future<void> _openUrl(String value) async {
  final uri = Uri.tryParse(value);
  if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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
    if (contact.name.isEmpty && contact.phone.isEmpty) {
      return const SizedBox.shrink();
    }
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.contact_phone_outlined),
      title: Text(contact.name.isEmpty ? label : contact.name),
      subtitle: Text([label, contact.phone].where((item) => item.isNotEmpty).join(' • ')),
    );
  }
}
