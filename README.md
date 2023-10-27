# Children's Services Standard Safeguarding Dataset (SSD)

This is the (in progress)source repository for the Standard CSC Dataset for LAs and associated toolset (Project 1a SSDF). A broader, more granular, standardised dataset for Children's Social Care (CSC) in safeguarding authorities. Enabling increased scope for bespoke local analysis, using sector-driven national level data, that extends the existing DfE returns _(Ref: Project Stage 1)_ combined with a suite of methods/tools that all local authorities can adopt at near-zero running cost to independently produce the standardised dataset _(Ref: Project Stage 2)_. Current variation in local data caputure and storage limits data collaboration between LAs to standard ‘core’ datasets – most notably the Children in Need (CIN) Census and SSDA903, for children in need and looked after children respectively – and Ofsted’s “Annex A” specification of child-level data. These datasets often lack the depth and granularity that some individual LAs incorporate in bespoke local analysis, including to understand quality of practice and improved outcomes for vunerable children. 
Current phase : [prototype](#current-phase). 

## Initial core of the SSD

The dataset aims to 'flatten' existing local variation in collected data, thus enabling a significantly expanded collaborative set of data items and providing wider multi-regional/national level consistency, improved independent LA benchmarking and potential for identifying best practice outcomes journies. A six-year historical data scope is being suggested across the range of safeguarding activities performed by councils. Project oversight and governance is via a Steering Group, DfE and volunteer LA's as part of a pilot group. 

[Subscribe](https://forms.office.com/e/UysrcGApJ1) or [volunteer for pilot involvement](mailto:datatoinsight.enquiries@gmail.com?subject=[GitHub]%Standard%Safeguarding%Dataset-Subscribe). - Please be aware that in order to make it available to GitPages/Public, if being viewed outside of the Git Repo, this page has been generated from the repo README.md page and some inconsistent formating might be evident as a result. 

#### Current statutory returns
- SSDA903
- Annex A
- CIN Census

#### Iterative revisions based on developments in other (project)areas
- Regional Improvement and Innovation Alliance (RIIA)
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
- Linking data items to strategic goals
- Additional ongoing user research input


## Specification components

### Data objects Conceptual Model

Defining the scope of objects/data points capturing LA Childrens Services data during the different stages of an individual's progress through the CSC system(s). Published for iterative review.

- [data object/conceptual model](https://github.com/data-to-insight/ssd-data-model/blob/main/docs/index.html)
- [data object/item-guidance model](https://github.com/data-to-insight/ssd-data-model/blob/main/docs/guidance.html)
- [existing data returns map](https://github.com/data-to-insight/ssd-data-model/blob/main/docs/existingreturnsmap.html)

The project will use [GIT][git] to track and approve proposed changes to the safeguarding data standard.

### Specification

The object specification input file[csv] can be found in the [admin](./docs/admin) subfolder, and there is further ongoing work to provide further 'human readable' reporting methods beyond the aforementioned [data object conceptual model](https://data-to-insight.github.io/ssd-data-model/). We are aiming to publish our full data-landscape overview that resulted in the specification. 

### Change log

Agreed data item-level changes are assigned an identifier, and will be traceable within the [changelog.md](./CHANGELOG.md). A sub-set of the change details for the most recent change (if any) also appear within each objects metadata block within the YAML file(s). The current change log contains sample data until we deploy the first pilot release. Note: Object-level change tracking is not yet available/in progress; feedback/suggestions welcomed. 

```yaml
- name: <data object name>
  fields:
  - [...]
    metadata:
      release_datetime: 
      change_id: 
      item_changes_count: 
      change_reason: 
      change_type: <bug|new feature|change|...tbc>
```


### Data objects

The data model is described using [YAML][yaml], which is designed to be a "human friendly" data format, offering a more readable structure than such as XML/JSON, a reduced storage/processing footprint and in combination with Git provides an audit trail of changes that can be tracked.

The [objects](./data/objects) folder contains definition for the specification, data objects as well as details
of synthetic data parameters and validation rules that apply to each field within the object. At the moment, the validation definitions do not reference back to the stat-returns validation process. 

An example data object contains a description and a set of fields for that record. The fields have an ID (the key), a name,
type, description, which cms systems the data item/field is available on and any comments,

```yaml

- name: <data object name>
  fields:
  - name: <item Name>
    type: <string|int|categorical|list>
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
    guidance: <DfE of similar guidance txt>
    metadata:
      release_datetime: 
      change_id: 
      item_changes_count: 
      change_reason: 
      change_type: <bug|new feature|change|...tbc>
    [...]
```

### Categories

The [categories](./data/categories) folder holds the dimensions as referenced by `Categorical` and `List` datatypes.
A Dimension object has a value and description, where the value is what would normally be expected to be transferred
in an interchange format. The description is optional, and is not provided where the value is descriptive enough.

The YAML category files can either hold a list of string values, e.g.

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

Since the specification is intended to be easy to maintain, and most case management and data management systems aren't YAML aware, the project is working towards providing an open source set of [tools](./tools/) to perform the needed processing, incl. extract the required data items from current/known CMS systems and provide methods to allow the YAML object definitions to be easily updated from specification improvement updates or required revisions. Stakeholders and others are also invited to fork the repository and/or suggest changes to all elements of the project including definitions structure and code-base. 

Currently the YAML data objects, associated diagrams, documentation and website can be (re-)generated using the [tools](./tools/). The SQL[sql] tools are in development at the moment, but are aimed towards extracting the relevant data directly from different CMS systems in a CMS-agnostic approach; enabling the inclusion of both new data objects, new items in existing objects and revisions to both. SQL for each CMS type can be generated using the provided tools(Pilot includes only Liquid Logic and MOSAIC compatibility), and the resultant SQL scripts are output in the [SQL](./sql/) folder. 



### [Current phase](#current-phase)

The project is following a transparent and iterative development cycle, within the following deployment stages. Further stakeholder [feedback](https://forms.office.com/e/UysrcGApJ1) and involvement is welcomed at any phase. LA's that wish to take part in the pilot deployment are further invited to [get in touch](mailto:datatoinsight.enquiries@gmail.com?subject=[GitHub]%Standard%Safeguarding%Dataset). 


| Stage | Phase | Description |
| --- | --- | --- |
| 1 | User research | Approach outline and user research with LA's to look at how data works in relevant services, consider data gaps, challenges, and opportunities. |
| 1 | **Prototype [Current Phase]** | Detailed survey of current data item usage, link data items to strategic goals, prototype specification(peer feedback), initial workflow toolset |
| 2 | Deploy (pilot) | Deploy with support to pilot councils by developing reproducible implementations. |
| 2 | Feedback | Product delivered to the DfE and offer supported adoption for LA's and iterative further development. |
| 2 | Continuous Deployment | Maintenance roadmap and framework agreement towards iterative improvement-driven approach. |


### Local Authorities guiding development

**Hertfordshire CC** : Bid Lead | **Knowsley CC** : Steering Group | **Data2Insight** : Project Lead | **East Sussex CC** : Host Authority | Essex CC : Project Management | **ADCS North West** (hosted by **Stockport Council**)

Repo forks, and direct involvement with the project are welcomed and you can find more information about Data2Insight on our website [https://www.datatoinsight.org/](https://www.datatoinsight.org/)


## Repo workflow

In brief, folders [data](./data/), [docs](./docs/) & [sql](./sql/) are output folders. Python scripts within the tools folder generate those files with the exception of [docs/admin](./docs/admin) which contains the import csv definitions of all data objects & relationships. [tools/*.py](./tools/) are numbered to dictate their required run order when updating the specification. This workflow enables the entire project and all outputs to be instantly updated enabling full development transparency and ease of later updates both minor modifications and new modules/objects. It is anticipated that most LA's will only need to access the generated extract [SQL files](./sql/) for their particular CMS. 


### Repo running notes

The Python based toolset will run within a [Git Codespace](https://github.com/codespaces/new?hide_repo_select=true&ref=main&repo=645832800). Use this link, then run the setup file, by typing the below command on the command-line.   
Set up the working environment (will prompt Y/N part-way through, type 'y'to continue):
```bash
./setup.sh
```

  For ref: The above bash script contains and runs <all> the following required commands so there is no further setup required. In some rare occasions, where 
  errors in running anything to do with Pygraphviz subsequently occur, running this setup.sh script twice usually fixes the issue(s): 
```python
[$] pip install -r requirements.txt
[$] sudo apt-get update
[$] sudo apt-get install graphviz libgraphviz-dev pkg-config
[$] pip install pygraphviz

[$] pip install poetry
```

The python tools(.py) are in [tools](./tools/) folder. To run them, right click on the file and select 'run in terminal' or type filename on the commandline. This will only work if the setup.sh file has been already run to install the needed dependencies. 



## Other relevant links

[yaml] : https://yaml.org/
[git]: https://git-scm.com/
[sql] : https://en.wikipedia.org/wiki/SQL/
[jsc]: https://json-schema.org/
[csc]: https://digital-preservation.github.io/csv-schema/
[ghp]: https://pages.github.com/
[ssd-spec]: https://github.com/data-to-insight/ssd-data-model/


