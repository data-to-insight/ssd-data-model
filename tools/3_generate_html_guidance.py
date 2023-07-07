

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
from admin.admin_tools import returns_categories

paths = get_paths()
erd_objects_path = paths['wsite_sub_images']
erd_overview_path = paths['wsite_main_images']
yml_import_path = paths['yml_data']



# Initialize html_content as an empty string
html_content = ""
# Embed colour_dict as a JSON object for JavaScript to use
# html_content += f"<script>\nvar colour_dict = {json.dumps(colour_dict)};\n</script>"

# main overview image settings
# 
#  output name
overview_erd_filename = "ssd_erd_diagram.png"
main_image_width = "85%"  # Calculate main image width # Adjust the padding as needed
image_width = "300px" # Sub-Image width (adjust as needed)


# Define page title and intro text
page_title_str = "Project 1a - Standard Safeguarding Dataset"
page_intro_str = ""


notes_str1 = "Right click and open the image in a new browser tab to zoom/magnify/scroll object level detail. Data item id numbers [AAA000A] enable specific item/field referencing."
notes_str2 = "Data objects/item definitions published towards iterative review. Diagrams consisdered as conceptual interpretations, not a true relational/representational model"
repo_link_back_str = "https://github.com/data-to-insight/ssd-data-model/blob/main/README.md"

# Other sub-links
index_link_back_str = "https://data-to-insight.github.io/ssd-data-model/index.html"
guidance_link_back_str = "https://data-to-insight.github.io/ssd-data-model/guidance.html"
returns_maps_link_back_str = "https://data-to-insight.github.io/ssd-data-model/existingreturnsmap.html"


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

# Embed returns_categories as a JSON object for JavaScript to use
html_content += f"<script>\nvar returns_categories = {json.dumps(returns_categories)};\n</script>"

html_content += f"<h1>{page_title_str}</h1>"
html_content += f"<p>{page_intro_str}</p>"
html_content += "<div style='padding: 2px;'>"

# Last updated and link section
html_content += "<div class='last-updated-container'>"
html_content += f"<span class='last-updated-text'>Last updated:</span>"
html_content += f"<span class='last-updated-date'>{datetime.datetime.now().strftime('%d-%m-%Y %H:%M')}</span>"
html_content += f"<a href='{repo_link_back_str}' class='repo-link'> &nbsp;|&nbsp; SSD Github</a>"
html_content += f"<a href='{index_link_back_str}' class='repo-link'> &nbsp;|&nbsp; Index</a>"
html_content += f"<a href='{guidance_link_back_str}' class='repo-link'> &nbsp;|&nbsp; Data Item Guidance</a>"
html_content += f"<a href='{returns_maps_link_back_str }' class='repo-link'> &nbsp;|&nbsp; Existing returns maps</a>"
html_content += "</div>"
# Object *Overview* section / main image
html_content += "<h1>Objects Overview <span style='color: orange;'>(Incl. Guidance Notes)</span>:</h1>"
html_content += f"<p>{notes_str1}</p>"
html_content += f"<p>{notes_str2}</p>"
html_content += "<div id='table-container'>"  # Add id attribute to the table container


# Add in main overview image
html_content += f'<img id="main-image" src="{erd_overview_path}{overview_erd_filename}" alt="Data Objects Overview" style="max-width: 100%; margin-bottom: 20px;">'  # Set max-width to 100% and remove margin-right

# Add a legend
html_content += "<div id='legend-container' style='margin-top: 20px;'>"

html_content += "<h3>Object/Data item key:</h3>"  # Legend heading
html_content += "<ul id='legend' style='background: rgba(255, 255, 255, 0.7); padding: 10px; border-radius: 5px; list-style: none; margin-top: 2px;'>"
for category, details in returns_categories.items():
    html_content += f"<li style='margin-bottom: 5px; font-size: 12px;'><div style='display: inline-block; width: 20px; height: 20px; margin-right: 5px; background: {details['colour']};'></div>{category} - {details['description']}</li>"
