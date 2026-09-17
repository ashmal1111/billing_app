import 'package:flutter/material.dart';
import 'supabase_service.dart';

class LoginDialog extends StatefulWidget {
  final VoidCallback onSessionChanged;

  const LoginDialog({
    super.key,
    required this.onSessionChanged,
  });

  static Future<void> show(BuildContext context,
      {required VoidCallback onSessionChanged}) {
    return showDialog(
      context: context,
      builder: (context) => LoginDialog(onSessionChanged: onSessionChanged),
    );
  }

  @override
  State<LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<LoginDialog> {
  final SupabaseService _auth = SupabaseService.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isSignUp = false;
  bool _isLoading = false;
  UserRole _selectedRole = UserRole.admin;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    final current = _auth.currentSession;
    if (current != null) {
      _emailController.text = current.email;
      _selectedRole = current.role;
    } else {
      _emailController.text = 'admin@company.com';
    }
  }

  @override
  void dispose() {
    _emailController.dispose;
    _passwordController.dispose;
    super.dispose();
  }

  Future<void> _submitAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty) {
      setState(() => _errorMessage = 'Please enter an email address');
      return;
    }
    if (password.isEmpty && _auth.isConfigured) {
      setState(() => _errorMessage = 'Please enter a password');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      if (_isSignUp) {
        await _auth.signUp(
          email: email,
          password: password.isEmpty ? '123456' : password,
          role: _selectedRole,
        );
      } else {
        await _auth.signIn(
          email: email,
          password: password.isEmpty ? '123456' : password,
          fallbackRole: _selectedRole,
        );
      }

      widget.onSessionChanged();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Logged in as ${_auth.currentSession?.email} (${_auth.currentSession?.role.displayName})',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loginDemo(UserRole role) async {
    setState(() => _isLoading = true);
    if (role == UserRole.admin) {
      await _auth.loginAsDemoAdmin();
    } else {
      await _auth.loginAsDemoStaff();
    }
    widget.onSessionChanged();
    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Active Session: ${role.displayName} (${_auth.currentSession?.email})',
          ),
          backgroundColor: role == UserRole.admin ? Colors.indigo : Colors.teal,
        ),
      );
    }
  }

  Future<void> _logout() async {
    await _auth.signOut();
    widget.onSessionChanged();
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Logged out successfully'),
          backgroundColor: Colors.grey,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _auth.currentSession;
    final isConfigured = _auth.isConfigured;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.shield,
                        color: Colors.indigo, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'User Session & Auth',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          isConfigured
                              ? 'Connected to Supabase Cloud'
                              : 'Local / Offline Mode Active',
                          style: TextStyle(
                            fontSize: 12,
                            color: isConfigured ? Colors.green : Colors.orange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 28),

              // Current Session Box
              if (session != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: session.isAdmin
                        ? Colors.indigo.withValues(alpha: 0.08)
                        : Colors.teal.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: session.isAdmin
                          ? Colors.indigo.withValues(alpha: 0.3)
                          : Colors.teal.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        session.isAdmin
                            ? Icons.admin_panel_settings
                            : Icons.badge,
                        color: session.isAdmin ? Colors.indigo : Colors.teal,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              session.email,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              'Role: ${session.role.displayName} ${session.isDemo ? "(Demo)" : "(Cloud)"}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: session.isAdmin ? Colors.indigo : Colors.teal,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          session.role.name.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Quick Switch Demo Buttons
              const Text(
                'QUICK DEMO SESSION (ONE-CLICK):',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed:
                          _isLoading ? null : () => _loginDemo(UserRole.admin),
                      icon: const Icon(Icons.admin_panel_settings, size: 18),
                      label: const Text('Admin Mode',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed:
                          _isLoading ? null : () => _loginDemo(UserRole.staff),
                      icon: const Icon(Icons.person, size: 18),
                      label: const Text('Staff Mode',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Divider with 'or'
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      isConfigured
                          ? 'OR SUPABASE ACCOUNT'
                          : 'OR CUSTOM ACCOUNT',
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                ],
              ),
              const SizedBox(height: 14),

              // Role Selector for Custom / Cloud Auth
              Row(
                children: [
                  const Text('Role: ',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    avatar: const Icon(Icons.admin_panel_settings, size: 16),
                    label: const Text('Admin'),
                    selected: _selectedRole == UserRole.admin,
                    selectedColor: Colors.indigo.shade100,
                    onSelected: (val) {
                      if (val) setState(() => _selectedRole = UserRole.admin);
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    avatar: const Icon(Icons.badge, size: 16),
                    label: const Text('Staff'),
                    selected: _selectedRole == UserRole.staff,
                    selectedColor: Colors.teal.shade100,
                    onSelected: (val) {
                      if (val) setState(() => _selectedRole = UserRole.staff);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Email input
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),

              // Password input
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: isConfigured ? 'Supabase password' : 'Any password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),

              if (_errorMessage.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],

              const SizedBox(height: 16),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _isLoading ? null : _submitAuth,
                      child: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(_isSignUp
                              ? 'Sign Up (${_selectedRole.displayName})'
                              : 'Sign In (${_selectedRole.displayName})'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => setState(() => _isSignUp = !_isSignUp),
                    child: Text(
                      _isSignUp
                          ? 'Already have an account? Sign In'
                          : 'Need an account? Sign Up',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  if (session != null)
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      onPressed: _logout,
                      child:
                          const Text('Log Out', style: TextStyle(fontSize: 12)),
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
