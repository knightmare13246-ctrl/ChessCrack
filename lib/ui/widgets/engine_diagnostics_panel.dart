import 'package:flutter/material.dart';
import '../../models/engine_analysis.dart';

class EngineDiagnosticsPanel extends StatelessWidget {
  final EngineDiagnostics? diagnostics;
  final bool isAnalyzing;

  const EngineDiagnosticsPanel({
    super.key,
    required this.diagnostics,
    this.isAnalyzing = false,
  });

  @override
  Widget build(BuildContext context) {
    if (diagnostics == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        color: const Color(0xFF161512),
        child: const Center(
          child: Text(
            'Diagnostics: No engine active',
            style: TextStyle(color: Colors.white54, fontSize: 12, fontFamily: 'monospace'),
          ),
        ),
      );
    }

    final d = diagnostics!;
    final wdlStr = d.wdl != null && d.wdl!.length >= 3
        ? 'W: ${(d.wdl![0] / 10).toStringAsFixed(1)}% | D: ${(d.wdl![1] / 10).toStringAsFixed(1)}% | L: ${(d.wdl![2] / 10).toStringAsFixed(1)}%'
        : 'N/A';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF161512),
        border: Border(
          top: BorderSide(color: Color(0xFF262421), width: 1),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isAnalyzing ? const Color(0xFF629924) : Colors.amber,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'CHESSCRACK • ${d.engineName.toUpperCase()}',
                    style: const TextStyle(
                      color: Color(0xFF1B78D0),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Req: #${d.analysisRequestId} | Rev: #${d.positionRevision}',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _buildMetricChip('Processes', '${d.activeProcessCount}', highlight: d.activeProcessCount == 1),
                _buildMetricChip('Backend', d.backend),
                _buildMetricChip('Device', d.device),
                _buildMetricChip('Nodes', '${d.totalNodes}'),
                _buildMetricChip('NPS', '${d.nps}'),
                _buildMetricChip('MultiPV', '${d.multiPv}'),
                _buildMetricChip('Threads', '${d.threads} (${d.optionsApplied ? "applied" : "pending"})'),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Text('Expected: ', style: TextStyle(color: Color(0xFF00D2BE), fontSize: 10.5, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                Expanded(
                  child: Text(
                    d.wdl != null && d.wdl!.length >= 3
                        ? '${((d.wdl![0] + 0.5 * d.wdl![1]) / 10).toStringAsFixed(1)}% ($wdlStr)'
                        : 'N/A',
                    style: const TextStyle(
                      color: Color(0xFFE0E0E0),
                      fontSize: 10.5,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (d.network.isNotEmpty && d.network != 'default') ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Text('Net: ', style: TextStyle(color: Colors.white54, fontSize: 10, fontFamily: 'monospace')),
                  Expanded(
                    child: Text(
                      d.network,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace'),
                    ),
                  ),
                ],
              ),
            ],
            if (d.topPv != null && d.topPv!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Text('PV: ', style: TextStyle(color: Colors.white54, fontSize: 10, fontFamily: 'monospace')),
                  Expanded(
                    child: Text(
                      d.topPv!,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF00D2BE), fontSize: 10, fontFamily: 'monospace'),
                    ),
                  ),
                ],
              ),
            ],
            _buildEnginePerformanceSection(d),
            _buildArrowPipelineSection(d),
          ],
        ),
      ),
    );
  }

  Widget _buildEnginePerformanceSection(EngineDiagnostics d) {
    final isLc0 = d.engineName.toLowerCase().contains('leela') || d.engineName.toLowerCase().contains('lc0');
    final hashLabel = isLc0 ? 'NN Cache' : 'Hash';
    final hashValue = isLc0
        ? '${d.requestedHashMb * 10}k (${d.optionsApplied ? "applied" : "pending"})'
        : '${d.requestedHashMb} MB (${d.optionsApplied ? "applied" : "pending"})';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            const Text(
              'ENGINE PERFORMANCE & UCI OPTIONS',
              style: TextStyle(
                color: Color(0xFF00D2BE),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: d.readyOkReceived ? const Color(0xFF1E3A2F) : const Color(0xFF3A2E1E),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: d.readyOkReceived ? const Color(0xFF00FFD5) : Colors.amber,
                  width: 0.8,
                ),
              ),
              child: Text(
                'UCI: ${d.readyOkReceived ? "READY" : "PENDING"}',
                style: TextStyle(
                  color: d.readyOkReceived ? const Color(0xFF00FFD5) : Colors.amber,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            if (d.engineVersion.isNotEmpty)
              _buildMetricChip('Version', d.engineVersion, highlight: true),
            _buildMetricChip('Threads', '${d.requestedThreads} (${d.optionsApplied ? "applied" : "pending"})', highlight: d.optionsApplied),
            _buildMetricChip(hashLabel, hashValue, highlight: d.optionsApplied),
            _buildMetricChip('MultiPV', '${d.requestedMultiPv} (${d.optionsApplied ? "applied" : "pending"})'),
            _buildMetricChip('Depth', '${d.depth}${d.seldepth > 0 ? "/${d.seldepth}" : ""}'),
            if (d.timeMs > 0)
              _buildMetricChip('Time', '${(d.timeMs / 1000).toStringAsFixed(1)}s'),
            _buildMetricChip('Nodes', '${d.totalNodes}'),
            _buildMetricChip('NPS', '${d.nps}'),
            if (d.hashfull > 0)
              _buildMetricChip('Hashfull', '${(d.hashfull / 10.0).toStringAsFixed(1)}%'),
            if (d.tbhits > 0)
              _buildMetricChip('TB Hits', '${d.tbhits}'),
            if (d.bestmove != null && d.bestmove!.isNotEmpty)
              _buildMetricChip('Best Move', d.bestmove!, highlight: true),
            if (d.currmove != null && d.currmove!.isNotEmpty)
              _buildMetricChip('Curr Move', '${d.currmove}${d.currmovenumber != null ? " (#${d.currmovenumber})" : ""}'),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1C),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: const Color(0xFF2C2C28)),
          ),
          child: Text(
            isLc0
                ? 'ℹ Lc0 MCTS: Neural policy & value evaluation (~50-300 NPS). Low NPS is normal for neural evaluations.'
                : 'ℹ Stockfish NNUE: Multi-threaded alpha-beta tree search (100k-500k+ NPS). High threads boost depth & nodes.',
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 9.5,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildArrowPipelineSection(EngineDiagnostics d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text(
          'ARROW PIPELINE TELEMETRY',
          style: TextStyle(
            color: Color(0xFF00D2BE),
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            _buildMetricChip('PVs Recv', '${d.pvsReceived}'),
            _buildMetricChip('Created', '${d.candidateArrowsCreated}'),
            _buildMetricChip('Filtered', '${d.arrowsAfterFilter}'),
            _buildMetricChip('Painter Recv', '${d.painterReceived}'),
            _buildMetricChip('Rev Check', '${d.passedRevisionCheck}'),
            _buildMetricChip('Legal Check', '${d.passedLegalMoveCheck}'),
            _buildMetricChip('Rendered', '${d.painterRendered}', highlight: true),
          ],
        ),
        if (d.arrowDiagnostics.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text(
            'PER-CANDIDATE STATUS',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 24,
              dataRowMinHeight: 22,
              dataRowMaxHeight: 22,
              horizontalMargin: 8,
              columnSpacing: 12,
              headingTextStyle: const TextStyle(
                color: Colors.white54,
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
              dataTextStyle: const TextStyle(
                color: Colors.white70,
                fontSize: 9.5,
                fontFamily: 'monospace',
              ),
              columns: const [
                DataColumn(label: Text('Rank')),
                DataColumn(label: Text('Move')),
                DataColumn(label: Text('Rev')),
                DataColumn(label: Text('Req')),
                DataColumn(label: Text('Legal')),
                DataColumn(label: Text('Coords')),
                DataColumn(label: Text('Filter')),
                DataColumn(label: Text('Rendered')),
                DataColumn(label: Text('Reason')),
              ],
              rows: d.arrowDiagnostics.map((ad) {
                final revStr = '#${ad.arrowRevision}/#${ad.currentRevision}';
                final reqStr = '#${ad.arrowRequestId}/#${ad.currentRequestId}';
                return DataRow(
                  cells: [
                    DataCell(Text('#${ad.rank}')),
                    DataCell(Text(ad.uciMove, style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(Text(revStr)),
                    DataCell(Text(reqStr)),
                    DataCell(Text(
                      ad.isLegal ? 'YES' : 'NO',
                      style: TextStyle(color: ad.isLegal ? Colors.greenAccent : Colors.redAccent),
                    )),
                    DataCell(Text(
                      ad.isCoordsValid ? 'YES' : 'NO',
                      style: TextStyle(color: ad.isCoordsValid ? Colors.greenAccent : Colors.redAccent),
                    )),
                    DataCell(Text(
                      ad.isFiltered ? 'DROPPED' : 'PASS',
                      style: TextStyle(color: ad.isFiltered ? Colors.amberAccent : Colors.greenAccent),
                    )),
                    DataCell(Text(
                      ad.isRendered ? 'YES' : 'NO',
                      style: TextStyle(
                        color: ad.isRendered ? const Color(0xFF00D2BE) : Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    )),
                    DataCell(Text(
                      ad.rejectionReason ?? '—',
                      style: TextStyle(
                        color: ad.rejectionReason != null ? Colors.orangeAccent : Colors.white38,
                      ),
                    )),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMetricChip(String label, String value, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: highlight ? const Color(0xFF1E3A2F) : const Color(0xFF262421),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: highlight ? const Color(0xFF00D2BE) : const Color(0xFF363431),
          width: 0.8,
        ),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(
                color: highlight ? const Color(0xFF80E5D8) : Colors.white54,
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                color: highlight ? const Color(0xFF00FFD5) : const Color(0xFFE0E0E0),
                fontSize: 10,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
