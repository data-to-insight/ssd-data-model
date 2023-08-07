import yaml

def transform_yaml():
    # Load the YAML file
    with open('la_config/la_cms_config_v1.yml', 'r') as file:
        data = yaml.safe_load(file)

    # Transform the structure
    transformed_data = {'la_configs': []}
    for key, value in data.items():
        # Ensure keys order by creating new dictionary
        ordered_dict = {'la_code': key, 'la_name': value['la_name'], 'cms': value['cms'], 
                        'cms_db': value['cms_db'], 'db_vers': value['db_vers']}
        
        transformed_data['la_configs'].append(ordered_dict)


    # Write the new structure to the same YAML file
    with open('la_config/la_cms_config_v2.yml', 'w') as file:
        yaml.safe_dump(transformed_data, file, sort_keys=False)

# Run the function
transform_yaml()
