from docx import Document
from docx.shared import Inches, Pt
from docx.enum.text import WD_LINE_SPACING

def main(out_path: str):
    doc = Document()

    # Page setup (1 inch margins)
    section = doc.sections[0]
    section.top_margin = Inches(1)
    section.bottom_margin = Inches(1)
    section.left_margin = Inches(1)
    section.right_margin = Inches(1)

    # Normal style: Times New Roman 12, double-spaced, first line indent 0.5"
    normal = doc.styles['Normal']
    normal.font.name = 'Times New Roman'
    normal.font.size = Pt(12)
    pformat = normal.paragraph_format
    pformat.line_spacing_rule = WD_LINE_SPACING.DOUBLE
    pformat.first_line_indent = Inches(0.5)
    pformat.space_before = Pt(0)
    pformat.space_after = Pt(0)

    # Heading styles (APA-ish: bold; no indent)
    for hname in ['Heading 1', 'Heading 2', 'Heading 3']:
        if hname in doc.styles:
            st = doc.styles[hname]
            st.font.name = 'Times New Roman'
            st.font.size = Pt(12)
            st.font.bold = True
            st.paragraph_format.first_line_indent = Inches(0)
            st.paragraph_format.line_spacing_rule = WD_LINE_SPACING.DOUBLE
            st.paragraph_format.space_before = Pt(0)
            st.paragraph_format.space_after = Pt(0)

    doc.save(out_path)

if __name__ == '__main__':
    import sys
    out = sys.argv[1] if len(sys.argv) > 1 else 'apa7_reference.docx'
    main(out)
