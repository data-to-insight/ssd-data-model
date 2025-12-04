#!/usr/bin/env python3
import re, zipfile, shutil
from pathlib import Path

EMBED_SCHEMA_LOOKUP_IN_PROC = False  # plain mode

# stems
IN_STEM  = Path("/workspaces/ssd-data-model/deployment_extracts/systemc/live/")
OUT_STEM = IN_STEM  # same in/out folder

# names
INPUT_NAME  = "ssd_deployment_individual_files/systemc_sqlserver_v1.3.7_1_20251203.sql"
OUTDIR_NAME = "ssd_deployment_proc_files"
ZIP_NAME    = "ssd_deployment_proc_files.zip"

# resolved paths
INPUT  = IN_STEM / INPUT_NAME
OUTDIR = OUT_STEM / OUTDIR_NAME
ZIPOUT = OUT_STEM / ZIP_NAME

# markers
container_start_re = re.compile(r'--\s*META-CONTAINER:\s*\{\s*"type"\s*:\s*"table"\s*,\s*"name"\s*:\s*"([^"]+)"\s*\}', re.IGNORECASE)
container_end_re   = re.compile(r'--\s*META-END\b', re.IGNORECASE)
create_table_pat   = re.compile(r'CREATE\s+TABLE\s+([a-zA-Z0-9_\.\[\]]+)\s*\(', re.IGNORECASE)

# clean rules
go_line_re         = re.compile(r'^\s*GO\s*$', re.IGNORECASE | re.MULTILINE)
schema_decl_re     = re.compile(r"^\s*DECLARE\s+@schema_name\s+NVARCHAR\(\d+\)\s*=\s*N'ssd_development';\s*$", re.IGNORECASE | re.MULTILINE)
meta_line_re       = re.compile(r'^\s*--\s*META-.*$', re.IGNORECASE | re.MULTILINE)
meta_test_line_re  = re.compile(r'^\s*--\s*META-ELEMENT:\s*\{"type":\s*"test"\}\s*$', re.IGNORECASE | re.MULTILINE)
version_re         = re.compile(r'^\s*--\s*Version:.*$', re.IGNORECASE | re.MULTILINE)
status_re          = re.compile(r'^\s*--\s*Status:.*$', re.IGNORECASE | re.MULTILINE)

def split_containers(text: str):
    pos, out = 0, []
    while True:
        m = container_start_re.search(text, pos)
        if not m: break
        name = m.group(1).strip()
        start = m.start()
        endm  = container_end_re.search(text, m.end())
        end   = endm.end() if endm else len(text)
        out.append((name, start, end))
        pos = end
    return out

def clean_block(block: str) -> str:
    # remove META test line and the immediate next line
    lines = block.splitlines(keepends=True)
    tmp, i = [], 0
    while i < len(lines):
        if meta_test_line_re.match(lines[i] or ""):
            i += 2
            continue
        tmp.append(lines[i]); i += 1
    block = "".join(tmp)

    # remove remaining META lines
    block = meta_line_re.sub("", block)

    # collapse Version..Status to baseline
    lines = block.splitlines(keepends=True)
    out, i = [], 0
    while i < len(lines):
        if version_re.match(lines[i] or ""):
            j = i + 1
            while j < len(lines) and not status_re.match(lines[j] or ""):
                j += 1
            if j < len(lines): j += 1
            out.append("-- Version: 1.0\n")
            out.append("-- Status: [D]ev-\n")
            i = j
            continue
        out.append(lines[i]); i += 1
    block = "".join(out)

    # remove redundant schema decl and GO
    block = schema_decl_re.sub("", block)
    block = go_line_re.sub("", block)

    # strip explicit schema prefixes everywhere, including quoted strings
    block = re.sub(r'(?i)\bssd_development\.', '', block)

    return block.strip() + "\n"

def proc_file_path(table_name: str) -> Path:
    base = table_name.split(".")[-1].strip("[]")
    return OUTDIR / "procs" / f"{base}.sql"

