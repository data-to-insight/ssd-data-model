import glob
import yaml
import base64
import subprocess
import datetime
from PIL import Image
import os

from admin.admin_tools import get_paths # get project defined file paths
from admin.admin_tools import resize_images



paths = get_paths()
erd_objects_path = paths['erd_objects_publish']
erd_overview_path = paths['erd_publish']
yml_import_path = paths['yml_data']

overview_erd_filename = "ssd_erd.png"



# Calculate main image width
main_image_width = "calc(100% - 40px)"  # Adjust the padding as needed

# Sub-Image width (adjust as needed)
image_width = "300px"

# Define page title and intro text
page_title_str = "SSD Data Model Documentation"
page_intro_str = "Data Item and Entity Definitions published for iterative review. Objects/data fields capturing LA Childrens Services data towards 1a SSD."

repo_link_back_str = "https://github.com/data-to-insight/ssd-data-model/blob/main/README.md"


# Generate HTML content
html_content = "<html><head><style>"
html_content += "table { border-collapse: collapse; width: 80%; margin: auto; }"
html_content += "th, td { text-align: left; padding: 8px; word-wrap: break-word; border: 1px solid #ddd; }"
html_content += "th { background-color: #f2f2f2; }"
html_content += "th.image-column { width: " + str(image_width) + "; }"
html_content += "th.field-ref-column { width: 100px; }"
html_content += "th.data-item-column { width: 30%; }"
html_content += "th.field-column { width: 20%; }"
html_content += "th.cms-column { width: 15%; }"
html_content += "th.categories-column { width: 15%; }"
html_content += "th.returns-column { width: 20%; }"
html_content += ".img-zoom-lens { position: absolute; border: 1px solid #d4d4d4; width: 40px; height: 40px; }"  # Added CSS rule
html_content += "</style></head><body>"
html_content += f"<h1>{page_title_str}</h1>"
html_content += f"<p>{page_intro_str}</p>"
html_content += f"<h3>Last updated: {datetime.datetime.now().strftime('%d-%m-%Y')}</h3>"


# Add Objects Overview section
html_content += "<h2>Objects Overview:</h2>"
html_content += "<div style='padding: 20px;'>"
html_content += "<div class='img-zoom-container'>"
html_content += f'<img id="main-image" src=f"{erd_overview_path}{overview_erd_filename}" alt="Data Objects Overview" style="width: {main_image_width};">'
html_content += "<div id='zoom-result' class='img-zoom-result'></div>"
html_content += "</div>"
html_content += "</div>"

# Add Object Data Points Overview section
html_content += "<h2>Object Data Points Overview:</h2>"


# Read the YAML files
for file_path in glob.glob(f'{yml_import_path}*.yml'):
    with open(file_path) as f:
        data = yaml.safe_load(f)
        nodes = data.get('nodes', [])
        if nodes:
            entity_name = nodes[0]['name']
            html_content += "<div>"
            html_content += f"<h2>Object name: {entity_name}</h2>"
            html_content += "<div style='text-align: center;'>"

            html_content += f'<img src="{erd_objects_path}{entity_name}.png" alt="{entity_name}" style="width: {image_width}; margin-right: 20px;">'
            html_content += "<table>"
            html_content += "<tr><th class='field-ref-column'>Field Ref</th><th class='data-item-column'>Data Item Name / Field</th><th class='field-column'>Field</th><th class='cms-column'>Exists in CMS</th><th class='categories-column'>Data Category Group(s)</th><th class='returns-column'>Returns</th></tr>"
            for field in nodes[0]['fields']:
                field_ref = field.get('field_ref', '')
                field_name = field['name']
                cms_data = ', '.join(field.get('cms', []))
                categories_data = ', '.join(field.get('categories', []))
                returns_data = ', '.join(field.get('returns', []))
                html_content += f"<tr><td>{field_ref}</td><td>{field_name}</td><td>{field_name}</td><td>{cms_data}</td><td>{categories_data}</td><td>{returns_data}</td></tr>"
            html_content += "</table>"
            html_content += "</div>"
            html_content += "</div>"

# Add image zoom JavaScript
html_content += "<script>"
html_content += "function imageZoom(imgID, resultID) {"
html_content += "var img, lens, result, cx, cy;"
html_content += "img = document.getElementById(imgID);"
html_content += "result = document.getElementById(resultID);"
html_content += "lens = document.createElement('DIV');"
html_content += "lens.setAttribute('class', 'img-zoom-lens');"
html_content += "img.parentElement.insertBefore(lens, img);"
html_content += "cx = result.offsetWidth / lens.offsetWidth;"
html_content += "cy = result.offsetHeight / lens.offsetHeight;"
html_content += "result.style.backgroundImage = 'url(' + img.src + ')';"
html_content += "result.style.backgroundSize = (img.width * cx) + 'px ' + (img.height * cy) + 'px';"
html_content += "lens.addEventListener('mousemove', moveLens);"
html_content += "img.addEventListener('mousemove', moveLens);"
html_content += "lens.addEventListener('touchmove', moveLens);"
html_content += "img.addEventListener('touchmove', moveLens);"
html_content += "function moveLens(e) {"
html_content += "var pos, x, y;"
html_content += "e.preventDefault();"
html_content += "pos = getCursorPos(e);"
html_content += "x = pos.x - (lens.offsetWidth / 2);"
html_content += "y = pos.y - (lens.offsetHeight / 2);"
html_content += "if (x > img.width - lens.offsetWidth) {x = img.width - lens.offsetWidth;}"
html_content += "if (x < 0) {x = 0;}"
html_content += "if (y > img.height - lens.offsetHeight) {y = img.height - lens.offsetHeight;}"
html_content += "if (y < 0) {y = 0;}"
html_content += "lens.style.left = x + 'px';"
html_content += "lens.style.top = y + 'px';"
html_content += "result.style.backgroundPosition = '-' + (x * cx) + 'px -' + (y * cy) + 'px';"
html_content += "}"
html_content += "function getCursorPos(e) {"
html_content += "var a, x = 0, y = 0;"
html_content += "e = e || window.event;"
html_content += "a = img.getBoundingClientRect();"
html_content += "x = e.pageX - a.left;"
html_content += "y = e.pageY - a.top;"
html_content += "x = x - window.pageXOffset;"
html_content += "y = y - window.pageYOffset;"
html_content += "return {x : x, y : y};"
html_content += "}"
html_content += "}"

# Call imageZoom function for main image
html_content += "imageZoom('main-image', 'zoom-result');"
html_content += "</script>"

# Close HTML tags
html_content += "</body></html>"


# Write HTML content to file
with open(paths['wsite_root'] +'index.html', 'w') as f:
    f.write(html_content)

# # Run create_erd.py script to re-create the individual object diagram images
# subprocess.run(['python3', paths['tools'] + 'create_erd_imgs.py'])

# Resize & optimise images for web publishing.
# Other/above methods only reduce to width/size of longest text data on row(s)
resize_images(paths['erd_objects_publish'], target_width=300, quality=80)         # each entity object
# resize_images(paths['wsite_root'], target_width=3000, quality=100)    # overview erd image


