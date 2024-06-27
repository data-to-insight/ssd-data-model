import pyodbc
import xml.etree.ElementTree as ET

# Db connection dets
server = 'your_server'      # SELECT @@servername AS ServerName;
database = 'your_database'  # SELECT DB_NAME() AS DatabaseName;
username = 'your_username'  # SELECT CURRENT_USER AS UserName;
password = 'your_password'
driver = '{ODBC Driver 17 for SQL Server}'  # ODBC API, with pyodbc

# db connect
conn = pyodbc.connect(
    f'DRIVER={driver};SERVER={server};DATABASE={database};UID={username};PWD={password}'
)
cursor = conn.cursor()

## Define/Obtain the CIN query to run
# # Opt1 - Hard code SQL query
# # Define the SQL query
# sql_query = """
# -- SQL in here
# """

# Opt2 - Obtain SQL from file
# Read the SQL query from the .sql file
sql_file_path = 'CINcensus_sqlserver.sql'
with open(sql_file_path, 'r') as file:
    sql_query = file.read()



# Execute the SQL query
cursor.execute(sql_query)
rows = cursor.fetchall()

# Initialize the XML structure
root = ET.Element("Message")

# Process the result set and build the XML structure
header = ET.SubElement(root, "Header")

# CollectionDetails
collection_details = ET.SubElement(header, "CollectionDetails")
collection = ET.SubElement(collection_details, "Collection")
collection.text = "CIN"
year = ET.SubElement(collection_details, "Year")
year.text = "2025"
reference_date = ET.SubElement(collection_details, "ReferenceDate")
reference_date.text = "2024-06-17"  # Replace with dynamic date if needed

# Source
source = ET.SubElement(header, "Source")
source_level = ET.SubElement(source, "SourceLevel")
source_level.text = "L"
lea = ET.SubElement(source, "LEA")
lea.text = "845"
software_code = ET.SubElement(source, "SoftwareCode")
software_code.text = "Local Authority"
release = ET.SubElement(source, "Release")
release.text = "ver 3.1.21"
serial_no = ET.SubElement(source, "SerialNo")
serial_no.text = "001"
date_time = ET.SubElement(source, "DateTime")
date_time.text = "2024-06-17T11:24:25"  # Replace with dynamic date if needed

# Content
content = ET.SubElement(header, "Content")
cbds_levels = ET.SubElement(content, "CBDSLevels")
cbds_level = ET.SubElement(cbds_levels, "CBDSLevel")
cbds_level.text = "Child"

# Children
children = ET.SubElement(root, "Children")

