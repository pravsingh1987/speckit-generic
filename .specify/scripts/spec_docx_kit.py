#!/usr/bin/env python3
"""Shared Word styling for client-facing specifications generated from a repo.

One styling module rather than a copy per document, so every specification a
project emits renders identically — same purple headings, same 8.5pt Table Grid
with a white-on-purple header row, same Consolas for field names and payloads.
The point is that a spec can be regenerated from source and diffed, instead of
being hand-edited in Word and drifting away from the code it describes.

Import and call build(title, subtitle, strapline, version, dated) to get a
Document with the title block already laid down, then use the returned helper
namespace for headings, tables, code blocks and callouts.

Contents pages are the part usually got wrong. d.toc() bookmarks every heading
and emits PAGEREF fields with updateFields set, which is what makes Word compute
real page numbers when the document is opened; without it the entries navigate
but show no numbers.

Requires python-docx:  pip install python-docx

Usage:
    from spec_docx_kit import build
    d = build("Order Integration API Specification",
              subtitle="Inbound order intake and status",
              version="v0.1", dated="01-Jan-2026",
              org_line="Acme Corp — Salesforce Sales Cloud")
    d.h1("1. Overview"); d.para("..."); d.table([...], [...])
    d.save(path)
"""

from __future__ import annotations

import datetime
import os
from dataclasses import dataclass
from typing import Iterable, Sequence

from docx import Document
from docx.enum.section import WD_ORIENT
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_BREAK
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Inches, Pt, RGBColor

PURPLE = RGBColor(0x4C, 0x1D, 0x95)
GREY = RGBColor(0x37, 0x41, 0x51)
RED = RGBColor(0xB9, 0x1C, 0x1C)
GREEN = RGBColor(0x06, 0x6E, 0x3A)


def shade(cell, hexcode: str) -> None:
    el = OxmlElement("w:shd")
    el.set(qn("w:val"), "clear")
    el.set(qn("w:fill"), hexcode)
    cell._tc.get_or_add_tcPr().append(el)


def _field(run_parent, instr, cached):
    """Append a Word field: begin, instruction, cached result, end.

    The cached result is what a reader sees before fields are refreshed. Word
    replaces it on open because build() sets updateFields, but a viewer that
    does not evaluate fields still shows something sensible rather than blank.
    """
    for kind, payload in (("begin", None), (None, instr), ("separate", None),
                          (None, None), ("end", None)):
        r = OxmlElement("w:r")
        if kind:
            fc = OxmlElement("w:fldChar")
            fc.set(qn("w:fldCharType"), kind)
            r.append(fc)
        elif payload is not None:
            t = OxmlElement("w:instrText")
            t.set(qn("xml:space"), "preserve")
            t.text = payload
            r.append(t)
        else:
            t = OxmlElement("w:t")
            t.text = cached
            r.append(t)
        run_parent.append(r)


