# Data model

This is the source repository for the SSD data model and includes tools for generating different outputs from the core
specification. The basis for this work was cloned from SocialFinanceDigitalLabs/rtof-data-model.

## Data Model

The data model defines a set of Records (facts) capturing data during the different stages of an individual's progress
through the programme. The data model also includes a number of Categories (dimensions) that are referenced from
the Fields within a Record.

Because records are captured as part of a programme workflow, we also store the "ideal" workflow so we can indicate
records in the order they are likely to be captured. However, we do recognise that this may not always be the case.

Finally, we define a number of validators that will be used to check data quality. These may be structural validators,
such as a field is required or has to be in a defined set (dimension), or relational validators, such as a date should
be after another date as events should happen sequentially.

The datamodel is described using [YAML][yaml], which, despite the website, is designed to be a
"human friendly" data format. The main reason for capturing the standard in YAML is that, because it is a text-based
format, it provides a proper audit trail of changes and can be tracked in a [Version Control System][vcs] (VCS).


As the programme progresses, we will use [GIT][git] to track and approve proposed changes to the data standard.

### Specification Components

The standard itself can be found in the [data](./data) subfolder. We purposefully did not want to start of with an
existing data Schema format, such as XML schemas as they are tightly coupled to the transfer format. For this project,
the data model defines the conceptual data model. However, the specification aims to capture details of both conceptual
and logical data models, as well as data interchange formats.

#### Records

The [records](./data/records) folder contains definition for all the specification records (facts) as well as details
of synthetic data parameters and validation rules that apply to each field within the record.

An example record contains a description and a set of fields for that record. The fields have an ID (the key), a name,
type, description, comments,

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

The [workflow file](./data/workflow.yml) describes the order in which the records are expected to be captured and is
mostly used to provide a useful ordering in documentation.

The format of this file is still in development.

#### Validators

Similarly to the workflow file, the [validators file](./data/validators.yml) is a single file defining the validation
rules that are applied to fields when the data is received. It is also intended that this file, combined with the other
definitions, will be used for generating transfer format schemas, such as [JSON Schema][jsc] or [CSV Schema][csc].

The format of this file is still in development.

## Output Formats

Since the specification is intended to be easy to maintain, it is not necessarily that easy to process for humans, and
most case management and data management systems aren't YAML aware, we provide a [set of tools][rtof-tools] to convert the YAML into
more conventional formats.

The main place to find documentation relating to this specification is
-tbc- The website and associated documentation is generated using the [tools][rtof-tools] mentioned above.

## Continuous Deployment

-tbc-


[ssd-spec]: https://github.com/data-to-insight/ssd-data-model
[ssd-tools]: https://github.com/data-to-insight/ssd-data-model-tools
[ssd-web]: https://sfdl.org.uk/SSD-specification/

[yaml]: https://yaml.org/
[vcs]: https://en.wikipedia.org/wiki/Version_control
[git]: https://git-scm.com/
[jsc]: https://json-schema.org/
[csc]: https://digital-preservation.github.io/csv-schema/
[ssot]: https://en.wikipedia.org/wiki/Single_source_of_truth
[ghp]: https://pages.github.com/
