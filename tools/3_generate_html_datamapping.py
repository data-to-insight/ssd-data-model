import glob
import os
import datetime
from admin.admin_tools import get_paths  # get project defined file paths




# Define page title and intro text
page_title_str = "Standard Safeguarding Dataset: Existing Returns Map"
page_intro_str = ""


notes_str1 = "This page shows the initial data mapping undertaken by the Standard Safeguarding Dataset project to understand the existing children's safeguarding data landscape. Right click and open image(s) in a new browser tab to zoom/magnify/scroll."
repo_link_str = "https://github.com/data-to-insight/ssd-data-model/blob/main/README.md"


# Other sub-links
index_link_str = "https://data-to-insight.github.io/ssd-data-model/index.html"
guidance_link_str = "https://data-to-insight.github.io/ssd-data-model/guidance.html"
returns_maps_link_str = "https://data-to-insight.github.io/ssd-data-model/existingreturnsmap.html"
change_request_link_str = "https://forms.office.com/e/UysrcGApJ1"


#### end of settings




paths = get_paths()

# Initialize html_content as an empty string
html_content = ""

html_content = "<html><head><style>"
html_content += "body { margin: 20px; }"
html_content += ".last-updated-container { display: flex; align-items: center; }"
html_content += ".last-updated-text { font-weight: bold; margin-right: 5px; }"
html_content += ".repo-link { text-decoration: none; }"
html_content += ".link-section a { margin-left: 10px; margin-right: 10px; }"
html_content += ".image-container { display: block; width: 85%; margin: 0 auto; }"  # Set the container width to 85% of the page width
html_content += ".image-container img { width: 100%; }"  # Stretch the images to fill the container width
html_content += ".key-container { display: flex; }"
html_content += ".key-item { flex-grow: 1; text-align: center; padding: 10px; border: none; }"

html_content += "</style></head><body>"

html_content += f"<h1>{page_title_str}</h1>"
html_content += f"<p>{page_intro_str}</p>"
html_content += "<div style='padding: 2px;'>"

# Last updated and link section
html_content += "<div class='last-updated-container'>"
html_content += f"<span class='last-updated-text'>Last updated:</span>"
html_content += f"<span class='last-updated-date'>{datetime.datetime.now().strftime('%d-%m-%Y %H:%M')}</span>"
html_content += "<div class='link-section'>"
html_content += f"<a href='{repo_link_str}' class='repo-link'> | SSD Github</a>"
html_content += f"<a href='{index_link_str}' class='repo-link'> | Object Concept Model</a>"
html_content += f"<a href='{guidance_link_str}' class='repo-link'> | Data Item Guidance</a>"
html_content += f"<a href='{returns_maps_link_str}' class='repo-link'> | Existing returns maps</a>"
html_content += f"<a href='{change_request_link_str}' class='repo-link'> | Submit Change Request</a>"
html_content += "</div>"

html_content += "</div>"

html_content += "<h1>DfE Data Returns:</h1>"
html_content += f"<p>{notes_str1}</p>"

# Add key/legend
html_content += "<h2>Key/Legend:</h2>"
html_content += "<div class='key-container'>"

# Define color and text for each key item
key_items = [
    {"color": "#F5F6F8", "text": "Identity"},
    {"color": "#F2C4DA", "text": "S47 and IPCP"},
    {"color": "#6CD9FA", "text": "Contact"},
    {"color": "#93D375", "text": "Early Help"},
    {"color": "#D6F693", "text": "Early Help (Plot)"},
    {"color": "#F5D027", "text": "Social Care Referral"},
    {"color": "#FF9D48", "text": "Child in Need"},
    {"color": "#EA94BB", "text": "CP Plan"},
    {"color": "#C6A2D2", "text": "Looked After & Leavers"},
    {"color": "#FFF9B1", "text": "Permanence"},
    {"color": "#ACB5FF", "text": "Education"},
    {"color": "#F2A1AA", "text": "Workforce|Other"}
]

# Loop over key items and add color cells/borderless boxes
for item in key_items:
    color = item["color"]
    text = item["text"]
    html_content += f"<div class='key-item' style='background-color: {color};'>{text}</div>"

html_content += "</div>" # key end


# Get the list of image files in the folder
image_files = glob.glob(paths['returns_maps'] + "*.jpg")  # location of source files

# Check if any image files are found
if len(image_files) > 0:
    # Loop over the image files and add them to the HTML content
    for image_file in image_files:
        # Extract the image filename
        image_filename = os.path.basename(image_file)

        web_img_path = paths['wsite_returns_maps'] + image_filename  # relative img path to generated HTML page

        image_filename = os.path.splitext(image_filename)[0]  # Remove '.jpg' extension

        html_content += f"<h2>{image_filename}</h2>"
        # Add the image to the HTML content
        html_content += f'<div class="image-container"><img src="{web_img_path}" alt="{image_filename}" style="max-width: 100%; margin-bottom: 20px;"></div>'
else:
    # No image files found
    print(f"In location {paths['returns_maps']}, No images found...")
    html_content += "<p>No images found.</p>"


html_content += "</div>"
html_content += "</div>"
html_content += "</body></html>"

with open(paths['wsite_root'] + 'existingreturnsmap.html', 'w') as f:
    f.write(html_content)
