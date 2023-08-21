import markdown
import os

def md_to_html(md_file_path, output_html_path):
    extensions = ['fenced_code']
    
    # Convert Markdown to HTML
    with open(md_file_path, 'r') as md_file:
        md_content = md_file.read()
        html_content = markdown.markdown(md_content, extensions=extensions)

    # Manually adjust table rendering
    lines = html_content.split("\n")
    fixed_lines = []

    in_table = False
    for line in lines:
        # Detect start of the table
        if "<p>|" in line:
            in_table = True
            fixed_lines.append("<table><tbody>")
        
        # If we are inside a table
        if in_table:
            if "| --- |" in line:  # Skip separator line
                continue
            else:
                row_data = line.replace("<p>", "").replace("</p>", "").strip().split("|")
                row_data = [cell.strip() for cell in row_data if cell.strip()]
                if not row_data:
                    continue
                fixed_lines.append("<tr><td>" + "</td><td>".join(row_data) + "</td></tr>")
            
            # Detect end of the table
            if "|</p>" in line:
                fixed_lines.append("</tbody></table>")
                in_table = False
                continue
        
        # If we are not inside a table
        if not in_table:
            fixed_lines.append(line)




    fixed_html_content = "\n".join(fixed_lines)

    # Add table and code block styling
    styled_html_content = """
    <html>
    <head>
        <style>
            table {
                border-collapse: collapse;
                width: 100%;
            }
            th, td {
                border: 1px solid black;
                padding: 8px;
                text-align: left;
            }
            th {
                background-color: #f2f2f2;
            }
            pre {
                background-color: #f5f5f5;
                padding: 10px;
                border-radius: 3px;
                overflow-x: auto;
            }
            code {
                font-family: monospace;
            }
        </style>
    </head>
    <body>
    """
    styled_html_content += fixed_html_content
    styled_html_content += """
    </body>
    </html>
    """

    with open(output_html_path, 'w') as html_file:
        html_file.write(styled_html_content)

# Usage:
md_to_html('./README.md', './docs/README.html')