for row in rows:
    child = ET.SubElement(children, "Child")

    # ChildIdentifiers
    child_identifiers = ET.SubElement(child, "ChildIdentifiers")
    la_child_id = ET.SubElement(child_identifiers, "LAchildID")
    la_child_id.text = row.LAchildID.strip()
    upn = ET.SubElement(child_identifiers, "UPN")
    upn.text = row.UPN.strip()
    former_upn = ET.SubElement(child_identifiers, "FormerUPN")
    former_upn.text = row.FormerUPN.strip()
    upn_unknown = ET.SubElement(child_identifiers, "UPNunknown")
    upn_unknown.text = row.UPNunknown.strip()
    person_birth_date = ET.SubElement(child_identifiers, "PersonBirthDate")
    person_birth_date.text = row.PersonBirthDate.strip()
    expected_person_birth_date = ET.SubElement(child_identifiers, "ExpectedPersonBirthDate")
    expected_person_birth_date.text = row.ExpectedPersonBirthDate.strip()
    person_death_date = ET.SubElement(child_identifiers, "PersonDeathDate")
    person_death_date.text = row.PersonDeathDate.strip()
    sex = ET.SubElement(child_identifiers, "Sex")
    sex.text = row.Sex.strip()

    # ChildCharacteristics
    child_characteristics = ET.SubElement(child, "ChildCharacteristics")
    ethnicity = ET.SubElement(child_characteristics, "Ethnicity")
    ethnicity.text = row.Ethnicity.strip()
    disabilities = ET.SubElement(child_characteristics, "Disabilities")
    disability = ET.SubElement(disabilities, "Disability")
    disability.text = row.Disability.strip()

    # CINdetails
    cin_details = ET.SubElement(child, "CINdetails")
    cin_referral_date = ET.SubElement(cin_details, "CINreferralDate")
    cin_referral_date.text = row.CINreferralDate.strip()
    referral_source = ET.SubElement(cin_details, "ReferralSource")
    referral_source.text = row.ReferralSource.strip()
    primary_need_code = ET.SubElement(cin_details, "PrimaryNeedCode")
    primary_need_code.text = row.PrimaryNeedCode.strip()
    referral_nfa = ET.SubElement(cin_details, "ReferralNFA")
    referral_nfa.text = row.ReferralNFA.strip()
    cin_closure_date = ET.SubElement(cin_details, "CINclosureDate")
    cin_closure_date.text = row.CINclosureDate.strip()
    reason_for_closure = ET.SubElement(cin_details, "ReasonForClosure")
    reason_for_closure.text = row.ReasonForClosure.strip()

    # Assessments
    assessments = ET.SubElement(cin_details, "Assessments")
    assessment_actual_start_date = ET.SubElement(assessments, "AssessmentActualStartDate")
    assessment_actual_start_date.text = row.AssessmentActualStartDate.strip()
    assessment_internal_review_date = ET.SubElement(assessments, "AssessmentInternalReviewDate")
    assessment_internal_review_date.text = row.AssessmentInternalReviewDate.strip()
    assessment_authorisation_date = ET.SubElement(assessments, "AssessmentAuthorisationDate")
    assessment_authorisation_date.text = row.AssessmentAuthorisationDate.strip()

    # FactorsIdentifiedAtAssessment
    factors_identified = ET.SubElement(assessments, "FactorsIdentifiedAtAssessment")
    for factor in row.AssessmentFactors.split(','):
        assessment_factors = ET.SubElement(factors_identified, "AssessmentFactors")
        assessment_factors.text = factor.strip()

    # CINPlanDates
    cin_plan_dates = ET.SubElement(cin_details, "CINPlanDates")
    cin_plan_start_date = ET.SubElement(cin_plan_dates, "CINPlanStartDate")
    cin_plan_start_date.text = row.CINPlanStartDate.strip()
    cin_plan_end_date = ET.SubElement(cin_plan_dates, "CINPlanEndDate")
    cin_plan_end_date.text = row.CINPlanEndDate.strip()

    # ChildProtectionPlans
    child_protection_plans = ET.SubElement(cin_details, "ChildProtectionPlans")
    cpp_start_date = ET.SubElement(child_protection_plans, "CPPstartDate")
    cpp_start_date.text = row.CPPstartDate.strip()
    cpp_end_date = ET.SubElement(child_protection_plans, "CPPendDate")
    cpp_end_date.text = row.CPPendDate.strip()
    initial_category_of_abuse = ET.SubElement(child_protection_plans, "InitialCategoryOfAbuse")
    initial_category_of_abuse.text = row.InitialCategoryOfAbuse.strip()
    latest_category_of_abuse = ET.SubElement(child_protection_plans, "LatestCategoryOfAbuse")
    latest_category_of_abuse.text = row.LatestCategoryOfAbuse.strip()
    number_of_previous_cpp = ET.SubElement(child_protection_plans, "NumberOfPreviousCPP")
    number_of_previous_cpp.text = row.NumberOfPreviousCPP.strip()

    # CPPreviews
    cp_previews = ET.SubElement(child_protection_plans, "CPPreviews")
    cp_preview_date = ET.SubElement(cp_previews, "CPPreviewDate")
    cp_preview_date.text = row.CPPreviewDate.strip()

    # Section47
    section47 = ET.SubElement(cin_details, "Section47")
    s47_actual_start_date = ET.SubElement(section47, "S47ActualStartDate")
    s47_actual_start_date.text = row.S47ActualStartDate.strip()
    initial_cpc_target = ET.SubElement(section47, "InitialCPCtarget")
    initial_cpc_target.text = row.InitialCPCtarget.strip()
    date_of_initial_cpc = ET.SubElement(section47, "DateOfInitialCPC")
    date_of_initial_cpc.text = row.DateOfInitialCPC.strip()
    icpc_not_required = ET.SubElement(section47, "ICPCnotRequired")
    icpc_not_required.text = row.ICPCnotRequired.strip()

# Convert the XML structure to a string
xml_string = ET.tostring(root, encoding='utf-8', method='xml')

# Save the XML string to a file
with open('output.xml', 'wb') as f:
    f.write(xml_string)

# Close the database connection
conn.close()
