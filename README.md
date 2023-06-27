# Standard Safeguarding Dataset

This is the source repository for the SSD data model and includes tools for both creating a standardised data set and providing a set of tools for manipulating and generating different outputs from the core specification. 

## Data Item and Entity Definitions
Towards the overall data model, published for iterative review  [current data object/entity model](./docs/index.html).


## Data Model

The data model defines a set of Objects capturing LA Childrens Services data during the different stages of an individual's progress
through the system(s). The data model also includes a number of Categories (dimensions) that are referenced from the Fields within a Record.

We define a number of validators that will be used to check data quality. These may be structural validators, such as a field is required or has to be in a defined set (dimension), or relational validators, such as a date should be after another date as events should happen sequentially.

The datamodel is described using [YAML][yaml], which, despite the website, is designed to be a "human friendly" data format. YAML has been used, as text-based format it offers a more human readable structure than such as XML/JSON, a reduced storage/processing footprint and tt provides also offers a proper audit trail of changes that can be tracked in a [Version Control System][vcs] (VCS).

The project will use [GIT][git] to track and approve proposed changes to the safeguarding data standard.

### Specification Components

The standard itself can be found in the [data](./data) subfolder. The specification aims to capture details of both conceptual
and logical data models, as well as data interchange formats.

#### Records

The [objects](./data/objects) folder contains definition for all the specification entity/objects as well as details
of synthetic data parameters and validation rules that apply to each field within the object.

An example data object contains a description and a set of fields for that record. The fields have an ID (the key), a name,
type, description, which cms systems the data item/field is available on and any comments,

```yaml

description: The description explains what this record captures

fields:

  field_name:
    name: <Formal Name>
    type: <string|int|Categorical|List>
    description: <Explanation of how to use the record>
    comments: <Development comments - such as issues raised>
    primary_key: <boolean>
    foreign_keys:
    - record: <record id>
      field:  <field id>>
    validation:
      <validator>: <args>

  [...]

```

#### Categories

The [categories](./data/categories) folder holds the dimensions as referenced by `Categorical` and `List` datatypes.
A Dimension object has a value and description, where the value is what would normally be expected to be transferred
in an interchange format. The description is optional, and is not provided where the value is descriptive enough.

The yaml files can either hold a list of string values, e.g.

```yaml
- Value 1
- Value 2
```
or a list of objects:

```yaml
- value: Value 1
  description: A description of value 1
- value: Value 2
  description: A description of value 2
```

#### Workflow
- tbc - 

The format of this file is still in development.

#### Validators

Similarly to the workflow file, the [validators file](./data/validators.yml) is a single file defining the validation
rules that are applied to fields when the data is received. It is also intended that this file, combined with the other
definitions, will be used for generating transfer format schemas, such as [JSON Schema][jsc] or [CSV Schema][csc].

The format of this file is still in development.

## Output Formats

Since the specification is intended to be easy to maintain, and most case management and data management systems aren't YAML aware, we provide a set of [tools][ssd-tools] to perform the needed processing tasks, incl. extract the required data items from current/known CMS systems, create ERD diagrams of the current structure, convert the YAML into more conventional formats.

The main place to find documentation relating to this specification is
-tbc- The website and associated documentation is generated using the [tools][ssd-tools] mentioned above.

## Continuous Deployment

-tbc-

## Relevant Links
[ssd-spec]: https://github.com/data-to-insight/ssd-data-model
[ssd-tools]: https://github.com/data-to-insight/ssd-data-model-tools

[yaml]: https://yaml.org/
[vcs]: https://en.wikipedia.org/wiki/Version_control
[git]: https://git-scm.com/
[jsc]: https://json-schema.org/
[csc]: https://digital-preservation.github.io/csv-schema/
[ssot]: https://en.wikipedia.org/wiki/Single_source_of_truth
[ghp]: https://pages.github.com/



## [Temp] Running notes:
./setup.sh

or.... 
pip install poetry

Ensure that you run the requirements file to set up before running scripts:
[$] pip install -r requirements.txt
Some of the .py scripts have package dependencies. To run the create_erd_from_yml.py ensure the following:
[$] sudo apt-get update
[$] sudo apt-get install graphviz libgraphviz-dev pkg-config
[$] pip install pygraphviz
