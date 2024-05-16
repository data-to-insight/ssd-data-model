# Children's Services Standard Safeguarding Dataset (SSD)

** If viewing this page from the SSD project pages please note that the (lack of) formatting here is as a result of the page being generated from the README file within the currently restricted access files repository. Public/open access is restreicted to this area, howerver LA's/Analysts are encouraged to request access via the below D2I email. **

This is the source repository for the Standard CSC Dataset for Local Authorities (Project 1a DDSF). A broader, more granular, standardised dataset for Children's Social Care (CSC) in safeguarding authorities. Enabling increased scope for bespoke local analysis using sector-driven national level data _(Ref: Project Stage 1)_; combined with a suite of methods/tools that all local authorities can adopt at near-zero running cost to independently produce the standardised dataset _(Ref: Project Stage 2)_. Current variation in local data caputure and storage limits data collaboration between LAs to standard ‘core’ datasets – most notably the Children in Need (CIN) Census and SSDA903, for children in need and looked after children respectively – and Ofsted’s “Annex A” specification of child-level data. These datasets often lack the depth and granularity that some individual LAs incorporate in bespoke local analysis, including to understand quality of practice and improved outcomes for vunerable children. 
Current phase : [deployment](#current-phase). 

## Initial core of the SSD

The dataset in-part aims to standardise existing local variation in how collected data is stored, thus enabling a significantly expanded collaborative set of data items and providing wider multi-regional/national level consistency, improved independent LA benchmarking and potential for identifying best practice outcomes journeys. A six-year historical data scope is proposed across the range of safeguarding activities performed by councils. Project oversight and governance via a dedicated steering group, DfE project team and volunteer LA's as part of an initial pilot and extended development group. 


## Running the SSD for/within your LA (Summarised getting started introduction)
Any representative from your LA is welcome to get in touch directly with questions or requests for support to get started with, or run the SSD (see following subscribe/contact/volunteer details). Obviously we welcome questions/input regardless of your involvement decision etc!  

The SSD is essentially a single SQL script, that creates labelled persistent tables in your existing database. There is no data sharing, and no changes to your existing systems are required. Data tables(with data copied from the raw CMS tables) and indexes for the SSD are created, and therefore in some cases will need support and/or agreement from either your IT or Intelligence team. The SQL script is always non-destructive, i.e. it does nothing to your existing data/tables/anything - the SSD process is simply a series of SELECT statements, pulling copied data into a new standardised field and table structure on your own system for access by only you/your LA.  

### Getting started workflow: 
The development and deployment of the SSD is functional only within, and as a result of direct involvement with Local Authorities. So we're not expectant of a one-size-fits-all approach, and will work with your team(s) to ensure confidence in, and successfull implementation of the SSD for your LA.  
- Contact us with your interest --> Conversations to assist running(within LA) & any basic set up needed --> Access given to the SSD script by email or via Github --> LA runs SSD --> Support available if needed --> shared access given to any available further tools e.g. stat-returns scripts etc. --> Feedback and improvements change requests as needed.

[Subscribe](https://forms.office.com/e/UysrcGApJ1) or [volunteer for pilot involvement](mailto:datatoinsight.enquiries@gmail.com?subject=[GitHub]%Standard%Safeguarding%Dataset-Subscribe). - Please be aware that in order to make this information page available outside the (currently private)code repositiory, this page has been re-generated from the (currently private)README.md page and as a result some inconsistent/unstructured text formating might be evident. Links to folders within the (currently)private respository will of course also not work until your LA is granted access.

## Specification components

### Specification

The SSD specification has been developed through extensive sector research, consideration of existing DfE returns, concurrent DfE projects, 130hrs+ of direct user research with Local Authorities and stakeholders. Project specification development has been made transparent at the monthly DfE Show & Tells (as part of the DDSF S&T's March'23-Feb'24) concurrent with the aforementioned oversight and governance. 

The project will use [GIT][git] to track and approve proposed changes to the safeguarding data standard.
The object specification input file[csv] can be found in the [admin](./docs/admin) subfolder, and there is further ongoing work to provide further 'human readable' reporting methods beyond the aforementioned [data object conceptual model](https://data-to-insight.github.io/ssd-data-model/). We are aiming to publish our full data-landscape overview that resulted in the specification. 

#### SSD in conjuction with (project|sector)developments

As part of the projects research and initial scoping, the team have considered input and results from all of the following sector developments towards ensuring that the SSD take current and changing LA/DfE needs into account. 
- CSC National Framework  
- SEN2
- ADCS Safeguarding
- School Census
- EH Benchmarking
- EET Activity
- Linking data items to strategic goals
- Additional ongoing user research input
- Kinship Care (DDSF 1b(i))
- Pre-Proceedings (DDSF 1b(ii))
- Section 251 Finance (DDSF 1b(iii))
- Voice of Child & Family (DDSF 1b(iv))
- Social worker CMS input data (DDSF 2a)


### Local Authorities guiding development

**Hertfordshire CC** : Bid Lead | **Knowsley CC** : Steering Group | **Data2Insight** : Project Lead | **East Sussex CC** : Host Authority | Essex CC : Project Management and Mosaic Pilot Development | **ADCS North West** (hosted by **Stockport Council**) | **Blackpool CC** : Mosaic Pilot Development | **East Riding CC** : Azeus Pilot Development  

Repo forks, and direct involvement with the project are welcomed and you can find more information about Data2Insight on our website [https://www.datatoinsight.org/](https://www.datatoinsight.org/)

--- 
##  SSD development details

### Technical and low-level SSD detail

The additional explanation detail that follows is relevant to those seeking a more in depth understanding of the granular SSD development detail. The majority of what follows on this page can be ignored/is less relevant to those looking only to set up their LA for SSD use. 



### Data objects Conceptual Model

Defining the scope of objects/data points capturing LA Childrens Services data during the different stages of an individual's progress through the CSC system(s). Published for iterative review.

- [data object/conceptual model](https://data-to-insight.github.io/ssd-data-model/index.html)
- [data object/item-guidance model](https://data-to-insight.github.io/ssd-data-model/guidance.html)
- [existing data returns map](https://data-to-insight.github.io/ssd-data-model/existingreturnsmap.html)



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
| 1 | Prototype | Detailed survey of current data item usage, link data items to strategic goals, prototype specification(peer feedback), initial workflow toolset |
| 2 | **Deploy(pilot) [Current Phase]** | Deploy with support to pilot councils by developing reproducible implementations. |
| 2 | Feedback | Product delivered to the DfE and offer supported adoption for LA's and iterative further development. |
| 2 | Continuous Deployment | Maintenance roadmap and framework agreement towards iterative improvement-driven approach. |



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


