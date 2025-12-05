# Standard Safeguarding Dataset(SSD) Extract

## Overview

Standard Safeguarding Dataset (SSD) extract script for local authorities

- Builds SSD layer from source CMS tables  
- Creates SSD prefixed persistent tables and supporting indexes in target database  
- Designed for T-SQL compatibility across SQL Server 2012 to 2022, Postgres for OLM|Eclipse.   

Project home:  
https://data-to-insight.github.io/ssd-data-model-next/ 
https://data-to-insight.github.io/ssd-data-model/ [Legacy project site]
https://github.com/data-to-insight/ssd-data-model/blob/main/README.md [Main project README]

## Purpose and scope

The extract script

- Reads from local authority CMS source tables  
- Populates SSD tables in a consistent, reporting friendly structure  
- Supports downstream use cases including DfE Early Adopter API payloads and local analytics  
- Allows database and schema configuration within the script before deployment  

## Safe pilot and test usage

Recommended approach for initial adoption

- Run initial pilots and trials in non production environments eg. development or test  
- By default all SSD objects are created under schema `ssd_development`  
  this simplifies early adoption, testing, and review  
- Once validated, teams can switch to an alternative schema name or to a production database  

## Changing schema name

To change or remove the default `ssd_development` schema reference

### Remove schema prefix completely

1. Search whole script for string  
   `ssd_development.`  
2. Replace with an empty string ie. ``

This removes the schema prefix and allows use of the database default schema  
eg. `dbo`

### Replace with local schema

1. Search whole script for string  
   `ssd_development.`  
2. Replace with  
   `your_schema_name.`  

Notes

- Include trailing dot in both search and replacement  
- Do not use quotes around schema name in the script  

## Legacy compatibility blocks (`#LEGACY-PRE2016`)

For local authorities running SQL Server 2016 SP1 or later an improved, non legacy path is available

- Search script for marker `#LEGACY-PRE2016`  
- At each location follow inline comments to  
  - enable modern T SQL block  
  - optionally remove legacy default block after testing  

This keeps SQL Server 2012 compatibility available while allowing later LAs to use cleaner features where appropriate

## Object naming and drop behaviour

The script is designed to be non destructive outside the SSD namespace

- Explicit `DROP TABLE` statements are used only for tables whose names start with `SSD_`  
- All SSD related components follow a consistent naming convention, eg.  
  - tables: `SSD_*`  
  - indexes: `IX_SSD_*`, `UX_SSD_*`, `CIX_SSD_*`  

Benefits

- Clear separation between SSD layer and other database objects  
- Easier auditing, support and operational oversight  

## Relationship to local CMS and governance

SSD tables copy data from raw CMS tables into a normalised, reporting friendly structure

Local authorities should consider

- Governance and sign off for creating new tables and indexes  
- Capacity and performance impact of SSD tables and supporting indexes  
- Coordination with IT, data, and intelligence teams for rollout and maintenance  

## Alternative temp table variant

Some local authorities only have read access to CMS database or schema  
for those teams a temp table based variant can be generated

Steps

1. Replace every instance of string  
   `ssd_development.`  
2. With  
   `#`  

This converts SSD tables into session scoped temp tables

Notes

- Temp based variant is suitable for short lived analysis or API payload runs within a single session  
- Before using temp approach for production style workloads, review local constraints on session duration, resource limits and job orchestration  

## Testing notes and inline markers

Script still contains inline testing markers while wider local authority testing continues

- `[TESTING]` marks temporary diagnostics or console style output  
  these assist with run time problem solving and early adoption  
- `[REVIEW]` identifies items where SSD project team review is requested  

Local authorities may

- Remove `[TESTING]` blocks once confident in local behaviour  
- Leave `[REVIEW]` markers visible until upstream guidance or revised patterns are available  

---

## Development object and item status flags

Development status flags are applied to objects and items in approximate lifecycle order  

These flags may appear in metadata, comments or YAML style descriptors

### Status codes

- `[B]`   Backlog  
  To do or for review, not current priority  

- `[D]`   Dev  
  In active development  

- `[T]`   Test  
  Under developer or run time testing  

- `[DT]`  DataTesting  
  Extract data being sense checked  

- `[AR]`  AwaitingReview  
  Awaiting SSD project team review and sign off  

- `[R]`   Release  
  Ready for wider release and secondary data testing  

- `[Bl]`  Blocked  
  Data not held in CMS or not accessible, or blocked for another reason  

- `[P]`   Placeholder  
  Data not expected to be held by most LAs, or new data where structure currently placeholder  

### Current development notes

- Overall script status: `[REVIEW]`  
- DfE returns expect dates formatted as `dd/mm/YYYY`  
  SSD extracts initially retain `DATETIME` types rather than `DATE`  
- Some default field sizes are intentionally generous  
  eg. `family_id NVARCHAR(48)` to maximise compatibility across CMS and local authority implementations  
- Caseload count logic is under active review  
  open question whether to restrict counts to SSD timeframe window or use full system history  

### Item level metadata pattern

Where used, item level metadata follows a simple key value structure, eg.

```jsonc
metadata = {
  "item_ref": "AAAA000A",

  // optional fields
  "item_status": "[B], [D]...",        // as per status list above
  "expected_data": ["value1", "value2"],
  "info": "short description"
}
```

---

## Version history reference

Full SSD version history maintained centrally

Source file

- `deployment_extracts/ssd_version_history.yml` in the main SSD data model repository  

GitHub location

- https://github.com/data-to-insight/ssd-data-model/tree/main/deployment_extracts/ssd_version_history.yml
