from docx import Document
from docx.shared import Cm, Inches
from docx.enum.table import WD_TABLE_ALIGNMENT




def write_word_specification(data: dict, filename: str):
    """
    Creates a detailed Word version of the specification.
    Read more about docx here: https://python-docx.readthedocs.io/en/latest/
    """
    document = Document()
    document.add_heading('RTOF Data Specification', 0)
    introduction = "The document outlines the data fields, types and descriptions for all required data collection during the lifetime of the Refugee Tranisition Outcome Fund"
    document.add_paragraph(introduction)
    document.add_page_break()

    document.add_heading('Tables', 1)
    document.add_paragraph(
        'Each table (does table make sense - '
        'maybe "form" would be clearer?) corresponds to a stage '
        'in the service.'
    )
    for table_def in data['Tables']:
        table_name = table_def.get('Table')
        document.add_heading(table_name.title(), 2)
        document.add_paragraph(table_def.get('Description', ""))
        
        table = document.add_table(rows=1, cols=4)
        table.style = 'Light Grid Accent 5'
        table.allow_autofit = False
        table.autofit = False
        table.alignment = WD_TABLE_ALIGNMENT.CENTER

        col0 = table.columns[0]
        col1 = table.columns[1]
        col2 = table.columns[2]
        col3 = table.columns[3]
        col0.width = Cm(5.19)        
        col1.width = Cm(2.5)
        col2.width = Cm(2.5)
        col3.width = Cm(6.0)
        
        hdr_cells = table.rows[0].cells
        hdr_cells[0].text = 'ID'
        hdr_cells[1].text = 'Name'
        hdr_cells[2].text = 'Type'
        hdr_cells[3].text = 'Description'

        table_fields = [f for f in data['Fields']
                        if f.get('Table') == table_name]
        for f in table_fields:
            row_cells = table.add_row().cells
            row_cells[0].text = f.get('ID', "")
            row_cells[1].text = f.get('Name', "")
            row_cells[2].text = f.get('Type', "")
            row_cells[3].text = f.get('Description', "")
        

    document.save(filename)
