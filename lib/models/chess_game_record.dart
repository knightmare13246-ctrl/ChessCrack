import 'chess_time_control.dart';

enum GameTerminationReason {
  checkmate,
  timeout,
  resignation,
  drawAgreement,
  stalemate,
  insufficientMaterial,
  threefoldRepetition,
  fiftyMoves,
  aborted,
}

class ChessGameRecord {
  final String id;
  final DateTime date;
  final String whitePlayer;
  final String blackPlayer;
  final String userSide; // 'white' or 'black'
  final String result; // '1-0', '0-1', '1/2-1/2', '*'
  final GameTerminationReason terminationReason;
  final ChessTimeControl timeControl;
  final int moveCount;
  final String finalFen;
  final String pgn;

  const ChessGameRecord({
    required this.id,
    required this.date,
    required this.whitePlayer,
    required this.blackPlayer,
    required this.userSide,
    required this.result,
    required this.terminationReason,
    required this.timeControl,
    required this.moveCount,
    required this.finalFen,
    required this.pgn,
  });

  String get displayTitle => '$whitePlayer vs $blackPlayer';

  String get readableTermination {
    switch (terminationReason) {
      case GameTerminationReason.checkmate:
        return 'Checkmate';
      case GameTerminationReason.timeout:
        return 'Time forfeit';
      case GameTerminationReason.resignation:
        return 'Resignation';
      case GameTerminationReason.drawAgreement:
        return 'Mutual agreement';
      case GameTerminationReason.stalemate:
        return 'Stalemate';
      case GameTerminationReason.insufficientMaterial:
        return 'Insufficient material';
      case GameTerminationReason.threefoldRepetition:
        return 'Threefold repetition';
      case GameTerminationReason.fiftyMoves:
        return '50-move rule';
      case GameTerminationReason.aborted:
        return 'Aborted';
    }
  }

  Map<String, dynamic> toJson({bool includePgn = true}) => {
        'id': id,
        'date': date.toIso8601String(),
        'whitePlayer': whitePlayer,
        'blackPlayer': blackPlayer,
        'userSide': userSide,
        'result': result,
        'terminationReason': terminationReason.name,
        'timeControl': timeControl.toJson(),
        'moveCount': moveCount,
        'finalFen': finalFen,
        if (includePgn) 'pgn': pgn,
      };

  factory ChessGameRecord.fromJson(Map<String, dynamic> json) {
    GameTerminationReason reason;
    try {
      reason = GameTerminationReason.values.byName(
        json['terminationReason'] as String? ?? 'aborted',
      );
    } catch (_) {
      reason = GameTerminationReason.aborted;
    }

    return ChessGameRecord(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      whitePlayer: json['whitePlayer'] as String? ?? 'White',
      blackPlayer: json['blackPlayer'] as String? ?? 'Black',
      userSide: json['userSide'] as String? ?? 'white',
      result: json['result'] as String? ?? '*',
      terminationReason: reason,
      timeControl: json['timeControl'] != null
          ? ChessTimeControl.fromJson(json['timeControl'] as Map<String, dynamic>)
          : const ChessTimeControl.unlimited(),
      moveCount: json['moveCount'] as int? ?? 0,
      finalFen: json['finalFen'] as String? ?? '',
      pgn: json['pgn'] as String? ?? '',
    );
  }
}
