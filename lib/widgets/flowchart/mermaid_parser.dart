/// Parses Mermaid flowchart syntax into a graph model.
/// Supports: graph TD/LR/BT/RL, node shapes [], (), (()), {}, -->, ---,
/// labeled edges, subgraphs, and style classes.

class MermaidGraph {
  final List<MermaidNode> nodes;
  final List<MermaidEdge> edges;
  final MermaidDirection direction;
  final List<MermaidSubgraph> subgraphs;

  MermaidGraph({
    required this.nodes,
    required this.edges,
    required this.direction,
    this.subgraphs = const [],
  });
}

enum MermaidDirection { topDown, leftRight, bottomTop, rightLeft }

enum MermaidNodeShape { rectangle, rounded, circle, diamond, stadium, hexagon }

class MermaidNode {
  final String id;
  final String label;
  final MermaidNodeShape shape;
  String? subgraphId;

  MermaidNode({required this.id, required this.label, this.shape = MermaidNodeShape.rectangle, this.subgraphId});
}

class MermaidEdge {
  final String fromId;
  final String toId;
  final String? label;
  final bool isDashed;

  MermaidEdge({required this.fromId, required this.toId, this.label, this.isDashed = false});
}

class MermaidSubgraph {
  final String id;
  final String label;
  final List<String> nodeIds;

  MermaidSubgraph({required this.id, required this.label, required this.nodeIds});
}

// Pre-compiled patterns
final _directionPattern = RegExp(r'^(?:graph|flowchart)\s+(TD|TB|LR|BT|RL)', caseSensitive: false);
final _nodeWithShape = RegExp(r'^(\w+)\s*(\[.*?\]|\(.*?\)|\(\(.*?\)\)|\{.*?\}|\[\/.*?\/\]|\[\[.*?\]\])');
final _edgePattern = RegExp(
  r'^(\w+)\s*(-->|---|-\.->|-\.-|==>|===|--\s*[^-].*?-->|--\s*[^-].*?---|-->\|.*?\||--\|.*?\|)\s*(\w+)',
);
final _labeledArrow = RegExp(r'-->\|(.+?)\|');
final _labeledDash = RegExp(r'--\s*(.+?)\s*-->');
final _subgraphStart = RegExp(r'^subgraph\s+(\w+)\s*\[?(.*?)\]?\s*$', caseSensitive: false);

MermaidGraph parseMermaid(String source) {
  final lines = source.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
  final nodes = <String, MermaidNode>{};
  final edges = <MermaidEdge>[];
  final subgraphs = <MermaidSubgraph>[];
  var direction = MermaidDirection.topDown;

  String? currentSubgraph;
  List<String>? currentSubgraphNodes;
  String currentSubgraphLabel = '';

  for (final line in lines) {
    // Skip comments
    if (line.startsWith('%%')) continue;

    // Direction
    final dirMatch = _directionPattern.firstMatch(line);
    if (dirMatch != null) {
      final d = dirMatch.group(1)!.toUpperCase();
      direction = switch (d) {
        'LR' => MermaidDirection.leftRight,
        'BT' => MermaidDirection.bottomTop,
        'RL' => MermaidDirection.rightLeft,
        _ => MermaidDirection.topDown,
      };
      continue;
    }

    // Subgraph start
    final subMatch = _subgraphStart.firstMatch(line);
    if (subMatch != null) {
      currentSubgraph = subMatch.group(1)!;
      currentSubgraphLabel = subMatch.group(2)?.isNotEmpty == true ? subMatch.group(2)! : currentSubgraph;
      currentSubgraphNodes = [];
      continue;
    }

    // Subgraph end
    if (line.toLowerCase() == 'end' && currentSubgraph != null) {
      subgraphs.add(MermaidSubgraph(
        id: currentSubgraph!,
        label: currentSubgraphLabel,
        nodeIds: currentSubgraphNodes!,
      ));
      currentSubgraph = null;
      currentSubgraphNodes = null;
      continue;
    }

    // Skip style/classDef/class lines
    if (line.startsWith('style ') || line.startsWith('classDef ') || line.startsWith('class ')) continue;

    // Try edge first
    final edgeMatch = _edgePattern.firstMatch(line);
    if (edgeMatch != null) {
      final fromId = edgeMatch.group(1)!;
      final arrow = edgeMatch.group(2)!;
      final toId = edgeMatch.group(3)!;

      _ensureNode(nodes, fromId, currentSubgraph);
      _ensureNode(nodes, toId, currentSubgraph);
      if (currentSubgraphNodes != null) {
        if (!currentSubgraphNodes.contains(fromId)) currentSubgraphNodes.add(fromId);
        if (!currentSubgraphNodes.contains(toId)) currentSubgraphNodes.add(toId);
      }

      String? edgeLabel;
      final lblMatch1 = _labeledArrow.firstMatch(arrow);
      final lblMatch2 = _labeledDash.firstMatch(arrow);
      if (lblMatch1 != null) {
        edgeLabel = lblMatch1.group(1);
      } else if (lblMatch2 != null) {
        edgeLabel = lblMatch2.group(1);
      }

      final isDashed = arrow.contains('-.-') || arrow.contains('-.->');

      edges.add(MermaidEdge(fromId: fromId, toId: toId, label: edgeLabel, isDashed: isDashed));

      // Parse remaining part of line after the edge for chained edges
      final remaining = line.substring(edgeMatch.end).trim();
      if (remaining.isNotEmpty) {
        _parseChainedEdge(remaining, toId, nodes, edges, currentSubgraph, currentSubgraphNodes);
      }
      continue;
    }

    // Standalone node definition
    final nodeMatch = _nodeWithShape.firstMatch(line);
    if (nodeMatch != null) {
      final id = nodeMatch.group(1)!;
      final shapePart = nodeMatch.group(2)!;
      final parsed = _parseNodeShape(id, shapePart);
      parsed.subgraphId = currentSubgraph;
      nodes[id] = parsed;
      if (currentSubgraphNodes != null && !currentSubgraphNodes.contains(id)) {
        currentSubgraphNodes.add(id);
      }
      continue;
    }

    // Bare node id
    final bareId = RegExp(r'^(\w+)\s*$').firstMatch(line);
    if (bareId != null && bareId.group(1) != 'end') {
      _ensureNode(nodes, bareId.group(1)!, currentSubgraph);
      if (currentSubgraphNodes != null && !currentSubgraphNodes.contains(bareId.group(1)!)) {
        currentSubgraphNodes.add(bareId.group(1)!);
      }
    }
  }

  return MermaidGraph(
    nodes: nodes.values.toList(),
    edges: edges,
    direction: direction,
    subgraphs: subgraphs,
  );
}