html_content += "</ul>"
html_content += "<p>Note: Colour identifiers on Overview image indicate presence of <i>at least</i> one known change. See below tables for the item level changes/additions with granular colour-coding.</p>"

html_content += "</div>"


html_content += "</div>"
html_content += "</div>"

# Object *Data Points* section
html_content += "<h1>Object Data Points Overview<span style='color: orange;'>(Incl. Guidance Notes)</span>:</h1>"

# Read the YAML files to get the object data
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
            html_content += "<col style='width: 12%;'/>"  # Set width for field-ref-column
            html_content += "<col style='width: 25%;'/>"  # Set width for data-item-column
            html_content += "<col style='width: 55%;'/>"  # Set width for guidance-column
            html_content += "<col style='width: 8%;'/>"  # Set width for returns-column
            html_content += "</colgroup>"
            html_content += "<tr><th class='item-ref-column'>Item Ref</th><th class='data-item-column'>Data Item Name</th><th class='field-column'>Guidance</th><th class='returns-column'>Returns</th></tr>"

            # For each row in the table:
            for field in nodes[0]['fields']:

                field_ref = field.get('item_ref', '')
                field_name = field['name']

                # Handle blank, single '0', and string '0' values in the guidance column
                # Temporary cleaning until import data is improved
                field_guidance = field['guidance'] or ""
                if field_guidance.strip() == '0':
                    field_guidance = ""

                field_guidance = field['guidance'] # This the additional field on this html output / long text field

                # cms_data = ', '.join(field.get('cms', []))
                # categories_data = ', '.join(field.get('categories', []))

                returns_data = ', '.join(field.get('returns', []))

                # Add a class to each row, using a unique identifier (like the field reference)
                html_content += f'<tr class="row-{field_ref}">'
                html_content += f"<td>{field_ref}</td><td>{field_name}</td><td>{field_guidance}</td><td>{returns_data}</td></tr>"

            html_content += "</table>"
            html_content += "</div>"
            html_content += "</div>"
            html_content += "</div>"
            html_content += "<hr style='border: none; border-top: 1px solid #ddd; margin-bottom: 20px;'>"



"""
JS is added to the HTML content. Colours rows in output table based on the contents of the 'returns' column.
- 'colourRow' func: checks if any element in the 'returns' list of a row matches a category in 'colour_dict'. 
- If it finds a match, it colours the row with the corresponding colour and stops the check.
- Main script: goes through all rows in the table. For each row, extracts the 'returns' column content, splits it into a list, and applies the 'colourRow' func
- triggered on the 'load' event of the window, ensuring it runs after the HTML content is fully loaded.
"""

html_content += """
<script>
window.addEventListener('load', function() {
  // Function to check if a row matches a category and colour it
  function colourRow(row, returns) {
    // Check if any of the return elements matches a category
    for (var i = 0; i < returns.length; i++) {
      if (returns_categories[returns[i].trim()]) { // .trim() is used to remove potential leading/trailing whitespaces
        // If it matches, colour the row and stop checking
        row.style.backgroundColor = returns_categories[returns[i].trim()]["colour"];
        return;
      }
    }
  }

  // Go through all rows
  var rows = document.getElementsByTagName("tr");

  for (var i = 0; i < rows.length; i++) {
    // Get the returns column and split it by ", "
    var returns = rows[i].children[3].innerText.split(", ").map(item => item.trim()); // Update the column index to 3

    // Apply the colourRow function
    colourRow(rows[i], returns);
  }
});
</script>
"""




html_content += "</body></html>"  # HTML end


with open(paths['wsite_root'] + 'guidance.html', 'w') as f:
    f.write(html_content)


# 
# # Run script to re-create the individual object diagram images
# subprocess.run(['python3', paths['tools'] + 'create_erd_imgs.py'])



# Resize & optimise image files for web publishing.
# Other/above methods only reduce to width/size of longest text data on row(s)
resize_images(paths['erd_objects_publish'], target_width=300, quality=80)  # each entity object
resize_images(paths['wsite_root'], target_width=5000, quality=100)  # overview erd image
