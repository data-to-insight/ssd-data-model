from openpyxl import load_workbook
from openpyxl.worksheet.worksheet import Worksheet
from openpyxl.worksheet.table import Table
from openpyxl.utils.cell import cols_from_range, range_boundaries


def _read_table(sheet: Worksheet, table: Table):
    table_length = range_boundaries(table.ref)[3] - 1

    data = [{} for x in range(0, table_length)]

    cols = cols_from_range(table.ref)
    for c in cols:
        header = sheet[c[0]].value
        for row in range(0, table_length):
            value = sheet[c[row+1]].value
            if value is not None:
                entry = data[row]
                entry[header] = value.strip()

    return data


def _read_list(sheet: Worksheet, table: Table):
    table_length = range_boundaries(table.ref)[3] - 1
    cols = cols_from_range(table.ref)

    data = {}

    for c in cols:
        header = sheet[c[0]].value
        header = header.strip()
        values = [sheet[c[ix+1]].value for ix in range(0, table_length)]
        values = [v.strip() for v in values if v is not None]
        data[header] = values

    return data


def read_excel(filename, as_list=None):
    """
    Opens a workbook and finds all tables in the workbook. Parses these and
    returns as a dictionary of the tablenames.

    e.g. {"Table1": [{name: 1}, {name: 2}, {name: 3}]}

    Normally tables are parsed so that each row creates a new object with
    each property named after the column heading.
    However, it is possibly to read a table where each column is returned
    as a list, useful for 'category' tables. To do
    so, specify as_list as a sequence containing the table name.

    """
    if as_list is None:
        as_list = set()

    wb = load_workbook(filename=filename)
    tables = {}
    for sheet_name in wb.sheetnames:
        sheet = wb[sheet_name]
        for table_name in sheet.tables:
            table = sheet.tables[table_name]
            if table_name in as_list:
                tables[table_name] = _read_list(sheet, table)
            else:
                tables[table_name] = _read_table(sheet, table)

    return tables
