# Children's Services Standard Safeguarding Dataset (SSD)
#### Current phase: prototype/review
This is the source repository for the SSD dataset and tools for creating the required data. The repository contains the definitions for a broader standard dataset for Children's Social Care (CSC) in safeguarding authorities beyond the existing returns dataset(s) (stage 1) and a set of solutions/tools that local authorities can adopt at low/zero cost to enable and produce the dataset.

The initial core of the SSD has been based around current statutory returns
- SSDA903
- Annex A
- CIN Census

and alongside LA user research iteratively considering
- Linking data items to strategic goals
- SEN2
- ADCS Safeguarding
- RIIA
- School Census
- EH Benchmarking
- Kinship Care
- Pre-Proceedings
- Section 251 Finance
- Voice of Child & Family
- CSC National Framework
- EET Activity



## Data Object and Item Definitions

Towards the overall data model, published for iterative review  [current data object/entity model](./docs/index.html).


## Data Model

The data model defines a set of Objects capturing LA Childrens Services data during the different stages of an individual's progress
through the system(s). The data model also includes a number of Categories (dimensions) that are referenced from the Fields within a Record.

The datamodel is described using [YAML][yaml], which is designed to be a "human friendly" data format, offering a more readable structure than such as XML/JSON, a reduced storage/processing footprint and in combination with Git provides an audit trail of changes that can be tracked.

The project will use [GIT][git] to track and approve proposed changes to the safeguarding data standard.

### Specification Components

The standard itself can be found in the [data](./data) subfolder. The specification aims to capture details of both conceptual
and logical data models, as well as data interchange formats.

#### Data Objects

The [objects](./data/objects) folder contains definition for all the specification entity/objects as well as details
of synthetic data parameters and validation rules that apply to each field within the object.

An example data object contains a description and a set of fields for that record. The fields have an ID (the key), a name,
type, description, which cms systems the data item/field is available on and any comments,

```yaml

- name: <data object name>
  fields:
  - name: <item Name>
    type: <string|int|Categorical|List>
    description: 
    item_ref: <data item ref code>
    primary_key: <true>
    validators:
      <validator>:  
    categories:
    returns:
    cms:
    cms_field:
    - liquid_logic:<ll_field_name>
    - mosaic: <mosaic_field_name>
    cms_table:
    - liquid_logic:<ll_tbl_name>
    - mosaic: <mosaic_tbl_name>
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

- tbc - This file/concept is still in development.



### Output Formats

Since the specification is intended to be easy to maintain, and most case management and data management systems aren't YAML aware, we provide a set of [tools][ssd-tools] to perform the needed processing tasks, incl. extract the required data items from current/known CMS systems, create ERD diagrams of the current structure, convert the YAML into more conventional formats.

The website and associated documentation is generated using the [tools][ssd-tools] mentioned above.

Further/additional documentation relating to this specification: -tbc- 

### Continuous Deployment

-tbc-

### Running notes

Use the following command in a Git Codespace to set up the working environment:
```bash
./setup.sh
```

  For ref: The above bash script contains and runs <all> the following required commands: 
```python
[$] pip install -r requirements.txt
[$] sudo apt-get update
[$] sudo apt-get install graphviz libgraphviz-dev pkg-config
[$] pip install pygraphviz

[$] pip install poetry
```

### Get in touch

If you have any questions about this repo, code or the structure definition, contact the project leads via the ([D2I the web site](https://www.datatoinsight.org/collaboration))


### Relevant Links

[yaml] : https://yaml.org/
[git]: https://git-scm.com/
[jsc]: https://json-schema.org/
[csc]: https://digital-preservation.github.io/csv-schema/
[ghp]: https://pages.github.com/
[ssd-spec]: https://github.com/data-to-insight/ssd-data-model/


