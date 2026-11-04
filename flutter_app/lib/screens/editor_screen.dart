import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/api_config.dart';
import '../models/debugging_question.dart';
import '../models/problem.dart';
import '../models/run_event.dart';
import '../services/api_client.dart';
import '../services/interactive_run_service.dart';
import '../services/judge_service.dart';
import '../services/progress_store.dart';
import '../widgets/arena_widgets.dart';

const _languages = <String, String>{
  'python': 'Python 3',
  'javascript': 'JavaScript',
  'java': 'Java',
  'cpp': 'C++',
  'c': 'C',
};

class EditorScreen extends StatefulWidget {
  final Problem? problem;
  final DebuggingQuestion? debuggingQuestion;
  final JudgeService judgeService;
  final InteractiveRunService runService;
  final ProgressStore? progressStore;

  const EditorScreen({
    super.key,
    this.problem,
    this.debuggingQuestion,
    required this.judgeService,
    required this.runService,
    this.progressStore,
  });

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final _codeController = TextEditingController();
  final _stdinController = TextEditingController();
  final _outputScrollController = ScrollController();
  final Map<String, String> _drafts = {};
  String _language = 'python';
  String _output = '';
  String _runStatus = 'Idle';
  bool _submitting = false;
  bool _startingRun = false;
  String? _runId;
  StreamSubscription<RunEvent>? _runSubscription;
  Map<String, dynamic>? _judgeResult;

  @override
  void initState() {
    super.initState();
    _drafts[_language] = _starterFor(_language);
    _codeController.text = _drafts[_language]!;
  }

  @override
  void dispose() {
    final runId = _runId;
    if (runId != null && _runStatus == 'Running') widget.runService.stop(runId);
    _runSubscription?.cancel();
    _codeController.dispose();
    _stdinController.dispose();
    _outputScrollController.dispose();
    super.dispose();
  }

  String _starterFor(String language) {
    final problemCode = widget.problem?.starterCode[language];
    if (problemCode != null) return problemCode;
    final debugCode = widget.debuggingQuestion?.starterCode[language];
    if (debugCode != null) return debugCode;
    return switch (language) {
      'python' =>
        'def solve():\n    data = input().strip()\n    print(data)\n\nsolve()\n',
      'javascript' =>
        'const fs = require("fs");\nconst input = fs.readFileSync(0, "utf8").trim();\nconsole.log(input);\n',
      'java' =>
        'import java.util.*;\n\npublic class Main {\n    public static void main(String[] args) {\n        Scanner scanner = new Scanner(System.in);\n        System.out.println(scanner.hasNextLine() ? scanner.nextLine() : "");\n    }\n}\n',
      'cpp' =>
        '#include <iostream>\n#include <string>\nusing namespace std;\n\nint main() {\n    string input;\n    getline(cin, input);\n    cout << input << endl;\n    return 0;\n}\n',
      _ =>
        '#include <stdio.h>\n\nint main(void) {\n    char input[1024] = {0};\n    if (fgets(input, sizeof(input), stdin)) printf("%s", input);\n    return 0;\n}\n',
    };
  }

  List<ProblemTestCase> get _tests {
    if (widget.problem != null) return widget.problem!.testCases;
    return widget.debuggingQuestion?.tests
            .map((test) =>
                ProblemTestCase(input: test.input, expected: test.expected))
            .toList() ??
        const <ProblemTestCase>[];
  }

