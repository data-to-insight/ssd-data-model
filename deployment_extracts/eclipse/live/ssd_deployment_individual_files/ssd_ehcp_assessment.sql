-- =============================================================================
-- META-ELEMENT: {"type": "drop_table"}
-- Note: uncomment only if dropping to apply new structural update(s)
-- =============================================================================
-- DROP TABLE IF EXISTS ssd_ehcp_assessment;

-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE IF NOT EXISTS ssd_ehcp_assessment (
    ehca_ehcp_assessment_id           VARCHAR(48) PRIMARY KEY,  -- metadata={"item_ref":"EHCA001A"}
    ehca_ehcp_request_id              VARCHAR(48),              -- metadata={"item_ref":"EHCA002A"}
    ehca_ehcp_assessment_outcome_date TIMESTAMP,                -- metadata={"item_ref":"EHCA003A"}
    ehca_ehcp_assessment_outcome      VARCHAR(100),             -- metadata={"item_ref":"EHCA004A"}
    ehca_ehcp_assessment_exceptions   VARCHAR(100)              -- metadata={"item_ref":"EHCA005A"}
);

TRUNCATE TABLE ssd_ehcp_assessment;

INSERT INTO ssd_ehcp_assessment (
    ehca_ehcp_assessment_id,
    ehca_ehcp_request_id,
    ehca_ehcp_assessment_outcome_date,
    ehca_ehcp_assessment_outcome,
    ehca_ehcp_assessment_exceptions
)
SELECT
    /* currently PLACEHOLDER_DATA pending further development 
       EHCP assessment record unique ID from system or auto generated as part of export. 
       This module collects information on the decision to issue a plan. Where a decision has been made to issue a plan, 
       the detail about the placement named on the EHC plan should be recorded in Module 4. It is possible that multiple 
       assessments may be recorded for a single person. For example, if it was decided not to issue a plan previously and 
       a new assessment has been agreed following a new request.
       If a child or young person transfers into the local authority’s area during the assessment process before an EHC plan 
       has been issued there is no right of transfer of decisions made by the originating local authority. Under good practice 
       local authorities may decide to share information but the importing local authority must make its own decisions on 
       whether to assess and whether to issue a plan.
       Where a person with an existing EHC plan transfers into the local authority’s area the assessment should be recorded as 
       historical by the importing local authority, even if the EHC plan start date is within the collection year. */
    NULL AS "ehca_ehcp_assessment_id",           --metadata={"item_ref":"EHCA001A"}
    /* currently PLACEHOLDER_DATA pending further development 
       EHCP request record unique ID from system or auto generated as part of export. */
    NULL AS "ehca_ehcp_request_id",              --metadata={"item_ref":"EHCA002A"}
    /* currently PLACEHOLDER_DATA pending further development 
       The assessment outcome date is required where EAM004A is equal to Y or N, either record: 
       - Date on which EHC plan was issued, or 
       - Date on which person was notified of decision not to issue a plan 
       If a decision to issue has been made but no plan has been issued, please leave blank. */
    NULL AS "ehca_ehcp_assessment_outcome_date", --metadata={"item_ref":"EHCA003A"}
    /* currently PLACEHOLDER_DATA pending further development 
       Assessment outcome  decision to issue EHC plan: 
       Y  It was decided an EHC plan would be issued 
       N  It was decided an EHC plan would not be issued 
       A  Decision has not yet been made 
       W  Request withdrawn or ceased before decision whether to issue was made 
       H  Historical  Decision to issue was made before the latest collection period 
       If a local authority decides not to issue an EHC plan and this decision is subsequently changed by the local authority 
       for any reason the original assessment outcome and assessment outcome date should not be changed. If the change follows 
       from mediation or tribunal the appropriate mediation and tribunal indicators should be selected for the assessment. 
       W may include where the person moves out of the local authority area, leaves education or training or if the child or 
       young person dies. 
       Where A or W is selected, no further information is required in this or subsequent modules. The 20 week timeliness 
       measure will not apply in cases where a plan has not yet been issued.
       For an active plan, where the decision to issue was made before the latest collection period H Historical information 
       is still required on the plan itself. */
    NULL AS "ehca_ehcp_assessment_outcome",      --metadata={"item_ref":"EHCA004A"}
    /* currently PLACEHOLDER_DATA pending further development 
       Assessment 20 week time limit exceptions apply? 
       1  Yes, exceptions apply 
       0  No, exceptions do not apply */
    NULL AS "ehca_ehcp_assessment_exceptions";   --metadata={"item_ref":"EHCA005A"}
