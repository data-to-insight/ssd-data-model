import os
import shutil
import yaml


# takes a .yml file as a template(000_la_config_template.yml), removes all comments (#) and duplicates it, 
# each time renaming a new copy of the revised template file to all the numbers in the la dict {id:la_name, ...} 
# and adding each la id to replace <id_num> and the la name as <la_name>
# To be used when re-generating revised yml config structure for each LA. 

# Note: 
# Running this will OVERWRITE everything in 'ssd-data-model/la_config_files__future_release/awaitingConfig/'
# Only blank/un-configured yml files should be stored in awaitingConfig/

# opt1 - map la codes to la name (from provider lookup 290924)
la_name_dict = {
    921: ["Isle-of-Wight", "SE", "Paris (MOSAIC)", "Oracle"],
    208: ["Lambeth", "GL", "MOSAIC", "Oracle"],
    887: ["Medway", "SE", "MOSAIC", "Oracle"],
    330: ["Birmingham", "WM", "Eclipse", "Postgress"],
    846: ["Brighton-and-Hove", "SE", "Eclipse", "Postgress"],
    878: ["Devon", "SW", "Eclipse", "Postgress"],
    876: ["Halton", "NW", "Eclipse", "Postgress"],
    391: ["Newcastle-upon-Tyne", "NE", "Eclipse", "Postgress"],
    879: ["Plymouth", "SW", "Eclipse", "Postgress"],
    336: ["Wolverhampton", "WM", "Eclipse", "Postgress"],
    890: ["Blackpool", "NW", "MOSAIC", "SQLServer"],
    204: ["Hackney", "GL", "MOSAIC", "SQLServer"],
    815: ["North-Yorkshire", "YH", "SystemC", "SQLServer"],
    931: ["Oxfordshire", "SE", "SystemC", "SQLServer"],
    870: ["Reading", "SE", "MOSAIC", "SQLServer"],
    320: ["Waltham-Forest", "GL", "MOSAIC", "SQLServer"],
    816: ["York", "YH", "MOSAIC", "SQLServer"],
    301: ["Barking-and-Dagenham", "GL", "SystemC", "SQLServer[D]"],
    800: ["Bath-and-North-East-Somerset", "SW", "SystemC", "SQLServer[D]"],
    822: ["Bedford-Borough", "E", "SystemC", "SQLServer[D]"],
    303: ["Bexley", "GL", "SystemC", "SQLServer[D]"],
    889: ["Blackburn-with-Darwen", "NW", "SystemC", "SQLServer[D]"],
    350: ["Bolton", "NW", "SystemC", "SQLServer[D]"],
    380: ["Bradford", "YH", "SystemC", "SQLServer[D]"],
    801: ["Bristol", "SW", "SystemC", "SQLServer[D]"],
    305: ["Bromley", "GL", "SystemC", "SQLServer[D]"],
    825: ["Buckinghamshire", "SE", "SystemC", "SQLServer[D]"],
    351: ["Bury", "NW", "SystemC", "SQLServer[D]"],
    873: ["Cambridgeshire", "E", "SystemC", "SQLServer[D]"],
    895: ["Cheshire-East", "NW", "SystemC", "SQLServer[D]"],
    896: ["Cheshire-West-and-Chester", "NW", "SystemC", "SQLServer[D]"],
    331: ["Coventry", "WM", "SystemC", "SQLServer[D]"],
    306: ["Croydon", "GL", "SystemC", "SQLServer[D]"],
    942: ["Cumberland", "NW", "SystemC", "SQLServer[D]"],
    841: ["Darlington", "NE", "SystemC", "SQLServer[D]"],
    831: ["Derby", "EM", "SystemC", "SQLServer[D]"],
    332: ["Dudley", "WM", "SystemC", "SQLServer[D]"],
    840: ["Durham", "NE", "SystemC", "SQLServer[D]"],
    845: ["East-Sussex", "SE", "SystemC", "SQLServer[D]"],
    308: ["Enfield", "GL", "SystemC", "SQLServer[D]"],
    916: ["Gloucestershire", "SW", "SystemC", "SQLServer[D]"],
    805: ["Hartlepool", "NE", "SystemC", "SQLServer[D]"],
    311: ["Havering", "GL", "SystemC", "SQLServer[D]"],
    919: ["Hertfordshire", "E", "SystemC", "SQLServer[D]"],
    312: ["Hillingdon", "GL", "SystemC", "SQLServer[D]"],
    313: ["Hounslow", "GL", "SystemC", "SQLServer[D]"],
    206: ["Islington", "GL", "SystemC", "SQLServer[D]"],
    886: ["Kent", "SE", "SystemC", "SQLServer[D]"],
    810: ["Kingston-upon-Hull", "YH", "SystemC", "SQLServer[D]"],
    314: ["Kingston-upon-Thames", "GL", "SystemC", "SQLServer[D]"],
    382: ["Kirklees", "YH", "SystemC", "SQLServer[D]"],
    888: ["Lancashire", "NW", "SystemC", "SQLServer[D]"],
    856: ["Leicester", "EM", "SystemC", "SQLServer[D]"],
    209: ["Lewisham", "GL", "SystemC", "SQLServer[D]"],
    341: ["Liverpool", "NW", "SystemC", "SQLServer[D]"],
    821: ["Luton", "E", "SystemC", "SQLServer[D]"],
    352: ["Manchester", "NW", "SystemC", "SQLServer[D]"],
    806: ["Middlesbrough", "NE", "SystemC", "SQLServer[D]"],
    826: ["Milton-Keynes", "SE", "SystemC", "SQLServer[D]"],
    926: ["Norfolk", "E", "SystemC", "SQLServer[D]"],
    812: ["North-East-Lincolnshire", "YH", "SystemC", "SQLServer[D]"],
    802: ["North-Somerset", "SW", "SystemC", "SQLServer[D]"],
    392: ["North-Tyneside", "NE", "SystemC", "SQLServer[D]"],
    929: ["Northumberland", "NE", "SystemC", "SQLServer[D]"],
    892: ["Nottingham", "EM", "SystemC", "SQLServer[D]"],
    874: ["Peterborough", "E", "SystemC", "SQLServer[D]"],
    807: ["Redcar-and-Cleveland", "NE", "SystemC", "SQLServer[D]"],
    354: ["Rochdale", "NW", "SystemC", "SQLServer[D]"],
    372: ["Rotherham", "YH", "SystemC", "SQLServer[D]"],
    857: ["Rutland", "EM", "SystemC", "SQLServer[D]"],
    355: ["Salford", "NW", "SystemC", "SQLServer[D]"],
    333: ["Sandwell", "WM", "SystemC", "SQLServer[D]"],
    343: ["Sefton", "NW", "SystemC", "SQLServer[D]"],
    373: ["Sheffield", "YH", "SystemC", "SQLServer[D]"],
    893: ["Shropshire", "WM", "SystemC", "SQLServer[D]"],
    871: ["Slough", "SE", "SystemC", "SQLServer[D]"],
    334: ["Solihull", "WM", "SystemC", "SQLServer[D]"],
    933: ["Somerset", "SW", "SystemC", "SQLServer[D]"],
    393: ["South-Tyneside", "NE", "SystemC", "SQLServer[D]"],
    882: ["Southend-on-Sea", "E", "SystemC", "SQLServer[D]"],
    342: ["St-Helens", "NW", "SystemC", "SQLServer[D]"],
    356: ["Stockport", "NW", "SystemC", "SQLServer[D]"],
    808: ["Stockton-on-Tees", "NE", "SystemC", "SQLServer[D]"],
    861: ["Stoke-on-Trent", "WM", "SystemC", "SQLServer[D]"],
    935: ["Suffolk", "E", "SystemC", "SQLServer[D]"],
    394: ["Sunderland", "NE", "SystemC", "SQLServer[D]"],
    936: ["Surrey", "SE", "SystemC", "SQLServer[D]"],
    357: ["Tameside", "NW", "SystemC", "SQLServer[D]"],
    894: ["Telford-and-Wrekin", "WM", "SystemC", "SQLServer[D]"],
    883: ["Thurrock", "E", "SystemC", "SQLServer[D]"],
    880: ["Torbay", "SW", "SystemC", "SQLServer[D]"],
    358: ["Trafford", "NW", "SystemC", "SQLServer[D]"],
    384: ["Wakefield", "YH", "SystemC", "SQLServer[D]"],
    943: ["Westmorland-and-Furness", "NW", "SystemC", "SQLServer[D]"],
    359: ["Wigan", "NW", "SystemC", "SQLServer[D]"],
    865: ["Wiltshire", "SW", "SystemC", "SQLServer[D]"],
    344: ["Wirral", "NW", "SystemC", "SQLServer[D]"],
    885: ["Worcestershire", "WM", "SystemC", "SQLServer[D]"],
    340: ["Knowsley", "NW", "SystemC", "SQLServer<2014"],
    881: ["Essex", "E", "MOSAIC", "SQLServer>2014"],
    302: ["Barnet", "GL", "MOSAIC", "Unknown"],
    370: ["Barnsley", "YH", "MOSAIC", "Unknown"],
    839: ["Bournemouth,-Christchurch-and-Poole", "SW", "MOSAIC", "Unknown"],
    867: ["Bracknell-Forest", "SE", "MOSAIC", "Unknown"],
    304: ["Brent", "GL", "MOSAIC", "Unknown"],
    381: ["Calderdale", "YH", "BespokeInHouse", "Unknown"],
    202: ["Camden", "GL", "MOSAIC", "Unknown"],
    823: ["Central-Bedfordshire", "E", "MOSAIC", "Unknown"],
    201: ["City-of-London", "GL", "MOSAIC", "Unknown"],
    908: ["Cornwall-Council", "SW", "MOSAIC", "Unknown"],
    909: ["Cumbria", "NotKnown", "Unknown", "Unknown"],
    830: ["Derbyshire", "EM", "MOSAIC", "Unknown"],
    371: ["Doncaster", "YH", "MOSAIC", "Unknown"],
    838: ["Dorset", "SW", "MOSAIC", "Unknown"],
    307: ["Ealing", "GL", "MOSAIC", "Unknown"],
    811: ["East-Riding-of-Yorkshire", "YH", "Azeus", "Unknown"],
    390: ["Gateshead", "NE", "MOSAIC", "Unknown"],
    203: ["Greenwich", "GL", "MOSAIC", "Unknown"],
    205: ["Hammersmith-and-Fulham", "GL", "MOSAIC", "Unknown"],
    850: ["Hampshire", "SE", "MOSAIC", "Unknown"],
    309: ["Haringey", "GL", "MOSAIC", "Unknown"],
    310: ["Harrow", "GL", "MOSAIC", "Unknown"],
    884: ["Herefordshire", "WM", "MOSAIC", "Unknown"],
    420: ["Isles-of-Scilly", "SW", "Azeus-(MOSAIC)", "Unknown"],
    207: ["Kensington-and-Chelsea", "GL", "MOSAIC", "Unknown"],
    383: ["Leeds", "YH", "MOSAIC", "Unknown"],
    855: ["Leicestershire", "EM", "MOSAIC", "Unknown"],
    925: ["Lincolnshire", "EM", "MOSAIC", "Unknown"],
    315: ["Merton", "GL", "MOSAIC", "Unknown"],
    316: ["Newham", "GL", "Azeus", "Unknown"],
    813: ["North-Lincolnshire", "YH", "Care-First", "Unknown"],
    940: ["North-Northamptonshire", "EM", "Care-First", "Unknown"],
    928: ["Northamptonshire", "EM", "Other", "Unknown"],
    891: ["Nottinghamshire", "EM", "MOSAIC", "Unknown"],
    353: ["Oldham", "NW", "MOSAIC", "Unknown"],
    836: ["Poole", "SW", "Unknown", "Unknown"],
    851: ["Portsmouth", "SE", "MOSAIC", "Unknown"],
    317: ["Redbridge", "GL", "Unknown", "Unknown"],
    318: ["Richmond-upon-Thames", "GL", "MOSAIC", "Unknown"],
    803: ["South-Gloucestershire", "SW", "MOSAIC", "Unknown"],
    852: ["Southampton", "SE", "Care-Director", "Unknown"],
    210: ["Southwark", "GL", "MOSAIC", "Unknown"],
    860: ["Staffordshire", "WM", "Care-Director", "Unknown"],
    319: ["Sutton", "GL", "MOSAIC", "Unknown"],
    866: ["Swindon", "SW", "Care-Director", "Unknown"],
    211: ["Tower-Hamlets", "GL", "MOSAIC", "Unknown"],
    335: ["Walsall", "WM", "MOSAIC", "Unknown"],
    212: ["Wandsworth", "GL", "MOSAIC", "Unknown"],
    877: ["Warrington", "NW", "MOSAIC", "Unknown"],
    937: ["Warwickshire", "WM", "MOSAIC", "Unknown"],
    869: ["West-Berkshire", "SE", "Care-Director", "Unknown"],
    941: ["West-Northamptonshire", "EM", "Care-First", "Unknown"],
    938: ["West-Sussex", "SE", "MOSAIC", "Unknown"],
    213: ["Westminster", "GL", "MOSAIC", "Unknown"],
    868: ["Windsor-and-Maidenhead", "SE", "PARIS", "Unknown"],
    872: ["Wokingham", "SE", "MOSAIC", "Unknown"]
}

