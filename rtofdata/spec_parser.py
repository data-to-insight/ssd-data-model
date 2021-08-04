from dataclasses import dataclass
from typing import List, Any
from dacite import from_dict

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
    sample_generator: dict = None


@dataclass
class Record:
    id: str
    description: str = None
    fields: List[Field] = None


@dataclass
class Workflow:
    name: str
    steps: List["WorkflowStep"]

    @property
    def all_steps(self):
        all_steps = []
        for s in self.steps:
            all_steps += s.all_steps
        for s in all_steps:
            if "flow" not in s:
                s["flow"] = self
        return all_steps


@dataclass
class WorkflowStep:
    name: str
    records: List[Record] = None
    flows: List[Workflow] = None

    @property
    def all_steps(self) -> List[Any]:
        all_steps = [dict(step=self)]
        for f in self.flows or []:
            all_steps += f.all_steps
        return all_steps


@dataclass
class Specification:
    records: List[Record]
    dimensions: List[DimensionList]
    flows: List[Workflow]


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
                    values=values
                ))

        record_list.append(Record(id=record_id, **data))

    if len(record_errors) > 0:
        error_fields = [f"{r['record']}.{r['field']}" for r in record_errors]
        raise ValueError(f"Error in the following fields: {error_fields}")

    return record_list


def parse_flow(records: List[Record]):
    records = {r.id : r for r in records}
    with open(data_dir / "workflow.yml", 'rt') as file:
        data = yaml.safe_load(file)

    flows = []
    for flow in data:
        flow = from_dict(data_class=Workflow, data=flow)
        for step in flow.all_steps:
            step["step"].records = [records[r.id] for r in step['step'].records or []]
        flows.append(flow)

    return flows


def parse_specification():
    categories = parse_dimensions()
    records = parse_records(categories)
    flows = parse_flow(records)

    return Specification(records=records, dimensions=categories, flows=flows)
