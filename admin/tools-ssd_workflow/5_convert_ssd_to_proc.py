#!/usr/bin/env python3
import re, zipfile, shutil
from pathlib import Path

# plain mode, cleaner files
EMBED_SCHEMA_LOOKUP_IN_PROC = False

# stems
IN_STEM  = Path("/workspaces/ssd-data-model/deployment_extracts/systemc/live/")
OUT_STEM = IN_STEM  # same in and out folder

# names
INPUT_PATTERN = "ssd_deployment_individual_files/*.sql"  # pick latest .sql in this folder
OUTDIR_NAME   = "ssd_deployment_proc_files"
ZIP_NAME      = "ssd_deployment_proc_files.zip"

# resolved output paths
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

def resolve_input() -> Path:
    """Pick the newest .sql that matches INPUT_PATTERN under IN_STEM."""
    candidates = [p for p in IN_STEM.glob(INPUT_PATTERN) if p.is_file()]
    if not candidates:
        raise SystemExit(f"No .sql files matched: {IN_STEM}/{INPUT_PATTERN}")
    try:
        candidates.sort(key=lambda p: (p.stat().st_mtime, p.name), reverse=True)
    except Exception:
        candidates.sort(key=lambda p: p.name, reverse=True)
    return candidates[0]

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


# def build_proc_sql(base_proc_name: str, body_sql: str) -> str:
    """
    Each proc accepts a standard parameter set and normalises defaults so procs
    remain self contained if you call them directly
    """
    escaped_body = body_sql.replace("'", "''")

    params = (
        "@src_db sysname = NULL,\n"
        "    @src_schema sysname = NULL,\n"
        "    @ssd_timeframe_years int = NULL,\n"
        "    @ssd_sub1_range_years int = NULL,\n"
        "    @today_date date = NULL,\n"
        "    @today_dt datetime = NULL,\n"
        "    @ssd_window_start date = NULL,\n"
        "    @ssd_window_end date = NULL,\n"
        "    @CaseloadLastSept30th date = NULL,\n"
        "    @CaseloadTimeframeStartDate date = NULL\n"
    )

    defaults = (
        "    -- normalise defaults if not provided\n"
        "    IF @src_db IS NULL SET @src_db = DB_NAME();\n"
        "    IF @src_schema IS NULL SET @src_schema = SCHEMA_NAME();\n"
        "    IF @ssd_timeframe_years IS NULL SET @ssd_timeframe_years = 6;\n"
        "    IF @ssd_sub1_range_years IS NULL SET @ssd_sub1_range_years = 1;\n"
        "    IF @today_date IS NULL SET @today_date = CONVERT(date, GETDATE());\n"
        "    IF @today_dt   IS NULL SET @today_dt   = CONVERT(datetime, @today_date);\n"
        "    IF @ssd_window_end   IS NULL SET @ssd_window_end   = @today_date;\n"
        "    IF @ssd_window_start IS NULL SET @ssd_window_start = DATEADD(year, -@ssd_timeframe_years, @ssd_window_end);\n"
        "    IF @CaseloadLastSept30th IS NULL SET @CaseloadLastSept30th = CASE\n"
        "        WHEN @today_date > DATEFROMPARTS(YEAR(@today_date), 9, 30) THEN DATEFROMPARTS(YEAR(@today_date), 9, 30)\n"
        "        ELSE DATEFROMPARTS(YEAR(@today_date) - 1, 9, 30) END;\n"
        "    IF @CaseloadTimeframeStartDate IS NULL SET @CaseloadTimeframeStartDate = DATEADD(year, -@ssd_timeframe_years, @CaseloadLastSept30th);\n"
    )

    return f"""IF OBJECT_ID(N'{base_proc_name}', N'P') IS NULL
BEGIN
    EXEC(N'CREATE PROCEDURE {base_proc_name} AS BEGIN SET NOCOUNT ON; RETURN; END');
END;
EXEC(N'CREATE OR ALTER PROCEDURE {base_proc_name}
    {params}
AS
BEGIN
    SET NOCOUNT ON;
{defaults}
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

def build_proc_sql(base_proc_name: str, body_sql: str) -> str:
    """
    Emit plain T-SQL procs, no EXEC string wrapping, no doubled quotes
    Keep the tiny dynamic stub only for first-time create to avoid parse errors
    
    i.e.
    No escaped_body = body_sql.replace("'", "''")
    body inserted verbatim, so IF OBJECT_ID('tempdb..#...','U') uses single quotes
    """
    params = (
        "@src_db sysname = NULL,\n"
        "    @src_schema sysname = NULL,\n"
        "    @ssd_timeframe_years int = NULL,\n"
        "    @ssd_sub1_range_years int = NULL,\n"
        "    @today_date date = NULL,\n"
        "    @today_dt datetime = NULL,\n"
        "    @ssd_window_start date = NULL,\n"
        "    @ssd_window_end date = NULL,\n"
        "    @CaseloadLastSept30th date = NULL,\n"
        "    @CaseloadTimeframeStartDate date = NULL\n"
    )

    defaults = (
        "    -- normalise defaults if not provided\n"
        "    IF @src_db IS NULL SET @src_db = DB_NAME();\n"
        "    IF @src_schema IS NULL SET @src_schema = SCHEMA_NAME();\n"
        "    IF @ssd_timeframe_years IS NULL SET @ssd_timeframe_years = 6;\n"
        "    IF @ssd_sub1_range_years IS NULL SET @ssd_sub1_range_years = 1;\n"
        "    IF @today_date IS NULL SET @today_date = CONVERT(date, GETDATE());\n"
        "    IF @today_dt   IS NULL SET @today_dt   = CONVERT(datetime, @today_date);\n"
        "    IF @ssd_window_end   IS NULL SET @ssd_window_end   = @today_date;\n"
        "    IF @ssd_window_start IS NULL SET @ssd_window_start = DATEADD(year, -@ssd_timeframe_years, @ssd_window_end);\n"
        "    IF @CaseloadLastSept30th IS NULL SET @CaseloadLastSept30th = CASE\n"
        "        WHEN @today_date > DATEFROMPARTS(YEAR(@today_date), 9, 30) THEN DATEFROMPARTS(YEAR(@today_date), 9, 30)\n"
        "        ELSE DATEFROMPARTS(YEAR(@today_date) - 1, 9, 30) END;\n"
        "    IF @CaseloadTimeframeStartDate IS NULL SET @CaseloadTimeframeStartDate = DATEADD(year, -@ssd_timeframe_years, @CaseloadLastSept30th);\n"
    )

    return f"""IF OBJECT_ID(N'{base_proc_name}', N'P') IS NULL
    EXEC(N'CREATE PROCEDURE {base_proc_name} AS BEGIN SET NOCOUNT ON; RETURN; END');
