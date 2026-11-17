import 'package:material_ui/material_ui.dart';

import '../api.dart';
import '../settings.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.settings});

  final SettingsStore settings;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final _url = TextEditingController(text: widget.settings.serverUrl);
  bool _testing = false;
  String? _status;
  bool _ok = false;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _saveAndTest() async {
    setState(() {
      _testing = true;
      _status = null;
    });
    await widget.settings.setServerUrl(_url.text);
    String status;
    bool ok;
    try {
      final info = await ApiClient(widget.settings.serverUrl).health();
      final voices = info.ttsLanguages.isEmpty ? '无（将使用手机自带语音）' : info.ttsLanguages.join('、');
      status = '连接成功\n模型：${info.model}\n示范语音：$voices\n'
          'AI 聊天：${info.chat ? '已配置' : '未配置'}';
      ok = true;
    } on ApiException catch (e) {
      status = e.message;
      ok = false;
    }
    if (!mounted) return;
    setState(() {
      _testing = false;
      _status = status;
      _ok = ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = _status;
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('评分服务器地址', style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'http://192.168.1.10:8000',
            ),
            onSubmitted: (_) => _saveAndTest(),
          ),
          const SizedBox(height: 8),
          Text(
            '真机：填电脑的局域网地址，手机和电脑连同一个 WiFi。\n'
            'Android 模拟器：填 ${SettingsStore.defaultServerUrl}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _testing ? null : _saveAndTest,
            icon: _testing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.wifi_tethering),
            label: const Text('保存并测试连接'),
          ),
          if (status != null) ...[
            const SizedBox(height: 16),
            Text(
              status,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: _ok ? theme.colorScheme.primary : theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
