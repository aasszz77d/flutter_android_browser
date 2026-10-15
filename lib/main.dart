import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const BrowserApp());
}

class BrowserApp extends StatelessWidget {
  const BrowserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Browser',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A73E8),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          scrolledUnderElevation: 1,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8AB4F8),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const BrowserHomePage(),
    );
  }
}

class BrowserTab {
  BrowserTab({
    required this.id,
    required this.controller,
    this.title = 'New Tab',
    this.url = 'https://www.google.com',
    this.isLoading = false,
    this.progress = 0,
  });

  final String id;
  final WebViewController controller;
  String title;
  String url;
  bool isLoading;
  int progress;
}

class BrowserHomePage extends StatefulWidget {
  const BrowserHomePage({super.key});

  @override
  State<BrowserHomePage> createState() => _BrowserHomePageState();
}

class _BrowserHomePageState extends State<BrowserHomePage> {
  final List<BrowserTab> _tabs = [];
  int _currentIndex = 0;
  final TextEditingController _urlController = TextEditingController();
  final FocusNode _urlFocusNode = FocusNode();
  bool _canGoBack = false;
  bool _canGoForward = false;
  bool _isDesktopMode = false;

  BrowserTab get _currentTab => _tabs[_currentIndex];

  @override
  void initState() {
    super.initState();
    _addNewTab();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _urlFocusNode.dispose();
    super.dispose();
  }

