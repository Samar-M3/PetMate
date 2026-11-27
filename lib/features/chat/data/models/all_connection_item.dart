import '../../../home/data/models/connection_request_model.dart';
import 'match_conversation_model.dart';

enum AllConnectionItemType { activeChat, incomingRequest, outgoingRequest }

class AllConnectionItem {
  final AllConnectionItemType itemType;
  final String id;
  final DateTime sortAt;
  final MatchConversationModel? match;
  final ConnectionRequestModel? incomingRequest;
  final OutgoingRequestModel? outgoingRequest;

  const AllConnectionItem({
    required this.itemType,
    required this.id,
    required this.sortAt,
    this.match,
    this.incomingRequest,
    this.outgoingRequest,
  });

  factory AllConnectionItem.fromJson(Map<String, dynamic> json) {
    final typeStr = json['itemType'] as String? ?? '';
    final AllConnectionItemType itemType;
    switch (typeStr) {
      case 'ACTIVE_CHAT':
        itemType = AllConnectionItemType.activeChat;
        break;
      case 'INCOMING_REQUEST':
        itemType = AllConnectionItemType.incomingRequest;
        break;
      default:
        itemType = AllConnectionItemType.outgoingRequest;
        break;
    }

    final sortAt = json['sortAt'] is String
        ? (DateTime.tryParse(json['sortAt'] as String) ?? DateTime.now())
        : DateTime.now();

    return AllConnectionItem(
      itemType: itemType,
      id: json['id'] as String? ?? '',
      sortAt: sortAt,
      match: json['match'] is Map<String, dynamic>
          ? MatchConversationModel.fromJson(
              json['match'] as Map<String, dynamic>,
            )
          : null,
      incomingRequest: json['incomingRequest'] is Map<String, dynamic>
          ? ConnectionRequestModel.fromJson(
              json['incomingRequest'] as Map<String, dynamic>,
            )
          : null,
      outgoingRequest: json['outgoingRequest'] is Map<String, dynamic>
          ? OutgoingRequestModel.fromJson(
              json['outgoingRequest'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}