void _parseChainedEdge(
  String text, String prevId,
  Map<String, MermaidNode> nodes, List<MermaidEdge> edges,
  String? subgraph, List<String>? subgraphNodes,
) {
  final chain = _edgePattern.firstMatch('$prevId $text');
  if (chain != null) {
    final arrow = chain.group(2)!;
    final toId = chain.group(3)!;
    _ensureNode(nodes, toId, subgraph);
    if (subgraphNodes != null && !subgraphNodes.contains(toId)) subgraphNodes.add(toId);

    String? label;
    final l1 = _labeledArrow.firstMatch(arrow);
    final l2 = _labeledDash.firstMatch(arrow);
    if (l1 != null) label = l1.group(1);
    if (l2 != null) label = l2.group(1);

    edges.add(MermaidEdge(fromId: prevId, toId: toId, label: label, isDashed: arrow.contains('-.-')));
  }
}

void _ensureNode(Map<String, MermaidNode> nodes, String id, String? subgraph) {
  if (!nodes.containsKey(id)) {
    nodes[id] = MermaidNode(id: id, label: id, subgraphId: subgraph);
  } else if (subgraph != null && nodes[id]!.subgraphId == null) {
    nodes[id]!.subgraphId = subgraph;
  }
}

MermaidNode _parseNodeShape(String id, String raw) {
  if (raw.startsWith('((') && raw.endsWith('))')) {
    return MermaidNode(id: id, label: raw.substring(2, raw.length - 2), shape: MermaidNodeShape.circle);
  }
  if (raw.startsWith('(') && raw.endsWith(')')) {
    return MermaidNode(id: id, label: raw.substring(1, raw.length - 1), shape: MermaidNodeShape.stadium);
  }
  if (raw.startsWith('{') && raw.endsWith('}')) {
    return MermaidNode(id: id, label: raw.substring(1, raw.length - 1), shape: MermaidNodeShape.diamond);
  }
  if (raw.startsWith('[[') && raw.endsWith(']]')) {
    return MermaidNode(id: id, label: raw.substring(2, raw.length - 2), shape: MermaidNodeShape.hexagon);
  }
  if (raw.startsWith('[/') && raw.endsWith('/]')) {
    return MermaidNode(id: id, label: raw.substring(2, raw.length - 2), shape: MermaidNodeShape.rounded);
  }
  // Default [...]
  final label = raw.startsWith('[') && raw.endsWith(']') ? raw.substring(1, raw.length - 1) : raw;
  return MermaidNode(id: id, label: label, shape: MermaidNodeShape.rectangle);
}
