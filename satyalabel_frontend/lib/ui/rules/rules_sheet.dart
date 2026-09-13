import 'package:flutter/material.dart';

class LMStandardRule {
  const LMStandardRule({
    required this.ruleNumber,
    required this.title,
    required this.category,
    required this.summary,
    required this.legalText,
    required this.commonViolations,
    required this.penaltyCitation,
  });

  final String ruleNumber;
  final String title;
  final String category;
  final String summary;
  final String legalText;
  final String commonViolations;
  final String penaltyCitation;
}

final List<LMStandardRule> kLegalMetrologyRules = [
  const LMStandardRule(
    ruleNumber: 'Rule 6(1)(a)',
    title: 'Manufacturer & Packer Identity',
    category: 'Mandatory Declarations',
    summary:
        'Every package shall bear the name and complete address of the manufacturer or packer, including city, state, and postal code.',
    legalText:
        'The name and complete address of the manufacturer or where the manufacturer is not the packer, the name and address of the manufacturer and packer and for any imported package the name and complete address of the importer shall be declared on every package.',
    commonViolations:
        'Missing PIN code, vague factory description, or omission of importer details for foreign goods.',
    penaltyCitation:
        'Section 36(1) of LM Act 2009: Fine up to ₹25,000 (1st offence), ₹50,000 (2nd offence).',
  ),
  const LMStandardRule(
    ruleNumber: 'Rule 6(1)(b)',
    title: 'Common or Generic Commodity Name',
    category: 'Mandatory Declarations',
    summary:
        'The common or generic name of the commodity contained in the package must be prominently declared.',
    legalText:
        'The common or generic names of the commodity contained in the package and in case of packages with more than one product, the name and number or quantity of each product shall be mentioned on the package.',
    commonViolations:
        'Only branding/fanciful name shown without specifying actual commodity type.',
    penaltyCitation:
        'Compoundable under Section 48; fine up to ₹25,000 for standard violations.',
  ),
  const LMStandardRule(
    ruleNumber: 'Rule 6(1)(c)',
    title: 'Net Quantity Declaration',
    category: 'Measurements & Quantities',
    summary:
        'Net quantity must be declared in standard units of weight, measure, or number (g, kg, ml, l, or pieces).',
    legalText:
        'The net quantity, in terms of the standard unit of weight or measure, of the commodity contained in the package or where the commodity is packed or sold by number, the number of the commodity shall be mentioned.',
    commonViolations:
        'Use of non-standard abbreviations (e.g., "gms", "ml.", "liters"), or net quantity printed below required font height.',
    penaltyCitation:
        'Section 36(1) & (2): Penalty for non-standard units and short-weight delivery.',
  ),
  const LMStandardRule(
    ruleNumber: 'Rule 6(1)(d)',
    title: 'Month & Year of Manufacture / Pre-packing',
    category: 'Dates & Expiry',
    summary:
        'Month and year of manufacture, pre-packing, or import must be clearly indicated (e.g. MM/YYYY).',
    legalText:
        'The month and year in which the commodity is manufactured or pre-packed or imported shall be mentioned in words or digits.',
    commonViolations:
        'Ambiguous date formats, missing manufacture month, or smudged inkjet lot numbers.',
    penaltyCitation:
        'Rule 32 compounding provision; up to ₹25,000 penalty.',
  ),
  const LMStandardRule(
    ruleNumber: 'Rule 6(1)(da)',
    title: 'Unit Sale Price (USP)',
    category: 'Pricing & MRP',
    summary:
        'Mandatory declaration of Unit Sale Price (e.g. ₹ per g, ₹ per kg, ₹ per ml) for packaged commodities.',
    legalText:
        'The unit sale price in rupees, rounded off to the nearest two decimals, shall be declared on every package where net quantity is greater than 1 kg / 1 L or sold by number.',
    commonViolations:
        'Missing USP on multi-packs, calculation errors, or omission on larger grocery packages.',
    penaltyCitation:
        'Amended 2021 Rules (in effect since Dec 2022); treated as missing statutory declaration.',
  ),
  const LMStandardRule(
    ruleNumber: 'Rule 6(1)(e)',
    title: 'Maximum Retail Price (MRP)',
    category: 'Pricing & MRP',
    summary:
        'Retail sale price must state "Maximum or Max. Retail Price ₹... inclusive of all taxes" or "MRP ₹... incl. of all taxes".',
    legalText:
        'The retail sale price of the package shall clearly indicate that it is inclusive of all taxes. No person shall alter, remove, or smudge the price sticker.',
    commonViolations:
        'Dual MRP sticker placement, missing "inclusive of all taxes" clause, or overcharging above printed MRP.',
    penaltyCitation:
        'Section 36(1) & Section 52; strict liability for altered stickers or overcharging.',
  ),
  const LMStandardRule(
    ruleNumber: 'Rule 6(1)(g)',
    title: 'Expiry / Best Before / Use By Date',
    category: 'Dates & Expiry',
    summary:
        'Mandatory expiry or best before declaration for commodities that perish or deteriorate over time.',
    legalText:
        'For packages containing commodities which may become unfit for human consumption after a period of time, the "Best Before" or "Use By" date, month, and year shall be declared.',
    commonViolations:
        'Missing best before statement on perishable packaged items.',
    penaltyCitation:
        'Critical violation triggering immediate product seizure under Section 15.',
  ),
  const LMStandardRule(
    ruleNumber: 'Rule 6(1)(h)',
    title: 'Consumer Care & Grievance Contact',
    category: 'Mandatory Declarations',
    summary:
        'Complete contact details (name, address, telephone number, and email) of consumer redressal officer.',
    legalText:
        'The name, address, telephone number, and email address of the person or office who may be contacted in case of consumer complaints shall be clearly declared.',
    commonViolations:
        'Missing email address or dummy non-functional customer care telephone numbers.',
    penaltyCitation:
        'Section 36(1) penalty; violation frequently cited in consumer forum grievances.',
  ),
  const LMStandardRule(
    ruleNumber: 'Rule 9(1)',
    title: 'Minimum Height of Numerals & Letters',
    category: 'Font & Sizing',
    summary:
        'Declarations must meet minimum font height thresholds based on package size and net quantity.',
    legalText:
        'The height of any numeral and letter shall not be less than the values prescribed in Table 1 (ranging from 1.0 mm for small packs up to 6.0 mm for >4 kg/litre packs).',
    commonViolations:
        'Micro-printed net quantity or MRP hidden in package creases with font height under 1.5 mm.',
    penaltyCitation:
        'Rule 9 non-compliance penalty; compoundable under Section 48.',
  ),
  const LMStandardRule(
    ruleNumber: 'Section 36',
    title: 'Offences & Penalties for Non-Standard Packages',
    category: 'Penalties & Legal',
    summary:
        'Prescribes criminal and pecuniary penalties for manufacturing, packing, or selling non-conforming goods.',
    legalText:
        'Whoever manufactures, packs, imports, sells, distributes, or exposes for sale any pre-packaged commodity which does not conform to the declarations on the package shall be punished with fine.',
    commonViolations:
        'Repeat offender manufacturers distributing unlabelled or mislabelled packages.',
    penaltyCitation:
        'First offence: up to ₹25,000; second offence: up to ₹50,000; subsequent offences: up to ₹1,00,000 or imprisonment up to 1 year.',
  ),
];

