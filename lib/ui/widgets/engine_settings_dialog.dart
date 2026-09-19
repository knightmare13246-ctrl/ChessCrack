import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/engine_analysis.dart';
import '../../models/engine_settings.dart';
import '../../services/native_engine_runner.dart';

class EngineSettingsDialog extends StatefulWidget {
  final EngineSettings settings;
  final void Function(EngineSettings newSettings) onSave;

  const EngineSettingsDialog({
    super.key,
    required this.settings,
    required this.onSave,
  });

  @override
  State<EngineSettingsDialog> createState() => _EngineSettingsDialogState();
}

class _EngineSettingsDialogState extends State<EngineSettingsDialog> {
  late EngineType _activeEngine;
  late int _threads;
  late int _hashSizeMb;
  late int _multiPv;
  late String _lc0Backend;
  String? _weightsPath;
  String? _syzygyPath;

  final Map<EngineType, bool> _binaryAvailability = {};

  @override
  void initState() {
    super.initState();
    _activeEngine = widget.settings.activeEngine;
    _threads = widget.settings.threads;
    _hashSizeMb = widget.settings.hashSizeMb;
    _multiPv = widget.settings.multiPv;
    _lc0Backend = const ['auto', 'blas', 'eigen', 'trivial'].contains(widget.settings.lc0Backend)
        ? widget.settings.lc0Backend
        : 'auto';
    _weightsPath = widget.settings.weightsPath;
    _syzygyPath = widget.settings.syzygyPath;
    _checkBinaries();
  }

  Future<void> _checkBinaries() async {
    for (final e in EngineType.values) {
      final path = await NativeEngineRunner.getEngineExecutablePath(e);
      if (mounted) {
        setState(() {
          _binaryAvailability[e] = path != null;
        });
      }
    }
  }

  Future<void> _pickWeightsFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      dialogTitle: 'Select Lc0 Neural Network Weights (.pb.gz or .onnx)',
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _weightsPath = result.files.single.path;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: const Text(
        'ChessCrack Engine Settings',
        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Selected Engine', style: TextStyle(color: Color(0xFF00D2BE), fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF141414),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<EngineType>(
                    value: _activeEngine,
                    dropdownColor: const Color(0xFF222222),
                    isExpanded: true,
                    items: EngineType.values.map((e) {
                      final isAvailable = _binaryAvailability[e] ?? true;
                      final label = isAvailable
                          ? '${e.displayName} (${e.description})'
                          : '${e.displayName} — unavailable';
                      return DropdownMenuItem(
                        value: e,
                        child: Text(
                          label,
                          style: TextStyle(
                            color: isAvailable ? Colors.white : Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _activeEngine = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),

              if (_activeEngine == EngineType.lc0) ...[
                const Text('Lc0 Compute Backend', style: TextStyle(color: Color(0xFF00D2BE), fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text(
                  'Execution backend for neural network evaluations (BLAS measured optimal on this CPU runtime).',
                  style: TextStyle(color: Colors.white54, fontSize: 10.5),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141414),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _lc0Backend,
                      dropdownColor: const Color(0xFF222222),
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 'auto', child: Text('Auto (Detected optimal backend)', style: TextStyle(color: Colors.white, fontSize: 12))),
                        DropdownMenuItem(value: 'blas', child: Text('BLAS (CPU accelerated execution)', style: TextStyle(color: Colors.white, fontSize: 12))),
                        DropdownMenuItem(value: 'eigen', child: Text('Eigen (Vectorized CPU execution)', style: TextStyle(color: Colors.white, fontSize: 12))),
                        DropdownMenuItem(value: 'trivial', child: Text('Trivial (Zero NN test backend)', style: TextStyle(color: Colors.white, fontSize: 12))),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _lc0Backend = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Lc0 Weights File (.pb.gz / .onnx)', style: TextStyle(color: Colors.white70, fontSize: 11)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141414),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Text(
                          _weightsPath != null ? _weightsPath!.split(RegExp(r'[\\/]')).last : 'Default embedded / auto weights',
                          style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace'),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF333333),
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      onPressed: _pickWeightsFile,
                      child: const Text('Browse', style: TextStyle(color: Colors.white, fontSize: 11)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Multi-PV Lines (Arrows):', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Text('$_multiPv', style: const TextStyle(color: Color(0xFF00D2BE), fontWeight: FontWeight.bold)),
                ],
              ),
              Slider(
                value: _multiPv.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                activeColor: const Color(0xFF00D2BE),
                onChanged: (val) => setState(() => _multiPv = val.round()),
              ),
              const SizedBox(height: 6),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('CPU Threads:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Text('$_threads', style: const TextStyle(color: Color(0xFF00D2BE), fontWeight: FontWeight.bold)),
                ],
              ),
              Slider(
                value: _threads.toDouble(),
                min: 1,
                max: 16,
                divisions: 15,
                activeColor: const Color(0xFF00D2BE),
                onChanged: (val) => setState(() => _threads = val.round()),
              ),
              const SizedBox(height: 6),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Memory Hash:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Text('$_hashSizeMb MB', style: const TextStyle(color: Color(0xFF00D2BE), fontWeight: FontWeight.bold)),
                ],
              ),
              Slider(
                value: _hashSizeMb.toDouble(),
                min: 16,
                max: 1024,
                divisions: 15,
                activeColor: const Color(0xFF00D2BE),
                onChanged: (val) => setState(() => _hashSizeMb = val.round()),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00D2BE),
            foregroundColor: Colors.black,
          ),
          onPressed: () {
            final newSettings = widget.settings.copyWith(
              activeEngine: _activeEngine,
              threads: _threads,
              hashSizeMb: _hashSizeMb,
              multiPv: _multiPv,
              lc0Backend: _lc0Backend,
              weightsPath: _weightsPath,
              syzygyPath: _syzygyPath,
            );
            widget.onSave(newSettings);
            Navigator.pop(context);
          },
          child: const Text('Apply Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
