from dataclasses import dataclass
from typing import List
import traceback

import yaml

from rtofdata.config import data_dir


@dataclass
class Dimension:
    value: str
    description: str = None


@dataclass
class DimensionList:
    id: str
    dimensions: List[Dimension]


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
    dimensions: DimensionList = None


@dataclass
class Record:
    id: str
    description: str
    fields: List[Field]


@dataclass
class Specification:
    records: List[Record]
    dimensions: List[DimensionList]


def parse_dimensions():
    category_file_list = (data_dir / "categories").glob("*.yml")

    all_categories = []
    for category_file in category_file_list:
        category_id = category_file.stem
        category_list = []
        all_categories.append(DimensionList(id=category_id, dimensions=category_list))
        with open(category_file, 'rt') as file:
            data = yaml.safe_load(file)
        for datum in data:
            if "value" in datum:
                category_list.append(Dimension(**datum))
            else:
                category_list.append(Dimension(value=datum))

    return all_categories


def parse_records(categories):
    categories = {c.id: c for c in categories}
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
                field = Field(id=field_id, **values)
                field_list.append(field)
                if field.type == "Categorical":
                    field.dimensions = categories[field.validation['dimension']]

            except TypeError:
                record_errors.append(dict(
                    msg="Exception occurred when creating field from",
                    record=record_id,
                    field=field_id,
                    values=values,
                    exception=traceback.format_exc(),
                ))

        record_list.append(Record(id=record_id, **data))

    if len(record_errors) > 0:
        print("Input validation errors encountered:")
        for r in record_errors:
            print(f"*** {r['record']}.{r['field']} ***")
            print(f"{r['exception']}")
            print()

        error_fields = [f"{r['record']}.{r['field']}" for r in record_errors]
        raise ValueError(f"Error in the following fields: {error_fields}")

    return record_list


def parse_specification():
    categories = parse_dimensions()
    records = parse_records(categories)

    return Specification(records=records, dimensions=categories)
