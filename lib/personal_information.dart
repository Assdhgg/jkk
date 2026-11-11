import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'evidence_image.dart';

String _t(BuildContext context, String english, String malayalam) =>
    Localizations.localeOf(context).languageCode == 'ml' ? malayalam : english;

abstract class PersonalInformationGateway {
  Future<Uint8List?> loadPhoto();
  Future<void> savePhoto(Uint8List data, String mime);
  Future<void> requestEmailChange(String email);
  Future<void> verifyOldEmail(String code);
  Future<void> verifyNewEmail(String email, String code);
}

class SupabasePersonalInformationGateway implements PersonalInformationGateway {
  const SupabasePersonalInformationGateway(this.client, this.newOtpClient);
  final SupabaseClient client;
  final SupabaseClient Function() newOtpClient;
  @override
  Future<Uint8List?> loadPhoto() async {
    final photo = await client.rpc('profile_photo');
    if (photo == null) return null;
    return decodeEvidenceImage(photo as String);
  }

  @override
  Future<void> savePhoto(Uint8List data, String mime) async {
    await client.rpc(
      'set_profile_photo',
      params: {'p_mime': mime, 'p_data': base64Encode(data)},
    );
  }

  @override
  Future<void> requestEmailChange(String email) async {
    await client.auth.updateUser(UserAttributes(email: email));
  }

  @override
  Future<void> verifyOldEmail(String code) async {
    final current = client.auth.currentUser;
    if (current?.email == null) throw const AuthException('Sign in first.');
    final isolated = newOtpClient();
    try {
      final result = await isolated.auth.verifyOTP(
        email: current!.email!,
        token: code,
        type: OtpType.emailChange,
      );
      if (result.session != null) {
        throw const AuthException('Email change requires both confirmations.');
      }
      if (client.auth.currentUser?.id != current.id) {
        throw const AuthException('Session changed.');
      }
    } finally {
      await isolated.dispose();
    }
  }

  @override
  Future<void> verifyNewEmail(String email, String code) async {
    final id = client.auth.currentUser?.id;
    if (id == null) throw const AuthException('Sign in first.');
    final isolated = newOtpClient();
    try {
      final result = await isolated.auth.verifyOTP(
        email: email,
        token: code,
        type: OtpType.emailChange,
      );
      final session = result.session;
      if (result.user?.id != id ||
          result.user?.email?.toLowerCase() != email.toLowerCase() ||
          session?.refreshToken == null ||
          client.auth.currentUser?.id != id) {
        throw const AuthException('Email change is not complete.');
      }
      await client.auth.setSession(session!.refreshToken!);
    } finally {
      await isolated.dispose();
    }
  }
}

class PersonalInformationPage extends StatefulWidget {
  const PersonalInformationPage({
    super.key,
    required this.user,
    required this.publicId,
    required this.gateway,
    this.picker,
    this.emailChangeEnabled = const bool.fromEnvironment(
      'SECURE_EMAIL_CHANGE_ENABLED',
    ),
  });
  final User user;
  final String? publicId;
  final PersonalInformationGateway gateway;
  final Future<XFile?> Function()? picker;
  final bool emailChangeEnabled;
  @override
  State<PersonalInformationPage> createState() =>
      _PersonalInformationPageState();
}

class _PersonalInformationPageState extends State<PersonalInformationPage> {
  Uint8List? photo;
  bool loading = true, busy = false;
  String? photoError;
  @override
  void initState() {
    super.initState();
    loadPhoto();
  }

