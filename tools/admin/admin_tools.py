import glob
from PIL import Image
import os
import re

returns_categories = {
    "Existing": {
        "colour": "#CCCCCC",
        "description": "Current returned data",
    },
    "Local": {
        "colour": "#C5E625",
        "description": "Recorded locally but not currently included in any data collections",
    },
    "1aDraft": {
        "colour": "#1CFCF2",
        "description": "Suggested new item for SSD",
    },
    "1bDraft": {
        "colour": "#F57C1D",
        "description": "Suggested new item for one of the 1b projects",
    },
    "1bSpecified": {
        "colour": "#FFC91E",
        "description": "Final specified item for one of the 1b projects",
    },
    "1aRemove": {
        "colour": "#FF2114",
        "description": "Specified item rejected from final spec.",
    },
}



def get_paths():
    """
    Return a dictionary of paths used in the application.
    """
    paths = {
        'assets': 'assets/',
        'docs': 'docs/',
        'tools': 'tools/',
        'erd_publish': 'docs/imgs/',
        'erd_returns_publish': 'doc/img/erd_returns_maps',
        'erd_objects_publish': 'docs/imgs/erd_data_objects/',
        'yml_data': 'data/objects/',  # yml imports
        'wsite_root':'docs/',
        'wsite_main_images': 'imgs/',
        'wsite_sub_images': 'imgs/erd_data_objects/',
        'returns_maps': 'docs/imgs/returns_maps/',
        'wsite_returns_maps': 'imgs/returns_maps/',
        'data_specification': 'docs/admin/data_objects_specification.csv',
        'change_log': 'docs/admin/ssd_change_log.csv'  
    }
    return paths


def resize_images(folder_path, target_width, quality=90):
    for file_path in glob.glob(os.path.join(folder_path, '*.png')):
        img = Image.open(file_path)
        current_width, current_height = img.size
        target_height = int((current_height / current_width) * target_width)
        resized_img = img.resize((target_width, target_height), resample=Image.LANCZOS)
        resized_img.save(file_path, format='PNG', optimize=True, quality=quality)



def clean_fieldname_data(value, is_name=False):
    """
    Cleans the given value.
    Processes include removing special characters ('/ \'), replacing spaces with underscores.

    Args:
        value (str): Input string to be cleaned.
        is_name (bool): Whether the input value is a name. If True, additional processing is done.

    Returns:
        str: The cleaned string.
    """

    # Replace double spaces with single spaces
    value = re.sub(r'\s{2,}', ' ', value)

    # Remove leading and trailing spaces
    value = value.strip()

    # # Replace many middle spaces with underscore
    # value = re.sub(r'\s+', '_', value)

    # Check for values '0', 'null', None, and empty strings
    if value in ['0', 'null', None, '', 0]:
        return None
    
    if is_name:
        value = value.lower()  # Force name element to lowercase

    return value