def build_proc_sql(base_proc_name: str, body_sql: str) -> str:
    # plain mode, create in caller default schema
    escaped_body = body_sql.replace("'", "''")
    return f"""IF OBJECT_ID(N'{base_proc_name}', N'P') IS NULL
BEGIN
    EXEC(N'CREATE PROCEDURE {base_proc_name} AS BEGIN SET NOCOUNT ON; RETURN; END');
END;
EXEC(N'CREATE OR ALTER PROCEDURE {base_proc_name}
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
{escaped_body}
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        DECLARE @ErrMsg nvarchar(2048) = ERROR_MESSAGE();
        DECLARE @ErrSev int = ERROR_SEVERITY();
        DECLARE @ErrState int = ERROR_STATE();
        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END');
"""

def write_bootstrap(setup_name: str, orchestrator_path: Path):
    procs_dir = OUTDIR / "procs"
    proc_files = sorted(procs_dir.glob("*.sql"), key=lambda p: p.name.lower())

    # ensure setup first if available
    setup_file = procs_dir / f"{setup_name}.sql"
    ordered = []
    if setup_file.exists():
        ordered.append(setup_file)
        proc_files = [p for p in proc_files if p != setup_file]
    ordered.extend(proc_files)

    # all includes relative to OUTDIR
    rel = lambda p: p.relative_to(OUTDIR)

    posix_lines = [f':r "{rel(p).as_posix()}"' for p in ordered]
    posix_lines.append(f':r "{rel(orchestrator_path).as_posix()}"')

    windows_lines = [f':r "{str(rel(p)).replace("/", "\\\\")}"' for p in ordered]
    windows_lines.append(f':r "{str(rel(orchestrator_path)).replace("/", "\\\\")}"')

    (OUTDIR / "00_install_all.sql").write_text("\n".join(posix_lines) + "\n", encoding="utf-8")
    (OUTDIR / "00_install_all_windows.sql").write_text("\n".join(windows_lines) + "\n", encoding="utf-8")