@dataclass
class SpecDoc:
    doc: Document

    def __post_init__(self):
        # (level, text, bookmark name) captured as headings are written, so the
        # contents page is generated from the document rather than maintained
        # alongside it and able to drift out of step.
        self._outline: list[tuple[int, str, str]] = []
        self._bmk = 0

    # ---------------------------------------------------------- headings ----
    def _heading(self, text, style, level):
        p = self.doc.add_paragraph(text, style=style)
        self._bmk += 1
        name = f"_Toc_{self._bmk:04d}"
        start = OxmlElement("w:bookmarkStart")
        start.set(qn("w:id"), str(self._bmk))
        start.set(qn("w:name"), name)
        end = OxmlElement("w:bookmarkEnd")
        end.set(qn("w:id"), str(self._bmk))
        p._p.insert(0, start)
        p._p.append(end)
        self._outline.append((level, text, name))
        return p

    def h1(self, text):
        return self._heading(text, "Heading 1", 1)

    def h2(self, text):
        return self._heading(text, "Heading 2", 2)

    def h3(self, text):
        return self._heading(text, "Heading 3", 3)

    # ------------------------------------------------------------- toc ------
    def toc(self, anchor=None, heading="Contents", levels=(1, 2), lead=None):
        """Insert a contents page directly after `anchor`.

        **Call this last**, once every heading has been written; it is then
        inserted back up at the front. Calling it early produces an empty
        contents page, because there are no headings to list yet.

        `anchor` defaults to the end of the title block laid down by build(),
        which is where a contents page belongs, so the usual call is `d.toc()`.

        Each entry is a real internal hyperlink to the heading's bookmark, so
        clicking it lands on the content itself in Word, Google Docs and
        LibreOffice alike; the page number beside it is a PAGEREF field pointing
        at the same bookmark, which Word fills in on open.
        """
        if anchor is None:
            anchor = getattr(self, "title_block_end", None)
            if anchor is None:
                raise ValueError(
                    "toc() needs an anchor paragraph. Documents made with build() "
                    "carry one as .title_block_end; pass anchor= explicitly otherwise."
                )
        built = []

        def new_para(style=None):
            p = self.doc.add_paragraph(style=style) if style else self.doc.add_paragraph()
            built.append(p)
            return p

        new_para().add_run().add_break(WD_BREAK.PAGE)
        h = new_para("Heading 1")
        h.add_run(heading)
        if lead:
            p = new_para()
            r = p.add_run(lead)
            r.italic = True
            r.font.size = Pt(8.5)
            r.font.color.rgb = GREY

        for level, text, name in self._outline:
            if level not in levels:
                continue
            p = new_para()
            pf = p.paragraph_format
            pf.left_indent = Inches(0.0 if level == 1 else 0.28)
            pf.space_before = Pt(6 if level == 1 else 0)
            pf.space_after = Pt(1)
            tabs = OxmlElement("w:tabs")
            tab = OxmlElement("w:tab")
            tab.set(qn("w:val"), "right")
            tab.set(qn("w:leader"), "dot")
            tab.set(qn("w:pos"), "10080")  # 7.0in, the right margin
            tabs.append(tab)
            p._p.get_or_add_pPr().append(tabs)

            link = OxmlElement("w:hyperlink")
            link.set(qn("w:anchor"), name)
            r = OxmlElement("w:r")
            rpr = OxmlElement("w:rPr")
            if level == 1:
                b = OxmlElement("w:b")
                rpr.append(b)
            col = OxmlElement("w:color")
            col.set(qn("w:val"), "4C1D95" if level == 1 else "374151")
            rpr.append(col)
            sz = OxmlElement("w:sz")
            sz.set(qn("w:val"), "20" if level == 1 else "18")
            rpr.append(sz)
            r.append(rpr)
            t = OxmlElement("w:t")
            t.set(qn("xml:space"), "preserve")
            t.text = text
            r.append(t)
            link.append(r)
            p._p.append(link)

            tr = OxmlElement("w:r")
            tt = OxmlElement("w:tab")
            tr.append(tt)
            p._p.append(tr)
            _field(p._p, f" PAGEREF {name} \\h ", "\u2013")

        new_para().add_run().add_break(WD_BREAK.PAGE)

        # Move the built block from the end of the document up to the anchor.
        node = anchor._p if hasattr(anchor, "_p") else anchor
        for p in built:
            node.addnext(p._p)
            node = p._p
        return built

    # ------------------------------------------------------------- text -----
    def para(self, text="", bold=False, italic=False, colour=None, size=None):
        p = self.doc.add_paragraph()
        r = p.add_run(text)
        r.bold = bold
        r.italic = italic
        if colour is not None:
            r.font.color.rgb = colour
        if size:
            r.font.size = Pt(size)
        return p

    def rich(self, *parts):
        """rich(("lead", {"bold": True}), ("body", {})) -> one mixed paragraph."""
        p = self.doc.add_paragraph()
        for text, fmt in parts:
            r = p.add_run(text)
            r.bold = fmt.get("bold", False)
            r.italic = fmt.get("italic", False)
            if fmt.get("mono"):
                r.font.name = "Consolas"
                r.font.size = Pt(9)
            if fmt.get("colour") is not None:
                r.font.color.rgb = fmt["colour"]
        return p

    def lead(self, lead_text, body, colour=None):
        return self.rich((lead_text, {"bold": True, "colour": colour}), (body, {}))

    def bullets(self, items: Iterable[str], numbered=False):
        for it in items:
            self.doc.add_paragraph(it, style="List Number" if numbered else "List Bullet")

    def note(self, text, label="Note", colour=RED):
        p = self.doc.add_paragraph()
        p.paragraph_format.left_indent = Inches(0.12)
        p.paragraph_format.space_before = Pt(6)
        r = p.add_run(f"{label}: ")
        r.bold = True
        r.font.color.rgb = colour
        r.font.size = Pt(9.5)
        r2 = p.add_run(text)
        r2.italic = True
        r2.font.size = Pt(9.5)
        return p

    def code(self, text):
        for line in text.split("\n"):
            p = self.doc.add_paragraph()
            p.paragraph_format.space_after = Pt(0)
            p.paragraph_format.space_before = Pt(0)
            p.paragraph_format.left_indent = Inches(0.12)
            r = p.add_run(line if line else " ")
            r.font.name = "Consolas"
            r.font.size = Pt(8.5)
        self.doc.add_paragraph().paragraph_format.space_after = Pt(2)

    # ------------------------------------------------------------ tables ----
    def table(self, headers: Sequence[str], rows, widths=None, mono_cols=(), font=8.5,
              bands: dict | None = None):
        t = self.doc.add_table(rows=1, cols=len(headers))
        t.style = "Table Grid"
        t.alignment = WD_TABLE_ALIGNMENT.CENTER
        t.autofit = False
        for i, htext in enumerate(headers):
            c = t.rows[0].cells[i]
            c.text = ""
            r = c.paragraphs[0].add_run(htext)
            r.bold = True
            r.font.size = Pt(font)
            r.font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)
            c.paragraphs[0].alignment = WD_ALIGN_PARAGRAPH.CENTER
            shade(c, "4C1D95")
        for idx, row in enumerate(rows):
            if bands and idx in bands:
                cells = t.add_row().cells
                for j, c in enumerate(cells):
                    c.text = ""
                    rr = c.paragraphs[0].add_run(bands[idx] if j == 0 else "")
                    rr.bold = True
                    rr.font.size = Pt(font)
                    shade(c, "EDE9FE")
            cells = t.add_row().cells
            for i, val in enumerate(row):
                cells[i].text = ""
                p = cells[i].paragraphs[0]
                p.paragraph_format.space_after = Pt(1)
                r = p.add_run("" if val is None else str(val))
                r.font.size = Pt(font)
                if i in mono_cols:
                    r.font.name = "Consolas"
                    r.font.size = Pt(font - 0.5)
        if widths:
            for row in t.rows:
                for i, w in enumerate(widths):
                    row.cells[i].width = Inches(w)
        self.doc.add_paragraph().paragraph_format.space_after = Pt(2)
        return t

    def callout(self, title, body, colour=PURPLE, fill="F5F3FF"):
        t = self.doc.add_table(rows=1, cols=1)
        t.style = "Table Grid"
        cell = t.rows[0].cells[0]
        cell.text = ""
        r = cell.paragraphs[0].add_run(title)
        r.bold = True
        r.font.size = Pt(9.5)
        r.font.color.rgb = colour
        r2 = cell.add_paragraph().add_run(body)
        r2.font.size = Pt(9)
        shade(cell, fill)
        cell.width = Inches(7.1)
        self.doc.add_paragraph().paragraph_format.space_after = Pt(2)
        return t

    # ------------------------------------------------------------- misc -----
    def page_break(self):
        self.doc.add_page_break()

    def trailer(self, version, dated):
        p = self.doc.add_paragraph()
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        r = p.add_run(f"End of document  \u00b7  {version}  \u00b7  {dated}")
        r.italic = True
        r.font.size = Pt(8.5)
        r.font.color.rgb = GREY

    def save(self, path):
        self.doc.save(path)