  void _appendOutput(String text) {
    if (!mounted) return;
    setState(() => _output += text);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_outputScrollController.hasClients) {
        _outputScrollController
            .jumpTo(_outputScrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _judgeResult = null;
    });
    try {
      final result = await widget.judgeService.submit(
        sourceCode: _codeController.text,
        language: _language,
        tests: _tests,
      );
      if (result['verdict'] == 'Accepted' &&
          widget.problem != null &&
          widget.progressStore != null) {
        await widget.progressStore!.markAccepted(widget.problem!.id);
      }
      if (result['verdict'] == 'Accepted' &&
          widget.debuggingQuestion != null &&
          widget.progressStore != null) {
        await widget.progressStore!
            .markDebuggingAccepted(widget.debuggingQuestion!.id);
      }
      if (mounted) setState(() => _judgeResult = result);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _judgeResult = {
              'verdict': 'Execution Error',
              'error': error.message
            });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _judgeResult = {
              'verdict': 'Execution Error',
              'error': error.toString()
            });
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _startRun() async {
    if (_startingRun || _runId != null) return;
    setState(() {
      _startingRun = true;
      _output = '';
      _runStatus = 'Starting';
    });
    try {
      final session = await widget.runService
          .start(sourceCode: _codeController.text, language: _language);
      if (!mounted) {
        widget.runService.stop(session.id);
        return;
      }
      setState(() {
        _runId = session.id;
        _runStatus = 'Starting';
        _startingRun = false;
      });
      _runSubscription =
          session.events.listen(_onRunEvent, onError: (Object error) {
        _appendOutput('\n[Connection error: $error]\n');
        if (mounted) {
          setState(() {
            _runStatus = 'Connection lost';
            _runId = null;
          });
        }
      }, onDone: () {
        if (mounted && _runStatus == 'Running') {
          setState(() {
            _runStatus = 'Connection closed';
            _runId = null;
          });
        }
      });
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _runStatus = 'Unavailable';
          _runId = null;
        });
        _appendOutput('${error.message}\n');
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _runStatus = 'Error';
          _runId = null;
        });
        _appendOutput('$error\n');
      }
    } finally {
      if (mounted) setState(() => _startingRun = false);
    }
  }

  void _onRunEvent(RunEvent event) {
    switch (event.type) {
      case 'stdout':
        _appendOutput(event.data['data']?.toString() ?? '');
      case 'stderr':
        _appendOutput(event.data['data']?.toString() ?? '');
      case 'status':
        final state = event.data['state']?.toString() ?? 'Running';
        if (mounted) {
          setState(
              () => _runStatus = state[0].toUpperCase() + state.substring(1));
        }
      case 'finished':
        final state = event.data['state']?.toString() ?? 'finished';
        final exitCode = event.data['exitCode'];
        if (mounted) {
          setState(() {
            _runStatus =
                state == 'completed' && exitCode == 0 ? 'Finished' : state;
            _runId = null;
          });
        }
        if (state == 'runner_error' ||
            state == 'runner_unavailable' ||
            state == 'process_error') {
          _appendOutput(
              '\n[Docker runner unavailable. Use a configured Node backend with the runner image built.]\n');
        }
    }
  }

  Future<void> _sendInput() async {
    final runId = _runId;
    if (runId == null || _stdinController.text.isEmpty) return;
    final line = _stdinController.text;
    _stdinController.clear();
    _appendOutput('> $line\n');
    try {
      await widget.runService.sendInput(runId, '$line\n');
    } on ApiException catch (error) {
      _appendOutput('[Input error: ${error.message}]\n');
    }
  }

  Future<void> _stopRun() async {
    final runId = _runId;
    if (runId == null) return;
    setState(() => _runStatus = 'Stopping');
    try {
      await widget.runService.stop(runId);
    } on ApiException catch (error) {
      _appendOutput('[Stop error: ${error.message}]\n');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.problem?.title ??
              widget.debuggingQuestion?.title ??
              'Compiler'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _language,
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _drafts[_language] = _codeController.text;
                      _language = value;
                      _codeController.text =
                          _drafts.putIfAbsent(value, () => _starterFor(value));
                    });
                  },
                  items: _languages.entries
                      .map((entry) => DropdownMenuItem(
                          value: entry.key, child: Text(entry.value)))
                      .toList(),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(children: [
            if (ApiConfig.configurationError() != null)
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: ApiNotice(
                    message:
                        'Set API_BASE_URL to enable real Run and Submit. No local or mock execution is used.'),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Row(children: [
                Expanded(
                    child: OutlinedButton.icon(
                  onPressed: _startingRun || _runId != null ? null : _startRun,
                  icon: _startingRun
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.play_arrow),
                  label: const Text('Run'),
                )),
                const SizedBox(width: 8),
                Expanded(
                    child: FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.fact_check_outlined),
                  label: const Text('Submit'),
                )),
                if (_runId != null) ...[
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                      tooltip: 'Stop program',
                      onPressed: _stopRun,
                      icon: const Icon(Icons.stop)),
                ],
              ]),
            ),
            if (_judgeResult != null) _JudgeResultPanel(result: _judgeResult!),
            Expanded(
              flex: 5,
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 2, 12, 8),
                decoration: BoxDecoration(
                    color: const Color(0xFF09171F),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF263D4A))),
                child: TextField(
                  controller: _codeController,
                  expands: true,
                  minLines: null,
                  maxLines: null,
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.multiline,
                  textAlignVertical: TextAlignVertical.top,
                  inputFormatters: [AutoIndentFormatter(_language)],
                  style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      height: 1.45,
                      color: Color(0xFFE5F1F4)),
                  decoration: const InputDecoration(
                    hintText: 'Write your program…',
                    contentPadding: EdgeInsets.all(14),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
            ),
            _TerminalPanel(
              output: _output,
              status: _runStatus,
              controller: _stdinController,
              scrollController: _outputScrollController,
              onSend: _sendInput,
              canSend: _runId != null,
            ),
          ]),
        ),
      );
}

