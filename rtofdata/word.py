from pathlib import Path

from docx import Document
from docx.shared import Cm, Inches
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH
from openpyxl.utils.cell import cols_from_range
from rtofdata.create_validation_rules import generate_validation_rules



def write_word_specification(data: dict, filename: str):
    """
    Creates a detailed Word version of the specification.
    Read more about docx here: https://python-docx.readthedocs.io/en/latest/
    """
        
    document = Document()
    document.add_heading('RTOF Data Specification', 0)
    for table_def in data['Intro_table']:
        introduction = table_def.get('Introduction')
        document.add_paragraph(introduction)

    picture = Path(__file__).parent / '../data/RTOF_program_path.png'
    document.add_picture(str(picture.absolute()), width = Cm(18.0))
    last_paragraph = document.paragraphs[-1] 
    last_paragraph.alignment = WD_ALIGN_PARAGRAPH.CENTER
    
    document.add_page_break()

    document.add_heading('Forms', 1)
    document.add_paragraph(
        'Each from corresponds to a stage '
        'in the service.'
    )
    for count, table_def in enumerate(data['Tables']):
        table_name = table_def.get('Table')
        if not table_name:
            continue
        document.add_heading(f"Form {count+1}: {table_name.title()}", 2)
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
        col0.width = Cm(5.79)        
        col1.width = Cm(1.0)
        col2.width = Cm(1.0)
        col3.width = Cm(6.0)
        
        hdr_cells = table.rows[0].cells
        hdr_cells[0].text = 'ID'
        hdr_cells[1].text = 'Name'
        hdr_cells[2].text = 'Type'
        hdr_cells[3].text = 'Description'

        table_fields = [f for f in data['Fields']
                        if f.get('Table') == table_name]
        document.add_page_break()
        for f in table_fields:
            row_cells = table.add_row().cells
            row_cells[0].text = f.get('ID', "")
            row_cells[1].text = f.get('Name', "")
            row_cells[2].text = f.get('Type', "")
            row_cells[3].text = f.get('Description', "")
        
    
    document.add_heading('Annex 1: Categorical data options')
   
    table = document.add_table(rows=1, cols=4)
    table.style = 'Light Grid Accent 5'
    table_fields = [f for f in data['Fields']
                    if f.get('Type') == 'Categorical']
    colx = table.columns[0]
    col1 = table.columns[1]
    col2 = table.columns[2]
    col3 = table.columns[3]
    colx.width = Cm(5)        
    col1.width = Cm(2.9)
    col2.width = Cm(3.29)
    col3.width = Cm(8.0)

    heading_cells = table.rows[0].cells
    heading_cells[0].text = 'ID'
    heading_cells[1].text = 'Name'
    heading_cells[2].text = 'Categories'
    heading_cells[3].text = 'Category descriptions' 

    for f in table_fields:
        row_cells = table.add_row().cells
        row_cells[0].text = f.get('ID', "")
        row_cells[1].text = f.get('Name', "")  
        id = f['ID']
        values = data['Categories'][id]
        row_cells[2].text = ";\n".join(values)
        descriptions = data['Categories'][f"{id}_description"]
        row_cells[3].text = ";\n".join(descriptions)

    document.add_page_break()
    document.add_heading('Annex 1: RTOF Data Validation rules', 0)
    
    for k, v in data['rules'].items():
        document.add_heading(k, 1)
        for t, c in v.items():
            document.add_paragraph(f"{t} : {c}")
        

    document.save(filename)
