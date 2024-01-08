import os
import yaml
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak

from reportlab.lib.pagesizes import A4
import datetime

from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle

yml_data_obj_dir = 'data/objects/'  # where the data obj definitions are

if not os.path.exists('docs'): # pdf report output location
    os.makedirs('docs') # create it if doesnt exist. 


def create_pdf_from_yaml(directory):
    # Create a simple doc template with left margin, right margin, top margin, bottom margin set
    doc = SimpleDocTemplate("docs/object_definitions.pdf", pagesize=A4,
                                rightMargin=72, leftMargin=72,
                                topMargin=72, bottomMargin=18)
    
    # Container for the 'Flowable' objects
    story = [Spacer(1, 2 * 72)]
    styles = getSampleStyleSheet()

    # Define a custom style for center-aligned text
    centre_style = ParagraphStyle('Center', parent=styles['Normal'])
    centre_style.alignment = 1  # 0=left, 1=centre, 2=right
    
    # Title Page
    title = "<br/><br/><br/><br/><br/><br/><br/><br/><h1>Standard Safeguarding Dataset</h1><br/><h2>YAML Object Specification</h2>"
    last_updated_date = datetime.datetime.now().strftime('%d-%m-%Y %H:%M')
    last_updated_text = f"Last updated/Ver: {last_updated_date}"  # Add prefix "Last updated: " to the date

    story.append(Paragraph(title, styles['Title']))
    story.append(Paragraph(last_updated_text, centre_style))  # Use the custom 'Centre' style here
    story.append(PageBreak())

    # Create a list to hold table of contents entries
    contents = []
    
    # Loop over each yaml file in the directory
    for filename in os.listdir(directory):
        if filename.endswith(".yaml") or filename.endswith(".yml"):
            with open(os.path.join(directory, filename), 'r') as stream:
                try:
                    data = yaml.safe_load(stream)
                    nodes = data.get('nodes', [])
                    for node in nodes:
                        contents.append(node['name'])
                except yaml.YAMLError as exc:
                    print(exc)

    # Table of Contents Page
    story.append(Paragraph("<h1>Table of Contents</h1>", styles['Title']))
    for content in contents:
        story.append(Paragraph(content, styles['BodyText']))
    story.append(PageBreak())
    
    # Loop over each yaml file in the directory again to generate content
    for filename in os.listdir(directory):
        if filename.endswith(".yaml") or filename.endswith(".yml"):
            with open(os.path.join(directory, filename), 'r') as stream:
                try:
                    data = yaml.safe_load(stream)
                    nodes = data.get('nodes', [])
                    for node in nodes:
                        story.append(Paragraph(f"<h1>Object: {node['name']}</h1>", styles['Heading1']))
                        for field in node['fields']:
                            story.append(Paragraph(f"<h2>Data Item: {field['name']}</h2>", styles['Heading2']))
                            for key, value in field.items():
                                if key != 'name':
                                    story.append(Paragraph(f"<b>{key}:</b> {str(value)}", styles['BodyText']))
                        story.append(PageBreak())
                except yaml.YAMLError as exc:
                    print(exc)

    # Build the pdf
    doc.build(story)


create_pdf_from_yaml(yml_data_obj_dir)
