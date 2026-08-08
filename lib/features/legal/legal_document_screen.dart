import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Legal Document Screen
///
/// Displays Privacy Policy or Terms of Service in a premium styled viewer.
/// Renders markdown content from bundled assets.
class LegalDocumentScreen extends StatefulWidget {
  final LegalDocumentType documentType;

  const LegalDocumentScreen({
    super.key,
    required this.documentType,
  });

  @override
  State<LegalDocumentScreen> createState() => _LegalDocumentScreenState();
}

enum LegalDocumentType {
  privacyPolicy,
  termsOfService,
}

class _LegalDocumentScreenState extends State<LegalDocumentScreen> {
  String _content = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    try {
      final assetPath = widget.documentType == LegalDocumentType.privacyPolicy
          ? 'assets/legal/privacy_policy.md'
          : 'assets/legal/terms_of_service.md';

      final content = await rootBundle.loadString(assetPath);
      setState(() {
        _content = content;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _content = 'Unable to load document. Please try again later.';
        _isLoading = false;
      });
    }
  }

  String get _title {
    return widget.documentType == LegalDocumentType.privacyPolicy
        ? 'Privacy Policy'
        : 'Terms of Service';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0F) : Colors.grey[50],
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0A0A0F) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            color: isDark ? Colors.white : Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _title,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: _MarkdownRenderer(content: _content, isDark: isDark),
            ),
    );
  }
}

/// Simple Markdown Renderer
///
/// Parses and renders basic markdown without external dependencies.
class _MarkdownRenderer extends StatelessWidget {
  final String content;
  final bool isDark;

  const _MarkdownRenderer({
    required this.content,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final lines = content.split('\n');
    final widgets = <Widget>[];

    bool inTable = false;
    List<String> tableRows = [];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Handle tables
      if (line.startsWith('|')) {
        if (!inTable) {
          inTable = true;
          tableRows = [];
        }
        tableRows.add(line);
        continue;
      } else if (inTable) {
        // End of table
        widgets.add(_buildTable(tableRows));
        widgets.add(const SizedBox(height: 16));
        inTable = false;
        tableRows = [];
      }

      // Skip empty lines
      if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }

      // Horizontal rule
      if (line.trim() == '---') {
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Divider(
            color: isDark ? Colors.white24 : Colors.black12,
            thickness: 1,
          ),
        ));
        continue;
      }

      // Headers
      if (line.startsWith('# ')) {
        widgets.add(_buildHeader(line.substring(2), 1));
        continue;
      }
      if (line.startsWith('## ')) {
        widgets.add(_buildHeader(line.substring(3), 2));
        continue;
      }
      if (line.startsWith('### ')) {
        widgets.add(_buildHeader(line.substring(4), 3));
        continue;
      }

      // List items
      if (line.startsWith('- ')) {
        widgets.add(_buildListItem(line.substring(2)));
        continue;
      }

      // Regular paragraph
      widgets.add(_buildParagraph(line));
    }

    // Handle any remaining table
    if (inTable && tableRows.isNotEmpty) {
      widgets.add(_buildTable(tableRows));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildHeader(String text, int level) {
    final sizes = {1: 24.0, 2: 20.0, 3: 17.0};
    final weights = {1: FontWeight.bold, 2: FontWeight.w600, 3: FontWeight.w600};

    return Padding(
      padding: EdgeInsets.only(
        top: level == 1 ? 8 : 20,
        bottom: 12,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: sizes[level],
          fontWeight: weights[level],
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _buildRichText(text),
    );
  }

  Widget _buildListItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '•  ',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
              fontSize: 15,
            ),
          ),
          Expanded(child: _buildRichText(text)),
        ],
      ),
    );
  }

  Widget _buildRichText(String text) {
    // Parse bold text (**text**)
    final spans = <TextSpan>[];
    final regex = RegExp(r'\*\*(.+?)\*\*');
    int lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      // Add text before the match
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      // Add bold text
      spans.add(TextSpan(
        text: match.group(1),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ));
      lastEnd = match.end;
    }

    // Add remaining text
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 15,
          height: 1.6,
          color: isDark ? Colors.white70 : Colors.black87,
        ),
        children: spans.isEmpty ? [TextSpan(text: text)] : spans,
      ),
    );
  }

  Widget _buildTable(List<String> rows) {
    if (rows.length < 2) return const SizedBox.shrink();

    // Parse header
    final headerCells = rows[0]
        .split('|')
        .where((c) => c.trim().isNotEmpty)
        .map((c) => c.trim())
        .toList();

    // Skip separator row (index 1) and parse data rows
    final dataRows = <List<String>>[];
    for (int i = 2; i < rows.length; i++) {
      final cells = rows[i]
          .split('|')
          .where((c) => c.trim().isNotEmpty)
          .map((c) => c.trim())
          .toList();
      if (cells.isNotEmpty) {
        dataRows.add(cells);
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(
          color: isDark ? Colors.white24 : Colors.black12,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Table(
          border: TableBorder(
            horizontalInside: BorderSide(
              color: isDark ? Colors.white12 : Colors.black12,
            ),
          ),
          children: [
            // Header row
            TableRow(
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
              ),
              children: headerCells.map((cell) => Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  cell,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              )).toList(),
            ),
            // Data rows
            ...dataRows.map((row) => TableRow(
              children: row.map((cell) => Padding(
                padding: const EdgeInsets.all(12),
                child: _buildTableCell(cell),
              )).toList(),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildTableCell(String text) {
    // Check if it's a link [text](url)
    final linkRegex = RegExp(r'\[(.+?)\]\((.+?)\)');
    final match = linkRegex.firstMatch(text);

    if (match != null) {
      return Text(
        match.group(1) ?? text,
        style: TextStyle(
          fontSize: 13,
          color: isDark ? Colors.blue[300] : Colors.blue[700],
          decoration: TextDecoration.underline,
        ),
      );
    }

    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        color: isDark ? Colors.white70 : Colors.black87,
      ),
    );
  }
}