class RulesSheet extends StatefulWidget {
  const RulesSheet({super.key});

  @override
  State<RulesSheet> createState() => _RulesSheetState();
}

class _RulesSheetState extends State<RulesSheet> {
  String _searchQuery = '';
  String _selectedCategory = 'All';

  final List<String> _categories = const [
    'All',
    'Mandatory Declarations',
    'Pricing & MRP',
    'Measurements & Quantities',
    'Dates & Expiry',
    'Font & Sizing',
    'Penalties & Legal',
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final filteredRules = kLegalMetrologyRules.where((rule) {
      final matchesCategory =
          _selectedCategory == 'All' || rule.category == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty ||
          rule.ruleNumber.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          rule.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          rule.summary.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          rule.legalText.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('LM(PC) Rules 2011 Standards'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search rules, citations, MRP, font sizes...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                filled: true,
                fillColor: Theme.of(context).scaffoldBackgroundColor,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                for (final cat in _categories)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(cat),
                      selected: _selectedCategory == cat,
                      onSelected: (sel) {
                        setState(() => _selectedCategory = cat);
                      },
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${filteredRules.length} Standards Indexed',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.primary,
                      ),
                ),
                const Text(
                  'Legal Metrology (Packaged Commodities) Rules',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: filteredRules.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.menu_book, size: 48, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text(
                          'No rules found matching "$_searchQuery"',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filteredRules.length,
                    itemBuilder: (context, i) {
                      final rule = filteredRules[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: scheme.primaryContainer,
                            foregroundColor: scheme.onPrimaryContainer,
                            child: const Icon(Icons.gavel, size: 20),
                          ),
                          title: Text(
                            rule.ruleNumber,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                rule.title,
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  rule.category,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: scheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Divider(),
                                  const Text(
                                    'Regulatory Summary',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    rule.summary,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Statutory Wording',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: scheme.surfaceContainerLow,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: scheme.outlineVariant,
                                      ),
                                    ),
                                    child: Text(
                                      rule.legalText,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                        color: scheme.onSurface,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons.warning_amber_rounded,
                                        size: 16,
                                        color: Colors.orange,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: RichText(
                                          text: TextSpan(
                                            style: DefaultTextStyle.of(context)
                                                .style
                                                .copyWith(fontSize: 12),
                                            children: [
                                              const TextSpan(
                                                text: 'Common Violations: ',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                              TextSpan(
                                                  text: rule.commonViolations),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons.security,
                                        size: 16,
                                        color: Colors.red,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: RichText(
                                          text: TextSpan(
                                            style: DefaultTextStyle.of(context)
                                                .style
                                                .copyWith(fontSize: 12),
                                            children: [
                                              const TextSpan(
                                                text: 'Statutory Penalty: ',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                              TextSpan(
                                                  text: rule.penaltyCitation),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
