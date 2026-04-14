-- META-CONTAINER: {"type": "table", "name": "ssd_pre_proceedings"}
-- =============================================================================
-- Description:
-- Author:
-- Version: 0.1
-- Status: [D]ev
-- Remarks: [EA_API_PRIORITY_TABLE]
-- Dependencies:
-- - ssd_person
--
-- =============================================================================

IF OBJECT_ID('tempdb..#ssd_pre_proceedings', 'U') IS NOT NULL DROP TABLE #ssd_pre_proceedings;

IF OBJECT_ID('ssd_pre_proceedings', 'U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_pre_proceedings)
        TRUNCATE TABLE ssd_pre_proceedings;
END
ELSE
BEGIN
    CREATE TABLE ssd_pre_proceedings (
        prep_table_id                         NVARCHAR(48)  NOT NULL PRIMARY KEY,
        prep_person_id                        NVARCHAR(48)  NULL,
        prep_plo_family_id                    NVARCHAR(48)  NULL,
        prep_pre_pro_decision_date            DATETIME      NULL,
        prep_initial_pre_pro_meeting_date     DATETIME      NULL,
        prep_pre_pro_outcome                  NVARCHAR(100) NULL,
        prep_agree_stepdown_issue_date        DATETIME      NULL,
        prep_cp_plans_referral_period         INT           NULL,
        prep_legal_gateway_outcome            NVARCHAR(100) NULL,
        prep_prev_pre_proc_child              INT           NULL,
        prep_prev_care_proc_child             INT           NULL,
        prep_pre_pro_letter_date              DATETIME      NULL,
        prep_care_pro_letter_date             DATETIME      NULL,
        prep_pre_pro_meetings_num             INT           NULL,
        prep_pre_pro_parents_legal_rep        NCHAR(1)      NULL,
        prep_parents_legal_rep_point_of_issue NCHAR(2)      NULL,
        prep_court_reference                  NVARCHAR(48)  NULL,
        prep_care_proc_court_hearings         INT           NULL,
        prep_care_proc_short_notice           NCHAR(1)      NULL,
        prep_proc_short_notice_reason         NVARCHAR(100) NULL,
        prep_la_inital_plan_approved          NCHAR(1)      NULL,
        prep_la_initial_care_plan             NVARCHAR(100) NULL,
        prep_la_final_plan_approved           NCHAR(1)      NULL,
        prep_la_final_care_plan               NVARCHAR(100) NULL
    );
END

TRUNCATE TABLE ssd_pre_proceedings;

INSERT INTO ssd_pre_proceedings (
    prep_table_id,
    prep_person_id,
    prep_plo_family_id,
    prep_pre_pro_decision_date,
    prep_initial_pre_pro_meeting_date,
    prep_pre_pro_outcome,
    prep_agree_stepdown_issue_date,
    prep_cp_plans_referral_period,
    prep_legal_gateway_outcome,
    prep_prev_pre_proc_child,
    prep_prev_care_proc_child,
    prep_pre_pro_letter_date,
    prep_care_pro_letter_date,
    prep_pre_pro_meetings_num,
    prep_pre_pro_parents_legal_rep,
    prep_parents_legal_rep_point_of_issue,
    prep_court_reference,
    prep_care_proc_court_hearings,
    prep_care_proc_short_notice,
    prep_proc_short_notice_reason,
    prep_la_inital_plan_approved,
    prep_la_initial_care_plan,
    prep_la_final_plan_approved,
    prep_la_final_care_plan
)
SELECT
    NULL AS prep_table_id,
    NULL AS prep_person_id,
    NULL AS prep_plo_family_id,
    NULL AS prep_pre_pro_decision_date,
    NULL AS prep_initial_pre_pro_meeting_date,
    NULL AS prep_pre_pro_outcome,
    NULL AS prep_agree_stepdown_issue_date,
    NULL AS prep_cp_plans_referral_period,
    NULL AS prep_legal_gateway_outcome,
    NULL AS prep_prev_pre_proc_child,
    NULL AS prep_prev_care_proc_child,
    NULL AS prep_pre_pro_letter_date,
    NULL AS prep_care_pro_letter_date,
    NULL AS prep_pre_pro_meetings_num,
    NULL AS prep_pre_pro_parents_legal_rep,
    NULL AS prep_parents_legal_rep_point_of_issue,
    NULL AS prep_court_reference,
    NULL AS prep_care_proc_court_hearings,
    NULL AS prep_care_proc_short_notice,
    NULL AS prep_proc_short_notice_reason,
    NULL AS prep_la_inital_plan_approved,
    NULL AS prep_la_initial_care_plan,
    NULL AS prep_la_final_plan_approved,
    NULL AS prep_la_final_care_plan
FROM ssd_person sp
WHERE 1 = 0;