def main():
    text = INPUT.read_text(encoding="utf-8", errors="ignore")

    if OUTDIR.exists(): shutil.rmtree(OUTDIR)
    (OUTDIR / "procs").mkdir(parents=True)

    # setup proc
    setup_name = "ssd_setup"
    setup_sql = f"""IF OBJECT_ID(N'{setup_name}', N'P') IS NULL
    EXEC('CREATE PROCEDURE {setup_name} AS BEGIN SET NOCOUNT ON; RETURN; END');
GO
CREATE OR ALTER PROCEDURE {setup_name}
AS
BEGIN
    SET NOCOUNT ON;
    IF OBJECT_ID('tempdb..##ssd_runtime_settings') IS NOT NULL DROP TABLE ##ssd_runtime_settings;

    DECLARE @src_db     sysname = N'HDM';
    DECLARE @src_schema sysname = N'';  -- empty string means use caller default schema

    DECLARE @ssd_timeframe_years INT = 6;
    DECLARE @ssd_sub1_range_years INT = 1;

    DECLARE @today_date  date     = CONVERT(date, GETDATE());
    DECLARE @today_dt    datetime = CONVERT(datetime, @today_date);

    DECLARE @ssd_window_end   date = @today_date;
    DECLARE @ssd_window_start date = DATEADD(year, -@ssd_timeframe_years, @ssd_window_end);

    DECLARE @CaseloadLastSept30th date =
        CASE WHEN @today_date > DATEFROMPARTS(YEAR(@today_date), 9, 30)
             THEN DATEFROMPARTS(YEAR(@today_date), 9, 30)
             ELSE DATEFROMPARTS(YEAR(@today_date) - 1, 9, 30) END;

    DECLARE @CaseloadTimeframeStartDate date =
        DATEADD(year, -@ssd_timeframe_years, @CaseloadLastSept30th);

    CREATE TABLE ##ssd_runtime_settings(
        src_db sysname,
        src_schema sysname,
        ssd_timeframe_years int,
        ssd_sub1_range_years int,
        today_date date,
        today_dt datetime,
        ssd_window_start date,
        ssd_window_end date,
        CaseloadLastSept30th date,
        CaseloadTimeframeStartDate date
    );

    INSERT INTO ##ssd_runtime_settings
    VALUES(@src_db, @src_schema, @ssd_timeframe_years, @ssd_sub1_range_years,
           @today_date, @today_dt, @ssd_window_start, @ssd_window_end,
           @CaseloadLastSept30th, @CaseloadTimeframeStartDate);
END
GO
"""
    (OUTDIR / "procs" / f"{setup_name}.sql").write_text(setup_sql, encoding="utf-8")

    # per table procs
    procs = []
    for name, start, end in split_containers(text):
        block = text[start:end]
        m = create_table_pat.search(block)
        if not m:
            continue
        table_name = re.sub(r'[\[\]]','', m.group(1).strip())
        body = clean_block(block)
        base_table = table_name.split(".")[-1].strip("[]")
        base_proc  = f"proc_{base_table}"
        proc_sql   = build_proc_sql(base_proc, body)
        proc_file_path(table_name).write_text(proc_sql, encoding="utf-8")
        procs.append(base_proc)

    # orchestrator with runtime check for _custom(LA bespoke vers of ssd_tablename_custom.sql)
    lines = []
    lines.append("-- Master deploy runner for SSD table procs")
    lines.append("SET NOCOUNT ON;")
    lines.append("SET XACT_ABORT ON;")
    lines.append("BEGIN TRY")
    lines.append("    BEGIN TRANSACTION;")
    lines.append(f"    PRINT 'Running {setup_name}';")
    lines.append(f"    EXEC {setup_name};")
    lines.append("")
    lines.append("    DECLARE @schema_name sysname = (SELECT TOP 1 src_schema FROM ##ssd_runtime_settings);")
    lines.append("    DECLARE @p nvarchar(514), @pc nvarchar(514), @sql nvarchar(max);")
    lines.append("")
    for base_proc in procs:
        lines.append(f"    -- {base_proc}")
        lines.append(f"    IF NULLIF(@schema_name, N'') IS NULL")
        lines.append(f"    BEGIN")
        lines.append(f"        SET @p  = N'{base_proc}';")
        lines.append(f"        SET @pc = N'{base_proc}_custom';")
        lines.append(f"    END")
        lines.append(f"    ELSE")
        lines.append(f"    BEGIN")
        lines.append(f"        SET @p  = QUOTENAME(@schema_name) + N'.{base_proc}';")
        lines.append(f"        SET @pc = @p + N'_custom';")
        lines.append(f"    END")
        lines.append(f"    IF OBJECT_ID(@pc, N'P') IS NOT NULL")
        lines.append(f"        SET @sql = N'EXEC ' + @pc;")
        lines.append(f"    ELSE")
        lines.append(f"        SET @sql = N'EXEC ' + @p;")
        lines.append(f"    PRINT @sql;")
        lines.append(f"    EXEC(@sql);")
        lines.append("")
    lines.append("    COMMIT TRANSACTION;")
    lines.append("END TRY")
    lines.append("BEGIN CATCH")
    lines.append("    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;")
    lines.append("    THROW;")
    lines.append("END CATCH;")
    orchestrator_path = OUTDIR / "populate_ssd_data_warehouse.sql"
    # orchestrator_path = "populate_ssd_data_warehouse.sql"

    orchestrator_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

    # bootstrap installers
    write_bootstrap(setup_name, orchestrator_path)

    # zip everything under OUTDIR into ZIPOUT
    if ZIPOUT.exists(): ZIPOUT.unlink()
    with zipfile.ZipFile(ZIPOUT, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        for p in OUTDIR.rglob("*"):
            zf.write(p, p.relative_to(OUTDIR.parent))

if __name__ == "__main__":
    if OUTDIR.exists(): shutil.rmtree(OUTDIR)
    (OUTDIR / "procs").mkdir(parents=True, exist_ok=True)
    main()
