import 'package:flutter/material.dart';

import 'admin_operations.dart';
import 'referral_download.dart';

class AdminReferralDownloadCard extends StatefulWidget {
  const AdminReferralDownloadCard({
    super.key,
    required this.gateway,
    required this.canEdit,
    this.verifyChange,
  });
  final ReferralDownloadGateway gateway;
  final bool canEdit;
  final Future<bool> Function()? verifyChange;

  @override
  State<AdminReferralDownloadCard> createState() =>
      _AdminReferralDownloadCardState();
}

class _AdminReferralDownloadCardState extends State<AdminReferralDownloadCard> {
  final controller = TextEditingController();
  String? saved, message;
  bool loading = true, busy = false, loadFailed = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      loadFailed = false;
      message = null;
    });
    try {
      final url = await widget.gateway.load();
      if (!mounted) return;
      setState(() {
        saved = url;
        controller.text = url ?? '';
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          loadFailed = true;
          message = 'Unable to load the download link. Try again.';
        });
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> save(String? url) async {
    if (busy || !widget.canEdit) return;
    if (url != null && !validReferralDownloadUrl(url)) {
      setState(() => message = 'Enter a valid HTTPS download link.');
      return;
    }
    setState(() {
      busy = true;
      message = null;
    });
    try {
      if (!await (widget.verifyChange?.call() ??
          verifyAdminMfa(context, widget.gateway.client))) {
        return;
      }
      if (!mounted) return;
      await widget.gateway.save(url);
      if (!mounted) return;
      setState(() {
        saved = url;
        controller.text = url ?? '';
        message = url == null
            ? 'Download link deleted.'
            : 'Download link saved.';
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => message = 'Unable to save the download link. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Referral app download link',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text('Users share this link with their referral code.'),
          if (loading)
            const LinearProgressIndicator()
          else if (loadFailed)
            TextButton(onPressed: load, child: const Text('Retry link'))
          else if (widget.canEdit) ...[
            TextField(
              controller: controller,
              enabled: !busy,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Download URL',
                hintText: 'https://example.com/app.apk',
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  onPressed: busy ? null : () => save(controller.text.trim()),
                  child: const Text('Save link'),
                ),
                if (saved != null)
                  OutlinedButton(
                    onPressed: busy ? null : () => save(null),
                    child: const Text('Delete link'),
                  ),
              ],
            ),
          ] else
            SelectableText(saved ?? 'No download link added.'),
          if (message != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(message!),
            ),
        ],
      ),
    ),
  );
}
