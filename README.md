# Children's Services Standard Safeguarding Dataset (SSD)


This is the source repository for the Standard CSC dataset for LAs and associated toolset (Project 1a SSD). The dataset is a broader dataset for Children's Social Care (CSC) in safeguarding authorities, expanding beyond the existing returns _(Ref: Stage 1)_ with a suite of methods/tools that all local authorities can adopt at zero running cost to independently produce the dataset _(Ref: Stage 2)_. The dataset aims to flatten existing local variation in collected data, thus enabling a significantly expanded set of data items and providing a national level consistency and improved independent LA benchmarking. A six-year historical data scope is suggested across the range of safeguarding activities performed by councils. The project is developed in allignment with the Care Review and current social work practice.  Current phase : [prototype](#current-phase). 

## The initial core of the SSD is based on
### Current statutory returns
- SSDA903
- Annex A
- CIN Census
- Regional Improvement and Innovation Alliance (RIIA)

### Iterative revisions based on developments in other (project)areas
- Linking data items to strategic goals
- SEN2
- ADCS Safeguarding
- School Census
- EH Benchmarking
- Kinship Care (1b(i))
- Pre-Proceedings (1b(ii))
- Section 251 Finance (1b(iii))
- Voice of Child & Family (1b(iv))
- Social worker CMS input data (2a)
- CSC National Framework
- EET Activity
- and additional ongoing [user research](#user-research) input


## Data Object and Item Definitions

Towards the overall data model, published for iterative review  [current data object/entity model](https://data-to-insight.github.io/ssd-data-model/).

## Data Model

The data model defines a set of Objects capturing LA Childrens Services data during the different stages of an individual's progress
through the CSC system(s). The data model also includes a number of Categories (dimensions) that are referenced from the Fields within a Data Item.

The datamodel is described using [YAML][yaml], which is designed to be a "human friendly" data format, offering a more readable structure than such as XML/JSON, a reduced storage/processing footprint and in combination with Git provides an audit trail of changes that can be tracked.

The project will use [GIT][git] to track and approve proposed changes to the safeguarding data standard.

### Specification Components

The object specification input file[csv] can be found in the [admin](./docs/admin) subfolder, and there is further ongoing work to provide more 'human readable' reporting methods beyond the aforementioned [data object model](https://data-to-insight.github.io/ssd-data-model/). 

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


### Output

Since the specification is intended to be easy to maintain, and most case management and data management systems aren't YAML aware, the project is working towards providing a set of [tools][ssd-tools] to perform the needed processing, incl. extract the required data items from current/known CMS systems and provide methods to allow the Yaml Object definitions to be easily updated from specification improvement updates or required revisions.

Currently the yml data objects, associated diagrams, documentation and website can be (re-)generated using the [tools][ssd-tools]. The SQL[sql] tools to extract the relevant data directly from different CMS systems, are flexible; enabling the inclusion of both new data objects, new items in existing objects and revisions to both. SQL for each CMS type can be generated using the provided tools(Pilot includes only Liquid Logic and MOSAIC compatibility), and the resultant SQL scripts are output in the [SQL](./sql/) folder. 



### [Current Phase](#current-phase)
The project is with Steering Group support, following a transparent and iterative development cycle, within the following deployment process. Further stakeholder [feedback](#feedback-anchor) is welcomed at any phase.

- **User Research**
  : Approach outline and user research with LA's to look at how data works in relevant services, consider data gaps, challenges, and opportunities.
- **Prototype**
  : Detailed survey of current data item usage, link data items to strategic goals, develop the prototype specification utilizing peer feedback.
- **Deploy (pilot)**
  : Deploy with support to pilot councils by developing reproducible implementations.
- **Feedback**
  : Product delivered to the DfE and offer supported adoption for LA's.
- **Continuous Deployment**
  : Maintenance roadmap and framework agreement towards iterative improvement-driven approach.


### Contributors
- **East Sussex CC** : Project hosts
- **Hertfordshire CC** : Project


## Running notes
The Python based toolset will run within a [Git Codespace](https://github.com/codespaces/new?hide_repo_select=true&ref=main&repo=645832800). Use this link, then run the setup file, by typing the below command on the command-line.   
Set up the working environment (will prompt Y/N part-way through, type 'y'to continue):
```bash
./setup.sh
```

  For ref: The above bash script contains and runs <all> the following required commands so there is no further setup required.: 
```python
[$] pip install -r requirements.txt
[$] sudo apt-get update
[$] sudo apt-get install graphviz libgraphviz-dev pkg-config
[$] pip install pygraphviz

[$] pip install poetry
```

The python tools(.py files) are in [tools][ssd-tools] folder. To run them, the easiest way is to right click on the file and select 'run in terminal'. This will only work if the setup.sh file has been already run to installed the needed dependencies. 



### Other Relevant Links

[yaml] : https://yaml.org/
[git]: https://git-scm.com/
[sql] : https://en.wikipedia.org/wiki/SQL/
[jsc]: https://json-schema.org/
[csc]: https://digital-preservation.github.io/csv-schema/
[ghp]: https://pages.github.com/
[ssd-spec]: https://github.com/data-to-insight/ssd-data-model/


