from dataclasses import dataclass
from typing import List

import yaml

from rtofdata.config import data_dir


@dataclass
class Field:
    id: str
    name: str
    type: str
    description: str = None
    comments: str = None
    primary_key: bool = False
    foreign_keys: List = None
    validation: dict = None


@dataclass
class Record:
    id: str
    description: str
    fields: List[Field]


def parse_specification():
    record_file_list = (data_dir / "records").glob("*.yml")

    record_list = []
    record_errors = []
    for record_file in record_file_list:
        with open(record_file, 'rt') as file:
            record_id = record_file.stem
            data = yaml.safe_load(file)

        field_dict = data.get('fields', {})
        data['fields'] = field_list = []
        for field_id, values in field_dict.items():
            try:
                field_list.append(Field(id=field_id, **values))
            except TypeError:
                record_errors.append(dict(
                    msg="Exception occurred when creating field from",
                    record=record_id,
                    field=field_id,
                    values=values
                ))

        record_list.append(Record(id=record_id, **data))

    if len(record_errors) > 0:
        error_fields = [f"{r['record']}.{r['field']}" for r in record_errors]
        raise ValueError(f"Error in the following fields: {error_fields}")

    return record_list
