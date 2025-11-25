
/* START

IF your LA is part of the DfE API Private Dashboard Early Adopters....

The following STAGING TABLE(S) object definitions are to be manually added into the SSD script from the API release files 
Please take the populate staging table .sql from the most recent release here(Ensure Postgres version):
https://github.com/data-to-insight/dfe-csc-api-data-flows/releases
*/


-- META-CONTAINER: {"type": "table", "name": "ssd_api_data_staging"}
-- =============================================================================
-- Description: Table for API payload and logging. For most LA's this is a placeholder structure as source data not common|confirmed
-- Author: D2I
-- =============================================================================



-- META-CONTAINER: {"type": "table", "name": "ssd_api_data_staging_anon"}
-- =============================================================================
-- Description: ssd_api_data_staging (_anon) tables for LIVE|TEST API payload and logging. 
-- Author: D2I
-- =============================================================================

-- META-ELEMENT: {"type": "test"}
-- Console reminder note
PRINT 'If your LA is part of the DfE API Private Dashboard Early Adopters you need to now run the seperate ssd_populate_api_data_staging.sql script ';
PRINT 'https://github.com/data-to-insight/dfe-csc-api-data-flows/releases'


/* END STAGING TABLE(S) object definitions */