  WebViewController _createController() {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (!mounted) return;
            setState(() {
              _currentTab.progress = progress;
              _currentTab.isLoading = progress < 100;
            });
          },
          onPageStarted: (String url) {
            if (!mounted) return;
            setState(() {
              _currentTab.url = url;
              _currentTab.isLoading = true;
              if (!_urlFocusNode.hasFocus) {
                _urlController.text = url;
              }
            });
            _updateNavigationState();
          },
          onPageFinished: (String url) async {
            if (!mounted) return;
            final title = await _currentTab.controller.getTitle();
            setState(() {
              _currentTab.url = url;
              _currentTab.title = (title?.isNotEmpty == true) ? title! : url;
              _currentTab.isLoading = false;
              if (!_urlFocusNode.hasFocus) {
                _urlController.text = url;
              }
            });
            _updateNavigationState();
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView error: ${error.description}');
          },
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          },
        ),
      );

    return controller;
  }

  void _addNewTab({String url = 'https://www.google.com'}) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final controller = _createController();
    final tab = BrowserTab(id: id, controller: controller, url: url);

    setState(() {
      _tabs.add(tab);
      _currentIndex = _tabs.length - 1;
      _urlController.text = url;
    });

    controller.loadRequest(Uri.parse(url));
    _applyDesktopMode(controller);
  }

  void _closeTab(int index) {
    if (_tabs.length <= 1) {
      // Keep at least one tab
      _tabs[0].controller.loadRequest(Uri.parse('https://www.google.com'));
      setState(() {
        _tabs[0].title = 'New Tab';
        _tabs[0].url = 'https://www.google.com';
        _urlController.text = 'https://www.google.com';
      });
      return;
    }

    setState(() {
      _tabs.removeAt(index);
      if (_currentIndex >= _tabs.length) {
        _currentIndex = _tabs.length - 1;
      } else if (_currentIndex > index) {
        _currentIndex--;
      }
      _urlController.text = _currentTab.url;
    });
    _updateNavigationState();
  }

  void _switchTab(int index) {
    setState(() {
      _currentIndex = index;
      _urlController.text = _currentTab.url;
    });
    _updateNavigationState();
  }

  Future<void> _updateNavigationState() async {
    final canBack = await _currentTab.controller.canGoBack();
    final canForward = await _currentTab.controller.canGoForward();
    if (!mounted) return;
    setState(() {
      _canGoBack = canBack;
      _canGoForward = canForward;
    });
  }

  void _navigateToUrl(String input) {
    String url = input.trim();
    if (url.isEmpty) return;

    // Simple search detection
    if (!url.contains('.') || url.contains(' ')) {
      url = 'https://www.google.com/search?q=${Uri.encodeComponent(url)}';
    } else if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }

    _urlFocusNode.unfocus();
    _currentTab.controller.loadRequest(Uri.parse(url));
  }

  Future<void> _applyDesktopMode(WebViewController controller) async {
    if (_isDesktopMode) {
      await controller.setUserAgent(
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      );
    } else {
      await controller.setUserAgent(null); // reset to default mobile UA
    }
  }

  void _toggleDesktopMode() async {
    setState(() => _isDesktopMode = !_isDesktopMode);
    await _applyDesktopMode(_currentTab.controller);
    _currentTab.controller.reload();
  }

  void _showTabsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tabs (${_tabs.length})',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () {
                          Navigator.pop(context);
                          _addNewTab();
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('New Tab'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: _tabs.length,
                    itemBuilder: (context, index) {
                      final tab = _tabs[index];
                      final isSelected = index == _currentIndex;
                      return ListTile(
                        selected: isSelected,
                        leading: Icon(
                          Icons.public,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                        title: Text(
                          tab.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          tab.url,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _closeTab(index);
                            if (_tabs.isEmpty) {
                              Navigator.pop(context);
                            } else {
                              // Force rebuild of sheet
                              (context as Element).markNeedsBuild();
                            }
                          },
                        ),
                        onTap: () {
                          _switchTab(index);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Material(
              elevation: 1,
              color: theme.colorScheme.surface,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: _canGoBack
                              ? () => _currentTab.controller.goBack()
                              : null,
                          tooltip: 'Back',
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_forward),
                          onPressed: _canGoForward
                              ? () => _currentTab.controller.goForward()
                              : null,
                          tooltip: 'Forward',
                        ),
                        IconButton(
                          icon: Icon(
                            _currentTab.isLoading ? Icons.close : Icons.refresh,
                          ),
                          onPressed: () {
                            if (_currentTab.isLoading) {
                              _currentTab.controller.loadRequest(
                                Uri.parse('about:blank'),
                              );
                            } else {
                              _currentTab.controller.reload();
                            }
                          },
                          tooltip: _currentTab.isLoading ? 'Stop' : 'Reload',
                        ),
                        Expanded(
                          child: Container(
                            height: 42,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: TextField(
                              controller: _urlController,
                              focusNode: _urlFocusNode,
                              style: theme.textTheme.bodyMedium,
                              decoration: InputDecoration(
                                hintText: 'Search or enter URL',
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                prefixIcon: const Icon(Icons.lock_outline, size: 18),
                                suffixIcon: _urlController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18),
                                        onPressed: () {
                                          _urlController.clear();
                                          _urlFocusNode.requestFocus();
                                        },
                                      )
                                    : null,
                              ),
                              keyboardType: TextInputType.url,
                              textInputAction: TextInputAction.go,
                              onSubmitted: _navigateToUrl,
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Badge(
                            label: Text('${_tabs.length}'),
                            child: const Icon(Icons.tab),
                          ),
                          onPressed: _showTabsSheet,
                          tooltip: 'Tabs',
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            switch (value) {
                              case 'new_tab':
                                _addNewTab();
                                break;
                              case 'home':
                                _currentTab.controller.loadRequest(
                                  Uri.parse('https://www.google.com'),
                                );
                                break;
                              case 'desktop':
                                _toggleDesktopMode();
                                break;
                              case 'share':
                                // Simple share via system (clipboard for now)
                                Clipboard.setData(
                                  ClipboardData(text: _currentTab.url),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('URL copied to clipboard'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                                break;
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'new_tab',
                              child: ListTile(
                                leading: Icon(Icons.add),
                                title: Text('New Tab'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'home',
                              child: ListTile(
                                leading: Icon(Icons.home_outlined),
                                title: Text('Home'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            PopupMenuItem(
                              value: 'desktop',
                              child: ListTile(
                                leading: Icon(
                                  _isDesktopMode
                                      ? Icons.smartphone
                                      : Icons.desktop_windows_outlined,
                                ),
                                title: Text(
                                  _isDesktopMode
                                      ? 'Mobile Site'
                                      : 'Desktop Site',
                                ),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'share',
                              child: ListTile(
                                leading: Icon(Icons.copy),
                                title: Text('Copy URL'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Progress bar
                  if (_currentTab.isLoading)
                    LinearProgressIndicator(
                      value: _currentTab.progress / 100,
                      minHeight: 2,
                      backgroundColor: Colors.transparent,
                    )
                  else
                    const SizedBox(height: 2),
                ],
              ),
            ),

            // WebView
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: _tabs.map((tab) {
                  return WebViewWidget(controller: tab.controller);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
