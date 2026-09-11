"""
PDF Evidence Report Generator for SatyaLabel
============================================
Generates court-ready PDF inspection reports per:
  Legal Metrology (Packaged Commodities) Rules, 2011

Sections in Generated Report:
  1. Header: Department of Consumer Affairs / Legal Metrology Inspection Notice
  2. Inspection Metadata: Scan ID, Timestamp, Inspector Badge, GPS Coordinates
  3. Verdict Banner: COMPLIANT (Green) | NON-COMPLIANT (Red) | NEEDS VERIFICATION (Amber)
  4. Photographic Evidence: Embedded scanned product label image
  5. Mandatory Declarations Audit Table: All 9 statutory fields, extracted values, status
  6. Detailed Violation Findings: Statutory citations (Rule 6(1)(a)-(k)) and exact defects
  7. Verification & Attestation Sign-off: Official stamp & signature placeholder
"""
from __future__ import annotations

import io
from datetime import datetime

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import (
    HRFlowable,
    KeepTogether,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)
from reportlab.platypus import (
    Image as RLImage,
)

from app.services.rule_engine import ComplianceReport, Severity, Verdict


class ReportGenerator:
    """Generates official PDF reports for SatyaLabel inspections."""

    def generate_pdf(
        self,
        compliance_report: ComplianceReport,
        scan_id: str,
        image_bytes: bytes | None = None,
        inspector_badge: str | None = "INSP-DL-2026-084",
        inspector_name: str | None = "Legal Metrology Inspector",
        location_hint: str | None = "Connaught Place Market, New Delhi (28.6315° N, 77.2167° E)",
    ) -> bytes:
        """
        Generate a PDF evidence document as raw bytes.

        Args:
            compliance_report: Result from RuleEngine
            scan_id: Unique UUID of the scan
            image_bytes: Raw JPEG/PNG bytes of the product label
            inspector_badge: Inspector identification number
            inspector_name: Inspector full name
            location_hint: GPS or address description

        Returns:
            bytes: Binary content of generated PDF
        """
        buf = io.BytesIO()
        doc = SimpleDocTemplate(
            buf,
            pagesize=A4,
            rightMargin=18 * mm,
            leftMargin=18 * mm,
            topMargin=16 * mm,
            bottomMargin=16 * mm,
        )

        styles = getSampleStyleSheet()
        title_style = ParagraphStyle(
            "DocTitle",
            parent=styles["Normal"],
            fontName="Helvetica-Bold",
            fontSize=15,
            leading=19,
            alignment=1,  # Center
            textColor=colors.HexColor("#1A365D"),
        )
        subtitle_style = ParagraphStyle(
            "DocSubtitle",
            parent=styles["Normal"],
            fontName="Helvetica-Bold",
            fontSize=10,
            leading=13,
            alignment=1,
            textColor=colors.HexColor("#2B6CB0"),
        )
        section_style = ParagraphStyle(
            "SectionHeader",
            parent=styles["Normal"],
            fontName="Helvetica-Bold",
            fontSize=11,
            leading=15,
            textColor=colors.HexColor("#2D3748"),
            spaceBefore=8,
            spaceAfter=4,
        )
        body_style = ParagraphStyle(
            "BodyDark",
            parent=styles["Normal"],
            fontName="Helvetica",
            fontSize=9,
            leading=12,
            textColor=colors.HexColor("#2D3748"),
        )
        body_bold = ParagraphStyle(
            "BodyDarkBold",
            parent=body_style,
            fontName="Helvetica-Bold",
        )

        elements = []

        # ── 1. Header Banner ──────────────────────────────────────────────────
        elements.append(Paragraph("GOVERNMENT OF INDIA / STATE ENFORCEMENT", subtitle_style))
        elements.append(Paragraph("LEGAL METROLOGY INSPECTION EVIDENCE REPORT", title_style))
        elements.append(
            Paragraph(
                "Automated Statutory Compliance Assessment under Legal Metrology (Packaged Commodities) Rules, 2011",
                ParagraphStyle("SubText", parent=styles["Normal"], fontSize=8, leading=10, alignment=1, textColor=colors.gray),
            )
        )
        elements.append(Spacer(1, 4 * mm))
        elements.append(HRFlowable(width="100%", thickness=1.5, color=colors.HexColor("#1A365D"), spaceAfter=10))

        # ── 2. Inspection Metadata ────────────────────────────────────────────
        now_str = datetime.now().strftime("%d-%b-%Y %H:%M:%S IST")
        meta_data = [
            [
                Paragraph("<b>Inspection ID:</b>", body_style),
                Paragraph(scan_id, body_style),
                Paragraph("<b>Date & Time:</b>", body_style),
                Paragraph(now_str, body_style),
            ],
            [
                Paragraph("<b>Inspector:</b>", body_style),
                Paragraph(f"{inspector_name} ({inspector_badge})", body_style),
                Paragraph("<b>Location:</b>", body_style),
                Paragraph(location_hint or "Not recorded", body_style),
            ],
        ]
        meta_table = Table(meta_data, colWidths=[28 * mm, 58 * mm, 26 * mm, 62 * mm])
        meta_table.setStyle(
            TableStyle([
                ("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#F7FAFC")),
                ("PADDING", (0, 0), (-1, -1), 4),
                ("BOX", (0, 0), (-1, -1), 0.5, colors.HexColor("#E2E8F0")),
                ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
            ])
        )
        elements.append(meta_table)
        elements.append(Spacer(1, 4 * mm))

        # ── 3. Verdict Banner ─────────────────────────────────────────────────
        if compliance_report.verdict == Verdict.COMPLIANT:
            banner_bg = colors.HexColor("#C6F6D5")
            banner_text_color = colors.HexColor("#22543D")
            verdict_text = "VERDICT: COMPLIANT — ALL STATUTORY DECLARATIONS SATISFIED"
        elif compliance_report.verdict == Verdict.NON_COMPLIANT:
            banner_bg = colors.HexColor("#FED7D7")
            banner_text_color = colors.HexColor("#742A2A")
            verdict_text = f"VERDICT: NON-COMPLIANT — {len(compliance_report.critical_violations)} STATUTORY VIOLATION(S) DETECTED"
        else:
            banner_bg = colors.HexColor("#FEEBC8")
            banner_text_color = colors.HexColor("#7B341E")
            verdict_text = "VERDICT: NEEDS VERIFICATION — INCONCLUSIVE OCR CONFIDENCE"

        verdict_table = Table(
            [[Paragraph(f"<b>{verdict_text}</b>", ParagraphStyle("VText", fontName="Helvetica-Bold", fontSize=10.5, alignment=1, textColor=banner_text_color))]],
            colWidths=[174 * mm],
        )
        verdict_table.setStyle(
            TableStyle([
                ("BACKGROUND", (0, 0), (-1, -1), banner_bg),
                ("PADDING", (0, 0), (-1, -1), 7),
                ("BOX", (0, 0), (-1, -1), 1.2, banner_text_color),
                ("ALIGN", (0, 0), (-1, -1), "CENTER"),
            ])
        )
        elements.append(verdict_table)
        elements.append(Spacer(1, 4 * mm))

        # ── 4. Photographic Evidence & Key Declarations ────────────────────────
        elements.append(Paragraph("1. Label Evidence & Core Declarations", section_style))

        # Build table of declarations
        fields = compliance_report.extracted_fields
        field_rows = [
            [
                Paragraph("<b>Statutory Declaration</b>", body_bold),
                Paragraph("<b>Extracted Print</b>", body_bold),
                Paragraph("<b>Rule Reference</b>", body_bold),
                Paragraph("<b>Status</b>", body_bold),
            ]
        ]

        declarations = [
            ("Maximum Retail Price (MRP)", fields.mrp, "Rule 6(1)(f)"),
            ("Net Quantity", fields.net_quantity, "Rule 6(1)(b)"),
            ("Date of Mfg / Packing", fields.mfg_date, "Rule 6(1)(e)"),
            ("Best Before / Expiry", fields.best_before_date, "Rule 6(1)(g)"),
            ("Manufacturer / Packer", fields.manufacturer, "Rule 6(1)(a)"),
            ("Consumer Care Contact", fields.consumer_phone, "Rule 6(1)(k)"),
            ("Consumer Care Email", fields.consumer_email, "Rule 6(1)(k)"),
            ("Batch / Lot Number", fields.batch_number, "Rule 6(1)(d)"),
        ]

        for name, fld, rule in declarations:
            val_text = fld.value if fld.is_found else "<i>[NOT FOUND]</i>"
            if not fld.is_found:
                status_cell = Paragraph("<font color='#E53E3E'><b>ABSENT</b></font>", body_style)
            elif fld.confidence < 0.50:
                status_cell = Paragraph("<font color='#DD6B20'><b>LOW CONF</b></font>", body_style)
            else:
                status_cell = Paragraph("<font color='#38A169'><b>PRESENT</b></font>", body_style)

            field_rows.append([
                Paragraph(name, body_style),
                Paragraph(val_text[:45], body_style),
                Paragraph(rule, body_style),
                status_cell,
            ])

        decl_table = Table(field_rows, colWidths=[48 * mm, 62 * mm, 34 * mm, 30 * mm])
        decl_table.setStyle(
            TableStyle([
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#EDF2F7")),
                ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#CBD5E0")),
                ("PADDING", (0, 0), (-1, -1), 3.5),
                ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
            ])
        )

        # If image bytes exist, put thumbnail alongside or above
        if image_bytes:
            try:
                img_io = io.BytesIO(image_bytes)
                rl_img = RLImage(img_io, width=45 * mm, height=35 * mm)
                # Combined layout
                evidence_box = Table(
                    [[rl_img, decl_table]],
                    colWidths=[48 * mm, 126 * mm],
                )
                evidence_box.setStyle(TableStyle([
                    ("VALIGN", (0, 0), (-1, -1), "TOP"),
                    ("PADDING", (0, 0), (-1, -1), 0),
                ]))
                elements.append(evidence_box)
            except Exception:
                elements.append(decl_table)
        else:
            elements.append(decl_table)

        elements.append(Spacer(1, 4 * mm))

        # ── 5. Detailed Violations List ───────────────────────────────────────
        elements.append(Paragraph("2. Statutory Violations & Irregularities", section_style))
        if not compliance_report.violations:
            elements.append(
                Paragraph(
                    "<i>No statutory violations detected. All mandatory declarations under the Legal Metrology "
                    "(Packaged Commodities) Rules, 2011 appear to be present in prima facie order.</i>",
                    body_style,
                )
            )
        else:
            viol_rows = [
                [
                    Paragraph("<b>#</b>", body_bold),
                    Paragraph("<b>Severity</b>", body_bold),
                    Paragraph("<b>Rule Reference</b>", body_bold),
                    Paragraph("<b>Defect Description</b>", body_bold),
                ]
            ]
            for idx, v in enumerate(compliance_report.violations, 1):
                sev_color = "#E53E3E" if v.severity == Severity.CRITICAL else "#DD6B20"
                sev_text = f"<font color='{sev_color}'><b>{v.severity.value}</b></font>"
                viol_rows.append([
                    Paragraph(str(idx), body_style),
                    Paragraph(sev_text, body_style),
                    Paragraph(v.rule_reference, body_style),
                    Paragraph(v.message, body_style),
                ])

            viol_table = Table(viol_rows, colWidths=[10 * mm, 28 * mm, 44 * mm, 92 * mm])
            viol_table.setStyle(
                TableStyle([
                    ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#FED7D7")),
                    ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#FEB2B2")),
                    ("PADDING", (0, 0), (-1, -1), 4),
                    ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ])
            )
            elements.append(viol_table)

        elements.append(Spacer(1, 6 * mm))

        # ── 6. Attestation & Sign-off Block ───────────────────────────────────
        signoff_data = [
            [
                Paragraph("<b>Official Verification Notice:</b><br/>"
                          "This inspection record was processed via SatyaLabel's automated "
                          "statutory rule engine. It constitutes contemporaneous prima facie evidence "
                          "for proceedings under Section 36 of the Legal Metrology Act, 2009.",
                          ParagraphStyle("Notice", parent=body_style, fontSize=7.5, leading=10, textColor=colors.dimgray)),
                Paragraph("<br/><br/>___________________________<br/><b>Inspecting Officer Signature</b><br/>"
                          "Legal Metrology Department",
                          ParagraphStyle("Sign", parent=body_style, fontSize=8, alignment=1)),
            ]
        ]
        signoff_table = Table(signoff_data, colWidths=[110 * mm, 64 * mm])
        signoff_table.setStyle(TableStyle([
            ("VALIGN", (0, 0), (-1, -1), "TOP"),
            ("PADDING", (0, 0), (-1, -1), 2),
        ]))
        elements.append(KeepTogether([signoff_table]))

        doc.build(elements)
        return buf.getvalue()


_report_generator = ReportGenerator()


def generate_inspection_pdf(
    compliance_report: ComplianceReport,
    scan_id: str,
    image_bytes: bytes | None = None,
    inspector_badge: str | None = "INSP-DL-2026-084",
    inspector_name: str | None = "Legal Metrology Inspector",
    location_hint: str | None = None,
) -> bytes:
    """Convenience function to generate a compliance PDF report."""
    return _report_generator.generate_pdf(
        compliance_report=compliance_report,
        scan_id=scan_id,
        image_bytes=image_bytes,
        inspector_badge=inspector_badge,
        inspector_name=inspector_name,
        location_hint=location_hint,
    )