def build(title: str, subtitle: str = "", strapline: str = "", version: str = "v0.1",
          dated: str = "", org_line: str | None = None) -> SpecDoc:
    """org_line is the client and programme name printed above the title.

    Set it per call, or once for the whole project via the SPECKIT_ORG_LINE
    environment variable, so a document does not have to be edited to be reused
    on the next engagement.
    """
    if org_line is None:
        org_line = os.environ.get("SPECKIT_ORG_LINE", "<Client> — Salesforce Programme")
    dated = dated or datetime.date.today().strftime("%d-%b-%Y")
    doc = Document()

    base = doc.styles["Normal"]
    base.font.name = "Calibri"
    base.font.size = Pt(10)
    base.paragraph_format.space_after = Pt(6)

    for name, size, colour in (("Heading 1", 15, PURPLE), ("Heading 2", 12, PURPLE),
                               ("Heading 3", 10.5, GREY)):
        st = doc.styles[name]
        st.font.name = "Calibri"
        st.font.size = Pt(size)
        st.font.bold = True
        st.font.color.rgb = colour
        st.paragraph_format.space_before = Pt(14 if name == "Heading 1" else 10)
        st.paragraph_format.space_after = Pt(5)

    sec = doc.sections[0]
    sec.orientation = WD_ORIENT.PORTRAIT
    sec.left_margin = sec.right_margin = Inches(0.7)
    sec.top_margin = sec.bottom_margin = Inches(0.7)

    # Tells Word to recalculate fields when the file is opened, which is what
    # puts real page numbers into the contents page without anyone pressing F9.
    upd = OxmlElement("w:updateFields")
    upd.set(qn("w:val"), "true")
    doc.settings.element.append(upd)

    # Page numbers in the footer, so the numbers on the contents page can be
    # acted on. Without these a contents page is decorative.
    fp = sec.footer.paragraphs[0]
    fp.alignment = WD_ALIGN_PARAGRAPH.CENTER
    fr = fp.add_run(f"{title}  \u00b7  {version}  \u00b7  Page ")
    fr.font.size = Pt(8)
    fr.font.color.rgb = GREY
    _field(fp._p, " PAGE ", "1")
    fr2 = fp.add_run(" of ")
    fr2.font.size = Pt(8)
    fr2.font.color.rgb = GREY
    _field(fp._p, " NUMPAGES ", "1")
    for r in fp.runs:
        r.font.size = Pt(8)
        r.font.color.rgb = GREY

    def centred(text, size, colour=None, bold=False, italic=False):
        p = doc.add_paragraph()
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        r = p.add_run(text)
        r.bold = bold
        r.italic = italic
        r.font.size = Pt(size)
        if colour is not None:
            r.font.color.rgb = colour
        return p

    centred(org_line, 11, GREY, bold=True)
    centred(title, 20, PURPLE, bold=True)
    centred(subtitle, 11, GREY)
    last = centred(strapline, 9, italic=True)

    d = SpecDoc(doc)
    d.title_block_end = last
    return d