  Future<void> loadPhoto() async {
    try {
      final value = await widget.gateway.loadPhoto();
      if (mounted) {
        setState(() {
          photo = value;
          photoError = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => photoError = _t(
            context,
            'Could not load photo.',
            'ഫോട്ടോ ലഭ്യമായില്ല.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> choosePhoto() async {
    setState(() {
      busy = true;
      photoError = null;
    });
    try {
      final file =
          await (widget.picker?.call() ??
              ImagePicker().pickImage(
                source: ImageSource.gallery,
                maxWidth: 1024,
                maxHeight: 1024,
                imageQuality: 60,
                requestFullMetadata: false,
              ));
      if (file == null) return;
      if (await file.length() > 524288) {
        throw const FormatException('Image too large');
      }
      final bytes = await file.readAsBytes();
      await validateEvidenceImage(bytes);
      final mime = bytes[0] == 0x89 ? 'image/png' : 'image/jpeg';
      await widget.gateway.savePhoto(bytes, mime);
      if (mounted) setState(() => photo = bytes);
    } catch (_) {
      if (mounted) {
        setState(
          () => photoError = _t(
            context,
            'Could not save photo. Use a JPEG or PNG under 512 KB.',
            'ഫോട്ടോ save ചെയ്യാനായില്ല. 512 KB-ൽ താഴെയുള്ള JPEG അല്ലെങ്കിൽ PNG ഉപയോഗിക്കുക.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.user.userMetadata?['full_name'];
    final created = DateTime.tryParse(widget.user.createdAt)?.toLocal();
    final joined = created == null
        ? '—'
        : MaterialLocalizations.of(context).formatFullDate(created);
    return Scaffold(
      appBar: AppBar(
        title: Text(_t(context, 'Personal information', 'വ്യക്തിഗത വിവരങ്ങൾ')),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: const Color(0xffe5dafa),
                  backgroundImage: photo == null ? null : MemoryImage(photo!),
                  child: photo == null
                      ? const Icon(Icons.person, size: 48)
                      : null,
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: busy || loading ? null : choosePhoto,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(_t(context, 'Change photo', 'ഫോട്ടോ മാറ്റുക')),
                ),
              ),
              if (photoError != null)
                Text(photoError!, textAlign: TextAlign.center),
              if (loading || busy) const LinearProgressIndicator(),
              const SizedBox(height: 16),
              ListTile(
                title: Text(_t(context, 'Name', 'പേര്')),
                subtitle: Text(
                  name is String && name.trim().isNotEmpty ? name : '—',
                ),
              ),
              ListTile(
                title: Text(_t(context, 'Email ID', 'ഇമെയിൽ')),
                subtitle: Text(widget.user.email ?? '—'),
                trailing: TextButton(
                  onPressed:
                      widget.emailChangeEnabled && widget.user.email != null
                      ? () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => EmailChangePage(
                              currentEmail: widget.user.email!,
                              gateway: widget.gateway,
                            ),
                          ),
                        )
                      : null,
                  child: Text(_t(context, 'Change', 'മാറ്റുക')),
                ),
              ),
              if (!widget.emailChangeEnabled)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    _t(
                      context,
                      'Email change is not configured yet.',
                      'Email മാറ്റാനുള്ള സംവിധാനം ഇതുവരെ സജ്ജമായിട്ടില്ല.',
                    ),
                  ),
                ),
              ListTile(
                title: Text(_t(context, 'User ID', 'User ID')),
                subtitle: SelectableText(widget.publicId ?? '—'),
                trailing: widget.publicId == null
                    ? null
                    : IconButton(
                        tooltip: _t(
                          context,
                          'Copy user ID',
                          'User ID പകർത്തുക',
                        ),
                        icon: const Icon(Icons.copy),
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: widget.publicId!),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  _t(
                                    context,
                                    'User ID copied',
                                    'User ID പകർത്തി',
                                  ),
                                ),
                              ),
                            );
                          }
                        },
                      ),
              ),
              ListTile(
                title: Text(_t(context, 'Join date', 'ചേർന്ന തീയതി')),
                subtitle: Text(joined),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmailChangePage extends StatefulWidget {
  const EmailChangePage({
    super.key,
    required this.currentEmail,
    required this.gateway,
  });
  final String currentEmail;
  final PersonalInformationGateway gateway;
  @override
  State<EmailChangePage> createState() => _EmailChangePageState();
}

class _EmailChangePageState extends State<EmailChangePage> {
  final email = TextEditingController();
  final code = TextEditingController();
  int step = 0;
  bool busy = false;
  String? error;
  @override
  void dispose() {
    email.dispose();
    code.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final target = email.text.trim();
    if (step == 0 &&
        (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(target) ||
            target.toLowerCase() == widget.currentEmail.toLowerCase())) {
      setState(
        () => error = _t(
          context,
          'Enter a different valid email address.',
          'വ്യത്യസ്തമായ ഒരു സാധുവായ email നൽകുക.',
        ),
      );
      return;
    }
    if (step != 0 && !RegExp(r'^\d{6}$').hasMatch(code.text.trim())) {
      setState(
        () => error = _t(
          context,
          'Enter the six-digit code.',
          'ആറ് അക്ക code നൽകുക.',
        ),
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (step == 0) {
        await widget.gateway.requestEmailChange(target);
      } else if (step == 1) {
        await widget.gateway.verifyOldEmail(code.text.trim());
      } else {
        await widget.gateway.verifyNewEmail(target, code.text.trim());
        if (mounted) Navigator.pop(context);
        return;
      }
      if (mounted) {
        setState(() {
          step++;
          code.clear();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = _t(
            context,
            'Unable to verify. Check the code and try again.',
            'പരിശോധിക്കാനായില്ല. Code പരിശോധിച്ച് വീണ്ടും ശ്രമിക്കുക.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_t(context, 'Change email', 'Email മാറ്റുക'))),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              step == 0
                  ? _t(
                      context,
                      'Codes will be sent to both addresses. Verify the current email first.',
                      'രണ്ട് email-ലേക്കും code ലഭിക്കും. ആദ്യം നിലവിലെ email പരിശോധിക്കുക.',
                    )
                  : step == 1
                  ? _t(
                      context,
                      'Enter the code sent to ${widget.currentEmail}.',
                      '${widget.currentEmail}-ലേക്ക് ലഭിച്ച code നൽകുക.',
                    )
                  : _t(
                      context,
                      'Enter the code sent to ${email.text.trim()}.',
                      '${email.text.trim()}-ലേക്ക് ലഭിച്ച code നൽകുക.',
                    ),
            ),
            const SizedBox(height: 16),
            if (step == 0)
              TextField(
                key: const Key('new_email'),
                controller: email,
                enabled: !busy,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textCapitalization: TextCapitalization.none,
                decoration: InputDecoration(
                  labelText: _t(context, 'New email', 'പുതിയ email'),
                ),
              )
            else
              TextField(
                key: Key(step == 1 ? 'old_email_code' : 'new_email_code'),
                controller: code,
                enabled: !busy,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: InputDecoration(
                  labelText: _t(
                    context,
                    'Verification code',
                    'Verification code',
                  ),
                ),
              ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: busy ? null : submit,
              child: Text(
                step == 0
                    ? _t(context, 'Send codes', 'Codes അയയ്ക്കുക')
                    : _t(context, 'Verify', 'പരിശോധിക്കുക'),
              ),
            ),
            if (busy) const LinearProgressIndicator(),
          ],
        ),
      ),
    ),
  );
}