# LAs who have already deployed or have ongoing config file
# inclusion in this array stops new config file being generated/previous overwritten. 
already_deployed_dict = {
    332: "East-Sussex", 350: "Bradford"
    # ... add other LAs as deployed
}

# filter out LAs already deployed
def filter_deployed_ids(id_name_dict, already_deployed_dict):
    return {id_num: la_data for id_num, la_data in id_name_dict.items() if id_num not in already_deployed_dict}

def duplicate_and_modify_template(template_path, output_directory, la_name_dict):
    # Apply the filter to exclude already deployed LAs
    la_name_dict = filter_deployed_ids(la_name_dict, already_deployed_dict)

    with open(template_path, 'r') as file:
        content = file.readlines()
    
    # Create output dir if it doesn't exist
    os.makedirs(output_directory, exist_ok=True)
    

    cleaned_content = []
    for line in content:
        # Remove anything after a comment # (including in-line comments)
        cleaned_line = line.split('#')[0].rstrip()  # Split at '#', keep the first part (code), and remove trailing spaces
        if cleaned_line:  # Keep only non-empty lines
            cleaned_content.append(cleaned_line)

    # Convert cleaned content to a single string for easier manipulation
    cleaned_content_str = '\n'.join(cleaned_content)

    # Iterate over the filtered dictionary and create modified copies
    for la_code, la_data in la_name_dict.items():
        la_name, _, cms, cms_db = la_data  # Extract la_name, cms, and cms_db
        new_file_name = f"{la_code}_{la_name.replace(' ', '_').lower()}.yml"
        new_file_path = os.path.join(output_directory, new_file_name)

        # Replace placeholders in the content
        modified_content = (cleaned_content_str
                            .replace('<la_id>', str(la_code))
                            .replace('<la_name>', la_name)
                            .replace('cms: <null>', f'cms: {cms}' if cms else 'cms: null')
                            .replace('cms_db: <null>', f'cms_db: {cms_db}' if cms_db else 'cms_db: null'))

        # Replace all other <null> placeholders with YAML null
        modified_content = modified_content.replace('<null>', 'null')
        
        # Write the modified content to a new file
        with open(new_file_path, 'w') as new_file:
            new_file.write(modified_content)
        
        print(f"Created: {new_file_path}")






yml_template_path = '/workspaces/ssd-data-model/la_config_files__future_release/awaitingConfig/000_la_config_template.yml'
output_directory = '/workspaces/ssd-data-model/la_config_files__future_release/awaitingConfig/'

duplicate_and_modify_template(yml_template_path, output_directory, la_name_dict)
