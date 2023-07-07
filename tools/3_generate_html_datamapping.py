import glob
import os
import datetime
from admin.admin_tools import get_paths  # get project defined file paths


paths = get_paths()

# Define the path to the images folder
images_folder = "assets/ReturnsMapping/"

# Initialize html_content as an empty string
html_content = ""

# main overview image settings
overview_erd_filename = "ssd_erd_diagram.png"
main_image_width = "85%"  
image_width = "300px"

# Define page title and intro text
page_title_str = "Project 1a"
page_intro_str = "Standard Safeguarding Dataset"


notes_str1 = "Right click and open image(s) in a new browser tab to zoom/magnify/scroll."
repo_link_back_str = "https://github.com/data-to-insight/ssd-data-model/blob/main/README.md"


# Initialize html_content as an empty string
html_content = ""
# Embed colour_dict as a JSON object for JavaScript to use
# html_content += f"<script>\nvar colour_dict = {json.dumps(colour_dict)};\n</script>"

html_content = "<html><head><style>"
html_content += "body { margin: 20px; }"
html_content += "table { border-collapse: collapse; width: 100%; margin: auto; table-layout: fixed; }"  
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

html_content += f"<h1>{page_title_str}</h1>"
html_content += f"<p>{page_intro_str}</p>"
html_content += "<div style='padding: 2px;'>"

html_content += "<div class='last-updated-container'>"
html_content += f"<span class='last-updated-text'>Last updated:</span>"
html_content += f"<span class='last-updated-date'>{datetime.datetime.now().strftime('%d-%m-%Y %H:%M')}</span>"
html_content += f"<a href='{repo_link_back_str}' class='repo-link'> &nbsp;|&nbsp; SSD Github</a>"
html_content += "</div>"

html_content += "<h1>DfE Data Returns Map:</h1>"
html_content += f"<p>{notes_str1}</p>"

html_content += "</div>"



# Get the list of image files in the folder
image_files = glob.glob(images_folder + "*.jpg")

# Loop over the image files and add them to the HTML content
for image_file in image_files:
    # Extract the image filename
    image_filename = os.path.basename(image_file)

    # Add the image to the HTML content
    html_content += f'<img src="{image_file}" alt="{image_filename}" style="max-width: 100%; margin-bottom: 20px;">'

html_content += "</div>"
html_content += "</div>"
html_content += "</body></html>"


with open(paths['wsite_root'] + 'existingreturnsmap.html', 'w') as f:
    f.write(html_content)