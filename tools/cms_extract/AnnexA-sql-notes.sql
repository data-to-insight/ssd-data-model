/*
******************
SSD AnnexA Returns
******************

Variations on how to achieve depending on db type

/**** MySQL ****/
INTO OUTFILE '/root/exports/Ofsted List 1 - Initial Contacts.csv'
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n';

-- Date field handling/formatting
DATE_FORMAT(p.person_dob, '%d/%m/%Y') AS formatted_person_dob,
DATE_FORMAT(c.contact_date, '%d/%m/%Y') AS formatted_contact_date,
On date filter use: DATE_ADD(CURRENT_DATE, INTERVAL -12 MONTH)


/**** SQL Server ****/
use built in export as or
bcp "QUERY_HERE" queryout "C:\path\to\myfile.csv" -c -t, -S SERVER_NAME -d DATABASE_NAME -U USERNAME -P PASSWORD

-- Date field handling/formatting
FORMAT(p.person_dob, 'dd/MM/yyyy') AS formatted_person_dob,
FORMAT(c.contact_date, 'dd/MM/yyyy') AS formatted_contact_date,
On date filter use:     -- DATEADD(YEAR, -6, GETDATE()) *** in place of *** DATE_ADD(CURRENT_DATE, INTERVAL -12 MONTH)


/**** Oracle ****/
sqlplus username/password@databasename @/path_to_script/export_data.sql

SET HEADING ON
SET COLSEP ","
SET LINESIZE 32767
SET PAGESIZE 50000
SET TERMOUT OFF
SET FEEDBACK OFF
SET MARKUP HTML OFF SPOOL OFF
SET NUM 24

SPOOL /root/exports/Ofsted List 1 - Initial Contacts.csv
-- main query
SPOOL OFF
EXIT;

-- Date field handling/formatting
TO_CHAR(p.person_dob, 'DD/MM/YYYY') AS formatted_person_dob,
TO_CHAR(c.contact_date, 'DD/MM/YYYY') AS formatted_contact_date,


/**** PostGres ****/

-- Date field handling/formatting
TO_CHAR(p.person_dob, 'DD/MM/YYYY') AS formatted_person_dob,
TO_CHAR(c.contact_date, 'DD/MM/YYYY') AS formatted_contact_date,




**************************
SSD AnnexA Returns Queries
**************************
*/