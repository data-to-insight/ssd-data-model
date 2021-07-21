def add_unique_rules(rules, input_data):
    """
    Adds validation rules based on the 'Required' column containing anything with a Y in it
    """
    field_list = input_data['Fields']
    for field in field_list:
        required = field.get("Required")
        if required is not None and 'y' in required.lower():
            table_name = field['Table']
            field_name = field['ID']
            name = f'{table_name}.{field_name}'
            rules[f'{name}.notnull'] = dict(
                validator="notnull",
                description=f"Field {name} must be present in the record"
            )
            rules[f'{name}.notblank'] = dict(
                validator="notblank",
                description=f"Field {name} must not be blank non-zero length and not just spaces"
            )


def add_after_date_rules(rules, input_data):
    """
    Adds validation rules based on the 'After Date' column containing a reference to another date field
    """
    field_list = input_data['Fields']
    for field in field_list:
        after_date = field.get("After Date")
        if after_date:
            table_name = field['Table']
            field_name = field['ID']
            name = f'{table_name}.{field_name}'

            after_field = next(f for f in field_list if f['ID'] == after_date.strip())

            rules[f'{name}.date_after.{after_field["ID"]}'] = dict(
                validator="notnull",
                description=f"Field {name} must be after {after_field['Table']}.{after_field['ID']}."
            )


def generate_validation_rules(input_data):
    rules = {}

    add_unique_rules(rules, input_data)
    add_after_date_rules(rules, input_data)

    return rules
