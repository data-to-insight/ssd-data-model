import glob
from PIL import Image
import os

def get_paths():
    """
    Return a dictionary of paths used in the application.
    """
    paths = {
        'assets': 'assets/',
        'docs': 'docs/',
        'tools': 'tools/',
        'erd_publish': 'docs/imgs/',
        'erd_objects_publish': 'docs/imgs/erd_data_objects/',
        'yml_data': 'data/objects/',  # yml imports
        'wsite_root':'docs/',
        'data_specification': 'docs/admin/data_objects_specification.csv'  
    }
    return paths


def resize_images(folder_path, target_width, quality=90):
    for file_path in glob.glob(os.path.join(folder_path, '*.png')):
        img = Image.open(file_path)
        current_width, current_height = img.size
        target_height = int((current_height / current_width) * target_width)
        resized_img = img.resize((target_width, target_height), resample=Image.LANCZOS)
        resized_img.save(file_path, format='PNG', optimize=True, quality=quality)

