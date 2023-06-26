import os
from PIL import Image
from IPython.display import display

def create_entity_webpage():
    image_folder = 'docs/publish/web/'
    output_folder = 'docs/publish/web/'
    os.makedirs(output_folder, exist_ok=True)
    image_files = os.listdir(image_folder)
    image_files.sort()

    webpage_file = os.path.join(output_folder, 'index.html')
    with open(webpage_file, 'w') as f:
        f.write('<html>\n<head>\n<style>\n.row { display: flex; }\n.column { flex: 33.33%; padding: 5px; }\n</style>\n</head>\n<body>\n')

        for i, image_file in enumerate(image_files):
            image_path = os.path.join(image_folder, image_file)
            resized_image = Image.open(image_path)
            resized_image.thumbnail((400, 300))

            if i % 3 == 0:
                if i > 0:
                    f.write('</div>\n')
                f.write('<div class="row">\n')

            f.write(f'<div class="column">\n')
            f.write(f'<img src="{image_path}" alt="{image_file}" style="width:100%">\n')
            f.write('</div>\n')

        f.write('</div>\n</body>\n</html>\n')

    display(webpage_file)

create_entity_webpage()

