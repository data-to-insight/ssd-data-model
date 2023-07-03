
# here is the python code complete




import glob
import yaml
import base64
import subprocess
import datetime
from PIL import Image
import os
import json

from admin.admin_tools import get_paths  # get project defined file paths
from admin.admin_tools import resize_images

paths = get_paths()
erd_objects_path = paths['wsite_sub_images']
erd_overview_path = paths['wsite_main_images']
yml_import_path = paths['yml_data']

overview_erd_filename = "ssd_erd_sfdp.png"

# Color dictionary
color_dict = {
    "categories": {
        "Local": "#C5E625",             # New data items but existing
        "1a": "#1CFCF2",                # Suggested 
        "1bDraft" : "#F57C1D",           # ??
        "1bSpecified": "#FFC91E"         # ?? 
    }
}


# Initialize html_content as an empty string
html_content = ""
# Embed color_dict as a JSON object for JavaScript to use
html_content += f"<script>\nvar color_dict = {json.dumps(color_dict)};\n</script>"


# Calculate main image width
main_image_width = "85%"  # Adjust the padding as needed

# Sub-Image width (adjust as needed)
image_width = "300px"

# Define page title and intro text
page_title_str = "SSD Data Model Documentation"
page_intro_str = "Project 1a. Standard Safeguarding Dataset. Data objects/item definitions published towards iterative review."

notes_str = "Right click and open the image in a new browser tab to zoom/magnify/scroll object level detail. Data item/field reference numbers [AAA000A] enable specific referencing."
repo_link_back_str = "https://github.com/data-to-insight/ssd-data-model/blob/main/README.md"


html_content = "<html><head><style>"
html_content += "body { margin: 20px; }"
html_content += "table { border-collapse: collapse; width: 100%; margin: auto; table-layout: fixed; }"  # Set width to 100% and table-layout to fixed
html_content += "th, td { text-align: left; padding: 8px; word-wrap: break-word; border: 1px solid #ddd; }"
html_content += "th { background-color: #f2f2f2; }"
html_content += "th.image-column { width: " + str(image_width) + "; }"
html_content += "th.field-ref-column { width: 100px; }"
html_content += "th.data-item-column { width: 30%; }"
html_content += "th.field-column { width: 20%; }"
html_content += "th.cms-column { width: 15%; }"
html_content += "th.categories-column { width: 15%; }"
html_content += "th.returns-column { width: 20%; }"
html_content += ".last-updated-container { display: flex; align-items: center; }"
html_content += ".last-updated-text { font-weight: bold; margin-right: 5px; }"
html_content += ".repo-link { text-decoration: none; }"
html_content += "</style></head><body>"
html_content += f"<script>\nvar color_dict = {color_dict};\n</script>"
html_content += f"<h1>{page_title_str}</h1>"
html_content += f"<p>{page_intro_str}</p>"
html_content += "<div style='padding: 2px;'>"

# Last updated and link section
html_content += "<div class='last-updated-container'>"
html_content += f"<span class='last-updated-text'>Last updated:</span>"
html_content += f"<span class='last-updated-date'>{datetime.datetime.now().strftime('%d-%m-%Y %H:%M')}</span>"
html_content += f"<a href='{repo_link_back_str}' class='repo-link'> | SSD Github</a>"
html_content += "</div>"

# Object Overview section
html_content += "<h1>Objects Overview:</h1>"
html_content += f"<p>{notes_str}</p>"
html_content += "<div id='table-container'>"  # Add id attribute to the table container
html_content += f'<img id="main-image" src="{erd_overview_path}{overview_erd_filename}" alt="Data Objects Overview" style="max-width: 100%; margin-bottom: 20px;">'  # Set max-width to 100% and remove margin-right
html_content += "</div>"
html_content += "</div>"

# Object Data Points Overview section
html_content += "<h1>Object Data Points Overview:</h1>"

