import glob
import os
import datetime
from admin.admin_tools import get_paths  # get project defined file paths




# Define page title and intro text
page_title_str = "Standard Safeguarding Dataset: Existing DfE Returns Map"
page_intro_str = ""


notes_str1 = "This page shows subset views of the SSD data map towards core DfE returns, and below this the initial data mapping undertaken by the Standard Safeguarding Dataset project to understand the existing children's safeguarding data landscape."
# repo_link_str = "https://github.com/data-to-insight/ssd-data-model/blob/main/README.md"   # For when Repo is PUBLIC
repo_link_str = "https://data-to-insight.github.io/ssd-data-model/README.html"              # For when repo is PRIVATE

# Used with the seperator between diagrams/planning images
sub_notes_str1 = "Initial data mapping undertaken by the Standard Safeguarding Dataset. </Br>Please note that image quality will vary due to limitations on source files and page generator workflow."

# Other sub-links
index_link_str = "https://data-to-insight.github.io/ssd-data-model/index.html"
guidance_link_str = "https://data-to-insight.github.io/ssd-data-model/guidance.html"
returns_maps_link_str = "https://data-to-insight.github.io/ssd-data-model/existingreturnsmap.html"
change_request_link_str = "https://forms.office.com/e/UysrcGApJ1"
object_specification_link_str = "https://data-to-insight.github.io/ssd-data-model/object_definitions.pdf"
object_ddl_tables_link_str = "https://dbdiagram.io/d/SSD-Schema-V1-65cf6008ac844320ae4e8484"  # if publishing DDL diagram via dbdiagram

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
html_content += "h1, h2 { border-bottom: none; }"

html_content += "</style></head><body>"

html_content += f"<h1>{page_title_str}</h1>"
html_content += f"<p>{page_intro_str}</p>"
html_content += "<div style='padding: 2px;'>"

# Last updated and link section
html_content += "<div class='last-updated-container'>"
html_content += f"<span class='last-updated-text'>Last updated:</span>"
html_content += f"<span class='last-updated-date'>{datetime.datetime.now().strftime('%d-%m-%Y %H:%M')}</span>"
html_content += "<div class='link-section'>"
html_content += f"<a href='{repo_link_str}' class='repo-link'> | Get Started & Project description</a>"
html_content += f"<a href='{index_link_str}' class='repo-link'> | Object Concept Model</a>"
html_content += f"<a href='{guidance_link_str}' class='repo-link'> | Data Item Guidance</a>"
html_content += f"<a href='{returns_maps_link_str}' class='repo-link'> | Existing returns maps</a>"
html_content += f"<a href='{change_request_link_str}' class='repo-link'> | Submit Change Request</a>"
html_content += f"<a href='{object_specification_link_str}' class='repo-link'> | Object Spec download(PDF)</a>"
html_content += f"<a href='{object_ddl_tables_link_str}' class='repo-link'> | Object ER diagram</a>" # if publishing ER diagram via dbdiagram

html_content += "</div>"

html_content += "</div>"

html_content += "<h1>SSD data map subsets:</h1>"
html_content += f"<p>{notes_str1}</p>"


# Get the list of image files in the folder
image_files = glob.glob(paths['returns_maps'] + "*.jpg")  # location of source files

# Check if any image files are found
if len(image_files) > 0:
    # Loop over the image files and add them to the HTML content

    diagram_files = [file for file in image_files if 'diagram' in os.path.basename(file).lower()]
    non_diagram_files = [file for file in image_files if file not in diagram_files]

    # Loop over the diagram files and add them to the HTML content
    for image_file in diagram_files:

        # Extract the image filename
        image_filename = os.path.basename(image_file)

        web_img_path = paths['wsite_returns_maps'] + image_filename  # relative img path to generated HTML page

        # Format the diagram sub-headers
        image_filename = os.path.splitext(image_filename)[0]    # Remove '.jpg' extension
        image_filename = image_filename.replace("ssd_", "")     # Remove 'ssd_' from the filename 
        parts = image_filename.split("_")                       # Split the filename by underscore
        image_filename = parts[0].upper()                       # Capitalise the first part
        html_content += f"<h2>{image_filename}</h2>"

        # Add the image/diagram to the HTML content
        html_content += f'<div class="image-container"><img src="{web_img_path}" alt="{image_filename}" style="max-width: 100%; margin-bottom: 20px;"></div>'

    # Add a visual separator
    html_content += "</Br></Br><h1>Current DfE Data Returns Map:</h1>"
    html_content += f"<p>{sub_notes_str1}</p></Br>"



    # Add key/legend
    html_content += "<h2>Key/Legend:</h2>"
    html_content += "<div class='key-container'>"

    # Define color and text for each key item
    key_items = [
        {"color": "#F5F6F8", "text": "Identity"},
        {"color": "#F2C4DA", "text": "S47 and IPCP"},
        {"color": "#6CD9FA", "text": "Contact"},
        {"color": "#93D375", "text": "Early Help"},
        {"color": "#D6F693", "text": "Early Help (Pilot)"},
        {"color": "#F5D027", "text": "Social Care Referral"},
        {"color": "#FF9D48", "text": "Child in Need"},
        {"color": "#EA94BB", "text": "CP Plan"},
        {"color": "#C6A2D2", "text": "Looked After & Leavers"},
        {"color": "#FFF9B1", "text": "Permanence"},
        {"color": "#ACB5FF", "text": "Education"},
        {"color": "#F2A1AA", "text": "Workforce | Other"}
    ]

    # Loop over key items and add color cells/borderless boxes
    for item in key_items:
        color = item["color"]
        text = item["text"]
        html_content += f"<div class='key-item' style='background-color: {color};'>{text}</div>"
    html_content += "</div>" # key end




    # Loop over the non-diagram files and add them to the HTML content
    for image_file in non_diagram_files:

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

# push out the compiled html content/formating to file
with open(paths['wsite_root'] + 'existingreturnsmap.html', 'w') as f:
    f.write(html_content)