class AutoIndentFormatter extends TextInputFormatter {
  final String language;

  AutoIndentFormatter(this.language);

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.length != oldValue.text.length + 1 ||
        newValue.selection.baseOffset < 1) {
      return newValue;
    }
    final caret = newValue.selection.baseOffset;
    if (newValue.text[caret - 1] != '\n') return newValue;
    final lineStart =
        oldValue.text.lastIndexOf('\n', oldValue.selection.baseOffset - 1) + 1;
    final line =
        oldValue.text.substring(lineStart, oldValue.selection.baseOffset);
    final indent = RegExp(r'^\s*').firstMatch(line)?.group(0) ?? '';
    final trimmed = line.trimRight();
    final opener =
        trimmed.isNotEmpty && '{[('.contains(trimmed[trimmed.length - 1]);
    final pythonBlock = language == 'python' && trimmed.endsWith(':');
    final insertion = '\n$indent${opener || pythonBlock ? '    ' : ''}';
    final text = oldValue.text.replaceRange(
        oldValue.selection.start, oldValue.selection.end, insertion);
    final offset = oldValue.selection.start + insertion.length;
    return TextEditingValue(
        text: text, selection: TextSelection.collapsed(offset: offset));
  }
}

class _TerminalPanel extends StatelessWidget {
  final String output;
  final String status;
  final TextEditingController controller;
  final ScrollController scrollController;
  final VoidCallback onSend;
  final bool canSend;

  const _TerminalPanel({
    required this.output,
    required this.status,
    required this.controller,
    required this.scrollController,
    required this.onSend,
    required this.canSend,
  });

  @override
  Widget build(BuildContext context) => Container(
        height: 174,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: BoxDecoration(
            color: const Color(0xFF0D1D26),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF263D4A))),
        child: Column(children: [
          Row(children: [
            const Icon(Icons.terminal, size: 16, color: Color(0xFF55DCE5)),
            const SizedBox(width: 7),
            const Text('RUN OUTPUT',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    letterSpacing: 0.7)),
            const Spacer(),
            Text(status,
                style: const TextStyle(color: Color(0xFFA8BBC5), fontSize: 11)),
          ]),
          const Divider(height: 12),
          Expanded(
            child: Align(
              alignment: Alignment.topLeft,
              child: SingleChildScrollView(
                controller: scrollController,
                child: SelectableText(
                    output.isEmpty ? 'Run output will appear here.' : output,
                    style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        height: 1.35,
                        color: Color(0xFFD8E5E9))),
              ),
            ),
          ),
          Row(children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: canSend,
                onSubmitted: (_) => onSend(),
                textInputAction: TextInputAction.send,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Send stdin line',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
              ),
            ),
            IconButton(
                tooltip: 'Send input',
                onPressed: canSend ? onSend : null,
                icon: const Icon(Icons.send, size: 18)),
          ]),
        ]),
      );
}

class _JudgeResultPanel extends StatelessWidget {
  final Map<String, dynamic> result;

  const _JudgeResultPanel({required this.result});

  @override
  Widget build(BuildContext context) {
    final verdict = result['verdict']?.toString() ??
        result['state']?.toString() ??
        'Execution Error';
    final results = (result['results'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 150),
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: const Color(0xFF10232F),
          borderRadius: BorderRadius.circular(8)),
      child: ListView(shrinkWrap: true, children: [
        Text(verdict,
            style: TextStyle(
                fontWeight: FontWeight.w800,
                color: verdict == 'Accepted'
                    ? const Color(0xFF72D7A5)
                    : const Color(0xFFFF8585))),
        if (result['error'] is String)
          Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(result['error'] as String)),
        if (result['stderr'] is String &&
            (result['stderr'] as String).isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 5),
              child: SelectableText(result['stderr'] as String)),
        ...results.map((test) => Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Text(
                'Case ${test['caseNumber']}: ${test['pass'] == true ? 'Accepted' : 'Failed'}'
                '${test['time'] == null ? '' : ' · ${test['time']} ms'}'
                '${test['memory'] == null ? '' : ' · ${test['memory']} MB'}\n'
                'Expected: ${test['expected']}\nActual: ${test['actual']}',
                style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 11, height: 1.35),
              ),
            )),
      ]),
    );
  }
}
