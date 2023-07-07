import glob
import os
import datetime
from admin.admin_tools import get_paths  # get project defined file paths

paths = get_paths()

# Initialize html_content as an empty string
html_content = ""

# main overview image settings
main_image_width = "85%"

# Define page title and intro text
page_title_str = "Project 1a - Standard Safeguarding Dataset"
page_intro_str = ""

notes_str1 = "Right click and open image(s) in a new browser tab to zoom/magnify/scroll."
repo_link_back_str = "https://github.com/data-to-insight/ssd-data-model/blob/main/README.md"

# Other sub-links
index_link_back_str = "https://data-to-insight.github.io/ssd-data-model/index.html"
guidance_link_back_str = "https://data-to-insight.github.io/ssd-data-model/guidance.html"
returns_maps_link_back_str = "https://data-to-insight.github.io/ssd-data-model/existingreturnsmap.html"

# Initialize html_content as an empty string
html_content = ""
# Embed colour_dict as a JSON object for JavaScript to use
# html_content += f"<script>\nvar colour_dict = {json.dumps(colour_dict)};\n</script>"

html_content = "<html><head><style>"
html_content += "body { margin: 20px; }"
html_content += ".last-updated-container { display: flex; align-items: center; }"
html_content += ".last-updated-text { font-weight: bold; margin-right: 5px; }"
html_content += ".repo-link { text-decoration: none; }"
html_content += "</style></head><body>"

html_content += f"<h1>{page_title_str}</h1>"
html_content += f"<p>{page_intro_str}</p>"
html_content += "<div style='padding: 2px;'>"

# Last updated and link section
html_content += "<div class='last-updated-container'>"
html_content += f"<span class='last-updated-text'>Last updated:</span>"
html_content += f"<span class='last-updated-date'>{datetime.datetime.now().strftime('%d-%m-%Y %H:%M')}</span>"
html_content += f"<a href='{repo_link_back_str}' class='repo-link'> &nbsp;|&nbsp; SSD Github</a>"
html_content += f"<a href='{index_link_back_str}' class='repo-link'> &nbsp;|&nbsp; Object Concept Model</a>"
html_content += f"<a href='{guidance_link_back_str}' class='repo-link'> &nbsp;|&nbsp; Data Item Guidance</a>"
html_content += f"<a href='{returns_maps_link_back_str}' class='repo-link'> &nbsp;|&nbsp; Existing returns maps</a>"
html_content += "</div>"

html_content += "<h1>DfE Data Returns:</h1>"
html_content += f"<p>{notes_str1}</p>"

# Get the list of image files in the folder
image_files = glob.glob(paths['returns_maps'] + "*.jpg") # location of source files


# Check if any image files are found
if len(image_files) > 0:
    # Loop over the image files and add them to the HTML content
    for image_file in image_files:
  
        # Extract the image filename
        image_filename = os.path.basename(image_file)

        web_img_path = paths['wsite_returns_maps'] + image_filename # relative img path to generated html page

        # Add the image to the HTML content
        html_content += f'<img src="{web_img_path}" alt="{image_filename}" style="max-width: 100%; margin-bottom: 20px;">'
else:
    # No image files found
    print(f"In location {paths['returns_maps']}, No images found...")
    html_content += "<p>No images found.</p>"


html_content += "</div>"
html_content += "</div>"
html_content += "</body></html>"

with open(paths['wsite_root'] + 'existingreturnsmap.html', 'w') as f:
    f.write(html_content)