# Read the YAML files
for file_path in glob.glob(f'{yml_import_path}*.yml'):
    with open(file_path) as f:
        data = yaml.safe_load(f)
        nodes = data.get('nodes', [])
        if nodes:
            entity_name = nodes[0]['name']
            html_content += "<div>"
            html_content += f"<h2 style='text-align: left; margin-top: 20px;'>Object name: {entity_name}</h2>"
            html_content += "<div style='display: flex; align-items: flex-start;'>"
            html_content += f'<img src="{erd_objects_path}{entity_name}.png" alt="{entity_name}" style="width: {image_width}; margin-right: 20px;">'
            html_content += "<div style='padding-bottom: 50px;'>"
            html_content += "<table style='border-collapse: collapse; border: none;'>"
            html_content += "<colgroup>"
            html_content += "<col style='width: 10%;'/>"  # Set width for field-ref-column
            html_content += "<col style='width: 30%;'/>"  # Set width for data-item-column
            html_content += "<col style='width: 20%;'/>"  # Set width for field-column
            html_content += "<col style='width: 10%;'/>"  # Set width for cms-column
            html_content += "<col style='width: 15%;'/>"  # Set width for categories-column
            html_content += "<col style='width: 15%;'/>"  # Set width for returns-column
            html_content += "</colgroup>"
            html_content += "<tr><th class='item-ref-column'>Item Ref</th><th class='data-item-column'>Data Item Name</th><th class='field-column'>Field</th><th class='cms-column'>Exists in CMS</th><th class='categories-column'>Data Category Group(s)</th><th class='returns-column'>Returns</th></tr>"

            # For each row in the table:
            for field in nodes[0]['fields']:
                field_ref = field.get('item_ref', '')
                field_name = field['name']
                cms_data = ', '.join(field.get('cms', []))
                categories_data = ', '.join(field.get('categories', []))
                returns_data = ', '.join(field.get('returns', []))

                # Add a class to each row, using a unique identifier (like the field reference)
                html_content += f'<tr class="row-{field_ref}">'
                html_content += f"<td>{field_ref}</td><td>{field_name}</td><td>{field_name}</td><td>{cms_data}</td><td>{categories_data}</td><td>{returns_data}</td></tr>"

            html_content += "</table>"
            html_content += "</div>"
            html_content += "</div>"
            html_content += "</div>"
            html_content += "<hr style='border: none; border-top: 1px solid #ddd; margin-bottom: 20px;'>"

html_content += """
<script>
window.addEventListener('load', function() {
  // Function to check if a row matches a category and color it
  function colorRow(row, returns) {
    // Check if any of the return elements matches a category
    for (var i = 0; i < returns.length; i++) {
      if (color_dict["categories"][returns[i].trim()]) { // .trim() is used to remove potential leading/trailing whitespaces
        // If it matches, color the row and stop checking
        row.style.backgroundColor = color_dict["categories"][returns[i].trim()];
        return;
      }
    }
  }

  // Go through all rows
  var rows = document.getElementsByTagName("tr");

  for (var i = 0; i < rows.length; i++) {
    // Get the returns column and split it by ", "
    var returns = rows[i].children[5].innerText.split(", ").map(item => item.trim());

    console.log("Returns:", returns);  // to check actual content in returns
    console.log("Color dict categories:", color_dict["categories"]);  // to check your color dict

    // Apply the colorRow function
    colorRow(rows[i], returns);
  }
});
</script>
"""


html_content += "</body></html>"  # Move this to the end of your Python script


with open(paths['wsite_root'] + 'index.html', 'w') as f:
    f.write(html_content)

# 
# # Run script to re-create the individual object diagram images
# subprocess.run(['python3', paths['tools'] + 'create_erd_imgs.py'])


# Resize & optimise image files for web publishing.
# Other/above methods only reduce to width/size of longest text data on row(s)
resize_images(paths['erd_objects_publish'], target_width=300, quality=80)  # each entity object
resize_images(paths['wsite_root'], target_width=5000, quality=100)  # overview erd image