GO
CREATE OR ALTER PROCEDURE {base_proc_name}
    {params}
AS
BEGIN
    SET NOCOUNT ON;
{defaults}
    BEGIN TRY
{body_sql}
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        DECLARE @ErrMsg nvarchar(2048) = ERROR_MESSAGE();
        DECLARE @ErrSev int = ERROR_SEVERITY();
        DECLARE @ErrState int = ERROR_STATE();
        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END
GO
"""


def write_bootstrap(orchestrator_path: Path):
    procs_dir = OUTDIR / "procs"
    proc_files = sorted(procs_dir.glob("*.sql"), key=lambda p: p.name.lower())

    rel = lambda p: p.relative_to(OUTDIR)

    posix_lines = [f':r "{rel(p).as_posix()}"' for p in proc_files]
    posix_lines.append(f':r "{rel(orchestrator_path).as_posix()}"')

    windows_lines = [f':r "{str(rel(p)).replace("/", "\\\\")}"' for p in proc_files]
    windows_lines.append(f':r "{str(rel(orchestrator_path)).replace("/", "\\\\")}"')

    (OUTDIR / "00_install_all.sql").write_text("\n".join(posix_lines) + "\n", encoding="utf-8")
    (OUTDIR / "00_install_all_windows.sql").write_text("\n".join(windows_lines) + "\n", encoding="utf-8")

def main():
    INPUT = resolve_input()
    text = INPUT.read_text(encoding="utf-8", errors="ignore")

    if OUTDIR.exists(): shutil.rmtree(OUTDIR)
    (OUTDIR / "procs").mkdir(parents=True)

    # generate per table procs
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

    # orchestrator, declares vars and passes them to each proc
    lines = []
    lines.append("-- Master deploy runner for SSD table procs")
    lines.append("SET NOCOUNT ON;")
    lines.append("SET XACT_ABORT ON;")
    lines.append("")
    lines.append("-- shared variables declared once and passed to every proc")
    lines.append("DECLARE @src_db     sysname = N'HDM';")
    lines.append("DECLARE @src_schema sysname = N'';    -- empty uses caller default schema")
    lines.append("")
    lines.append("DECLARE @ssd_timeframe_years INT = 6;")
    lines.append("DECLARE @ssd_sub1_range_years INT = 1;")
    lines.append("")
    lines.append("DECLARE @today_date  date     = CONVERT(date, GETDATE());")
    lines.append("DECLARE @today_dt    datetime = CONVERT(datetime, @today_date);")
    lines.append("")
    lines.append("DECLARE @ssd_window_end   date = @today_date;")
    lines.append("DECLARE @ssd_window_start date = DATEADD(year, -@ssd_timeframe_years, @ssd_window_end);")
    lines.append("")
    lines.append("DECLARE @CaseloadLastSept30th date =")
    lines.append("    CASE WHEN @today_date > DATEFROMPARTS(YEAR(@today_date), 9, 30)")
    lines.append("         THEN DATEFROMPARTS(YEAR(@today_date), 9, 30)")
    lines.append("         ELSE DATEFROMPARTS(YEAR(@today_date) - 1, 9, 30) END;")
    lines.append("DECLARE @CaseloadTimeframeStartDate date = DATEADD(year, -@ssd_timeframe_years, @CaseloadLastSept30th);")
    lines.append("")
    lines.append("BEGIN TRY")
    lines.append("    BEGIN TRANSACTION;")
    lines.append("    DECLARE @schema_name sysname = NULLIF(@src_schema, N'');")
    lines.append("    DECLARE @proc nvarchar(512);")
    lines.append("")

    def exec_block(base_proc: str) -> list[str]:
        b = []
        b.append(f"    -- {base_proc}")
        b.append(f"    IF @schema_name IS NULL")
        b.append(f"        SET @proc = N'{base_proc}_custom';")
        b.append(f"    ELSE")
        b.append(f"        SET @proc = QUOTENAME(@schema_name) + N'.{base_proc}_custom';")
        b.append(f"")
        b.append(f"    IF OBJECT_ID(@proc, N'P') IS NOT NULL")
        b.append(f"    BEGIN")
        b.append(f"        EXEC @proc")
        b.append(f"             @src_db=@src_db, @src_schema=@src_schema,")
        b.append(f"             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,")
        b.append(f"             @today_date=@today_date, @today_dt=@today_dt,")
        b.append(f"             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,")
        b.append(f"             @CaseloadLastSept30th=@CaseloadLastSept30th,")
        b.append(f"             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;")
        b.append(f"    END")
        b.append(f"    ELSE")
        b.append(f"    BEGIN")
        b.append(f"        IF @schema_name IS NULL SET @proc = N'{base_proc}';")
        b.append(f"        ELSE              SET @proc = QUOTENAME(@schema_name) + N'.{base_proc}';")
        b.append(f"        EXEC @proc")
        b.append(f"             @src_db=@src_db, @src_schema=@src_schema,")
        b.append(f"             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,")
        b.append(f"             @today_date=@today_date, @today_dt=@today_dt,")
        b.append(f"             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,")
        b.append(f"             @CaseloadLastSept30th=@CaseloadLastSept30th,")
        b.append(f"             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;")
        b.append(f"    END")
        b.append(f"")
        return b

    for base_proc in procs:
        lines.extend(exec_block(base_proc))

    lines.append("    COMMIT TRANSACTION;")
    lines.append("END TRY")
    lines.append("BEGIN CATCH")
    lines.append("    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;")
    lines.append("    THROW;")
    lines.append("END CATCH;")

    orchestrator_path = OUTDIR / "populate_ssd_data_warehouse.sql"
    orchestrator_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

    # bootstrap installers, relative includes
    write_bootstrap(orchestrator_path)

    # # zip everything under OUTDIR into ZIPOUT
    # if ZIPOUT.exists(): ZIPOUT.unlink()
    # with zipfile.ZipFile(ZIPOUT, "w", compression=zipfile.ZIP_DEFLATED) as zf:
    #     for p in OUTDIR.rglob("*"):
    #         zf.write(p, p.relative_to(OUTDIR.parent))

if __name__ == "__main__":
    if OUTDIR.exists(): shutil.rmtree(OUTDIR)
    (OUTDIR / "procs").mkdir(parents=True, exist_ok=True)
    main()
