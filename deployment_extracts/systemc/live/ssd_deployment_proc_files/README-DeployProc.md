# SSD proc-based deployment, how to run

## What's in this folder
```
.
├─ 00_install_all.sql                 SQLCMD bootstrap, creates or updates all procs
├─ 00_install_all_windows.sql         Windows slashes variant of the same
├─ populate_ssd_data_warehouse.sql    *Orchestrator, declares shared vars and runs each proc*
└─ procs/
   ├─ proc_ssd_address.sql
   ├─ proc_ssd_disability.sql
   └─ … one file per table
```

## Quick start in Azure Data Studio or SSMS

### Step 1, install or update procedures
1. Open `00_install_all.sql`
2. Enable SQLCMD mode, Command Palette, Toggle SQLCMD, or Settings, search for sqlcmd, enable for MSSQL
3. Connect the editor to the target database
4. Run. This includes every `procs/*.sql` and compiles the procedures. It also includes `populate_ssd_data_warehouse.sql` so it is available in the editor

Tip, you can also open any single file in `procs` and run it if you only changed one table.

### Step 2, run the orchestrator
1. Open `populate_ssd_data_warehouse.sql`
2. Connect to your target reporting database(e.g. hdm_local) or add `USE <dbname>;` at the top
3. Adjust the variables as needed
   - `@src_schema`, empty string means use the session default schema for proc names
   - `@ssd_timeframe_years`, `@ssd_sub1_range_years`, date window values
4. Run. The orchestrator prefers `_custom` overrides if present, for example `proc_ssd_person_custom`


## Quick start run from the command line(if preferred)

Use the `sqlcmd` utility. The includes in `00_install_all.sql` are relative to the working directory.

Windows PowerShell
```powershell
# install or update procs
sqlcmd -S yourserver -d yourdb -E -b -i ".\00_install_all_windows.sql"

# run the orchestrator
sqlcmd -S yourserver -d yourdb -E -b -i ".\populate_ssd_data_warehouse.sql"
```

Linux or macOS
```bash
# install or update procs
sqlcmd -S yourserver -d yourdb -G -b -i ./00_install_all.sql
# or, if using SQL auth
# sqlcmd -S yourserver -d yourdb -U youruser -P 'yourpass' -b -i ./00_install_all.sql

# run the orchestrator
sqlcmd -S yourserver -d yourdb -G -b -i ./populate_ssd_data_warehouse.sql
```

Notes
- `-E` uses Windows integrated auth on Windows. `-G` uses Azure AD. `-U` and `-P` use SQL auth
- Keep the working directory at the folder that contains `00_install_all.sql`, so the relative `:r "procs/..."` lines resolve correctly

## SQL Server Agent job pattern

Create a two step job.

1. Step type CmdExec, runs `sqlcmd` to execute `00_install_all.sql`. This compiles or updates the procedures. Use a working directory that contains the files or pass full paths
2. Step type CmdExec, runs `sqlcmd` to execute `populate_ssd_data_warehouse.sql`

You can also merge into one step by chaining two `sqlcmd` invocations in a small `.cmd` file and calling that from the job step.

## Custom per LA overrides

- If within your LA a file `procs/proc_ssd_<table>_custom.sql` exists and compiles to a procedure named the same, the orchestrator will prioritise|prefer it. This enables LA's to locally define their requirements for specific SSD table definitions. We hope that this also provides greater/easier oversight/change management if/when changes in the D2I source SSD occur. 
- The orchestrator passes the same parameter set to both base and custom versions, so your custom proc can accept the same parameters and ignore ones it does not need

## Calling a single table proc by hand

Every generated procedure accepts a shared parameter set and has safe defaults, so you can run one directly.

```sql
EXEC proc_ssd_disability
     @src_db = N'HDM',
     @src_schema = N'',
     @ssd_timeframe_years = 6,
     @ssd_sub1_range_years = 1,
     @today_date = CONVERT(date, GETDATE()),
     @today_dt = GETDATE(),
     @ssd_window_start = DATEADD(year, -6, CONVERT(date, GETDATE())),
     @ssd_window_end = CONVERT(date, GETDATE()),
     @CaseloadLastSept30th = DATEFROMPARTS(YEAR(GETDATE()) - CASE WHEN GETDATE() <= DATEFROMPARTS(YEAR(GETDATE()), 9, 30) THEN 1 ELSE 0 END, 9, 30),
     @CaseloadTimeframeStartDate = DATEADD(year, -6, DATEFROMPARTS(YEAR(GETDATE()) - CASE WHEN GETDATE() <= DATEFROMPARTS(YEAR(GETDATE()), 9, 30) THEN 1 ELSE 0 END, 9, 30));
```

If you omit parameters, defaults inside the proc will fill them.

## Schema handling

- Procedure names, the orchestrator(populate_ssd_data_warehouse.sql) will use `@src_schema` when looking up and executing `proc_*` and `proc_*_custom`. Set `@src_schema = N''` to execute without a schema prefix, this uses the default schema of the login.
- Table DDL inside each proc is unqualified, tables are created or truncated in the default schema of the execution context. If you need to force a schema for tables, connect with a user that has that default schema or modify the proc body locally to qualify the target tables.

## Troubleshooting

- Error, could not find stored procedure, you have not run `00_install_all.sql` against this database, or you ran it in another database, or SQLCMD mode was off and includes did not run. Install again with SQLCMD on, then run the orchestrator.
- Includes do not work, enable SQLCMD mode in the editor tab, check that the status bar shows SQLCMD.
- The bootstrap cannot find files, open `00_install_all.sql` from the same folder that contains the `procs` subfolder so the relative `:r` lines resolve.
- You still see `ssd_development.` in DDL, regenerate files. The generator strips that prefix. If you hand edited any procs, search and remove those prefixes.



## D2I Admin only - Updating to a new source script

- Drop the new source `.sql` into the `ssd_deployment_individual_files` folder
- Run the Python generator. It picks the newest `.sql` automatically
- In Azure Data Studio, run `00_install_all.sql` with SQLCMD mode on, then run `populate_ssd_data_warehouse.sql`
