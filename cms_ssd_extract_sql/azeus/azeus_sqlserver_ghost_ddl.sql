
CREATE TABLE ADOPTER_APP (
    ADOPTER_APP_ID INT PRIMARY KEY,
    ADOPT_ORD_DT DATETIME,
    APP_END_DT DATETIME,
    APP_END_DT_2 DATETIME,
    APP_OUTCOME VARCHAR(255),
    APP_REF_NO VARCHAR(255),
    APP_START_DT DATETIME,
    APP_START_DT_2 DATETIME,
    ASS_WRKR VARCHAR(255),
    COMPLETE_REF_IND CHAR(1),
    CREATED_BY_POST VARCHAR(255),
    CREATED_BY_USR VARCHAR(255),
    CREATE_DT DATETIME,
    DECISION_STATUS VARCHAR(255),
    FORM_ID VARCHAR(255),
    LST_UPD_BY_POST VARCHAR(255),
    LST_UPD_BY_USR VARCHAR(255),
    LST_UPD_DT DATETIME,
    MED_RCV_DET DATETIME,
    MED_SENT_DET DATETIME,
    MTG_DT DATETIME,
    OUTCOME_RCV_DT DATETIME,
    OUTCOME_SENT_DT DATETIME,
    PANEL_DT DATETIME,
    PANEL_MATCH_DT DATETIME,
    PAR_WRKR VARCHAR(255),
    PLCMT_DT DATETIME,
    REFER_DT DATETIME,
    REF_SENT_DT DATETIME,
    REL_ENQ_REF_NO VARCHAR(255),
    REM TEXT,
    RESP_WRKR VARCHAR(255),
    RETURN_OUTCOME VARCHAR(255),
    REVIEW_DT DATETIME,
    SIGN_DT DATETIME,
    SIGN_DT_2 DATETIME,
    STAGE VARCHAR(255),
    SVC_USR_REF_NO_1 VARCHAR(255),
    SVC_USR_REF_NO_2 VARCHAR(255),
    S_REC_ID INT
);

CREATE TABLE ADOPTER_APP_ACT (
    ADOPTER_APP_ACT_ID INT PRIMARY KEY,
    ADOPTER_APP_ID INT,
    ACT_CD VARCHAR(255),
    ACT_DET TEXT,
    ACT_DT DATETIME,
    APPR_BY_POST VARCHAR(255),
    APPR_BY_USR VARCHAR(255),
    APPR_DT DATETIME,
    APP_ACT_REF_NO VARCHAR(255),
    CREATED_BY_POST VARCHAR(255),
    CREATED_BY_USR VARCHAR(255),
    CREATE_DT DATETIME,
    LST_UPD_BY_POST VARCHAR(255),
    LST_UPD_BY_USR VARCHAR(255),
    LST_UPD_DT DATETIME,
    REM TEXT,
    RESP_WRKR VARCHAR(255),
    RESP_WRKR_POST_ID VARCHAR(255),
    RETD_BY_POST VARCHAR(255),
    RETD_BY_USR VARCHAR(255),
    RETURN_DT DATETIME,
    STATUS VARCHAR(255),
    SUB_BY_POST VARCHAR(255),
    SUB_BY_USR VARCHAR(255),
    SUB_DT DATETIME,
    SUB_TO VARCHAR(255),
    SUP_REM TEXT,
    S_REC_ID INT,

    FOREIGN KEY (ADOPTER_APP_ID) REFERENCES ADOPTER_APP(ADOPTER_APP_ID)
);


CREATE TABLE ASMT (
    ACS_TO_RECS_DT DATETIME,
    ACS_TO_RECS_IND NVARCHAR(255),
    ACS_TO_RECS_NOT_REAS NVARCHAR(255),
    ACTL_END_DT DATETIME,
    ACTL_RVW_DT DATETIME,
    ACTL_START_DT DATETIME,
    ACT_DAILY_LVNG_ADJ_FACS NVARCHAR(255),
    ACT_DAILY_LVNG_FACS NVARCHAR(255),
    APP_ID INT, -- Assuming ID fields are integers
    ASMT_ABOUT_ME_SKETCH_ID NVARCHAR(255),
    ASMT_APPROVED_BY NVARCHAR(255),
    ASMT_APPROVED_BY_POST NVARCHAR(255),
    ASMT_APPROVED_DT DATETIME,
    ASMT_FORM NVARCHAR(255),
    ASMT_FORM_PORTAL NVARCHAR(255),
    ASMT_ID INT PRIMARY KEY, -- Assuming ASMT_ID is the primary key
    ASMT_REAS NVARCHAR(255),
    ASMT_REF_NO NVARCHAR(255),
    ASMT_RES NVARCHAR(255),
    ASMT_RETURN_BY NVARCHAR(255),
    ASMT_RETURN_BY_POST NVARCHAR(255),
    ASMT_RETURN_DT DATETIME,
    ASMT_SKETCH_ID NVARCHAR(255),
    ASMT_STATUS NVARCHAR(255),
    ASMT_SUBMIT_TO_POST NVARCHAR(255),
    ASMT_SUBMIT_TO_SYS_POST NVARCHAR(255),
    ASMT_SUB_BY_CASEWORKER NVARCHAR(255),
    ASMT_SUB_BY_POST_CASEWORKE NVARCHAR(255),
    ASMT_SUB_BY_SVC_USR NVARCHAR(255),
    ASMT_SUB_DT_CASEWORKER DATETIME,
    ASMT_SUB_DT_SVC_USR DATETIME,
    ASMT_WITHDRAWN_BY NVARCHAR(255),
    ASMT_WITHDRAWN_BY_POST NVARCHAR(255),
    ASMT_WITHDRAWN_DT DATETIME,
    ASMT_WORKING_SKETCH_ID NVARCHAR(255),
    ASSESSOR NVARCHAR(255),
    ASSESSOR_REM NVARCHAR(255),
    ASSESSOR_SYS_POST_ID NVARCHAR(255),
    BUDGET_SVC_USR_FREQ NVARCHAR(255),
    BUDGET_WKR_FREQ NVARCHAR(255),
    CASCADE_TO_DPA NVARCHAR(255),
    CASEWORKER_RVW_DT DATETIME,
    CASE_ID NVARCHAR(255),
    CHILD_CAT_NEED NVARCHAR(255),
    COMPLAINTS_PROC_DT DATETIME,
    COMPLAINTS_PROC_IND NVARCHAR(255),
    COMPLAINTS_PROC_NOT_REAS NVARCHAR(255),
    COMPLETED_BY NVARCHAR(255),
    COMPLETE_IND NVARCHAR(255),
    COMPL_DT DATETIME,
    CONTRIBUTION_SCHD NVARCHAR(255),
    COPIED_IND NVARCHAR(255),
    CREATED_BY_POST NVARCHAR(255),
    CREATED_BY_USR NVARCHAR(255),
    CREATE_DT DATETIME,
    DEF_PAY_APP_ID NVARCHAR(255),
    FACS_LVL NVARCHAR(255),
    FACS_LVL_BY_SVC_USR NVARCHAR(255),
    FACS_LVL_BY_WKR NVARCHAR(255),
    FAM_AND_CARERS_ADJ_FACS NVARCHAR(255),
    FAM_AND_CARERS_FACS NVARCHAR(255),
    FULLY_PAID NVARCHAR(255),
    FUP_AXN NVARCHAR(255),
    FUP_AXN_REM NVARCHAR(255),
    INDEX_DT DATETIME,
    INDICATIVE_BUDGET NVARCHAR(255),
    INDICATIVE_BUDGET_FREQ NVARCHAR(255),
    INDICATIVE_BUDGET_SVC_USR NVARCHAR(255),
    INDICATIVE_BUDGET_WKR NVARCHAR(255),
    INIT_CONT_ID NVARCHAR(255),
    INTERPERS_REL_ADJ_FACS NVARCHAR(255),
    INTERPERS_REL_FACS NVARCHAR(255),
    IS_FULL_COST NVARCHAR(255),
    IS_VIEWABLE_TO_SVC_USR NVARCHAR(255),
    LAST_CALC_DT DATETIME,
    LOC NVARCHAR(255),
    LST_UPD_BY_POST NVARCHAR(255),
    LST_UPD_BY_USR NVARCHAR(255),
    LST_UPD_DT DATETIME,
    MOBILE_CHECKED_OUT_BY NVARCHAR(255),
    OTH_REL_INFO_DET NVARCHAR(255),
    OTH_REL_INFO_DT DATETIME,
    OTH_REL_INFO_IND NVARCHAR(255),
    PAID_UNTIL_DT DATETIME,
    PHYS_WELLBEING_ADJ_FACS NVARCHAR(255),
    PHYS_WELLBEING_FACS NVARCHAR(255),
    PLANNED_END_DT DATETIME,
    PLANNED_START_DT DATETIME,
    PLANNED_START_DT_REAS NVARCHAR(255),
    PRIMARY_CLIENT_SUBTYPE NVARCHAR(255),
    PRIMARY_CLIENT_TYPE NVARCHAR(255),
    PSYCH_WELLBEING_ADJ_FACS NVARCHAR(255),
    PSYCH_WELLBEING_FACS NVARCHAR(255),
    REAS_FOR_AXN_TAKEN NVARCHAR(255),
    REAS_FOR_DELAY NVARCHAR(255),
    REFERRED_AGNC NVARCHAR(255),
    REF_ID NVARCHAR(255),
    RESTART_DT DATETIME,
    SOC_CARE_ADJ_FACS NVARCHAR(255),
    SOC_CARE_FACS NVARCHAR(255),
    SUP_REM NVARCHAR(255),
    SVC_USR_REF_NO NVARCHAR(255),
    SVC_USR_SHARES NVARCHAR(255),
    SVC_USR_SHR_FREQ NVARCHAR(255),
    SVC_USR_SHR_SVC_USR NVARCHAR(255),
    SVC_USR_SHR_SVC_USR_FREQ NVARCHAR(255),
    SVC_USR_SHR_WKR NVARCHAR(255),
    SVC_USR_SHR_WKR_FREQ NVARCHAR(255),
    S_FIN_ASMT_REC_ID NVARCHAR(255),
    S_FIN_ASMT_REC_ID_CUT NVARCHAR(255),
    S_REC_ID NVARCHAR(255),
    USR_CONTRIB NVARCHAR(255),
    USR_CONTRIB_ADJ NVARCHAR(255),
    USR_CONTRIB_DIR_PAY NVARCHAR(255),
    USR_CONTRIB_START_DT DATETIME,
    VALID_FOR_DPA NVARCHAR(255),
    VENUE NVARCHAR(255)
    );

CREATE TABLE CASEWORKER (
    CASEWORKER_ID INT PRIMARY KEY,
    CASEWORKER_SYS_POST_ID NVARCHAR(255),
    CASE_ID NVARCHAR(255),
    CASE_WKR_IND NVARCHAR(255),
    CREATED_BY_POST NVARCHAR(255),
    CREATED_BY_USR NVARCHAR(255),
    CREATE_DT DATETIME,
    DEACTIVATION_TYPE NVARCHAR(255),
    DESIGNATION NVARCHAR(255),
    EFFECTIVE_END_DT DATETIME,
    EFFECTIVE_START_DT DATETIME,
    EMP_ID NVARCHAR(255),
    END_REAS NVARCHAR(255),
    KEY_WKR_IND NVARCHAR(255),
    KEY_WKR_TRANS_REAS NVARCHAR(255),
    LST_UPD_BY_POST NVARCHAR(255),
    LST_UPD_BY_USR NVARCHAR(255),
    LST_UPD_DT DATETIME,
    ROLE NVARCHAR(255),
    TEAM_ID NVARCHAR(255)
);

CREATE TABLE CASE_ACT (
    ACT_METHOD NVARCHAR(255),
    ACT_TIME DATETIME, 
    APPR_BY_POST NVARCHAR(255),
    APPR_BY_USR NVARCHAR(255),
    APPR_DT DATETIME, 
    CASE_ACT_CD NVARCHAR(255),
    CASE_ACT_CD_OTH NVARCHAR(255),
    CASE_ACT_DET NVARCHAR(255),
    CASE_ACT_DT DATETIME, 
    CASE_ACT_ID INT PRIMARY KEY, -- Specified as PK 
    CASE_ACT_REF_NO NVARCHAR(255),
    CASE_ACT_SKETCH_ID NVARCHAR(255),
    CASE_ID NVARCHAR(255), -- Assuming this could be a FK to another table
    CREATED_BY_POST NVARCHAR(255),
    CREATED_BY_USR NVARCHAR(255),
    CREATE_DT DATETIME, 
    INDEX_DT DATETIME, 
    INIT_CONT_ID NVARCHAR(255),
    INTERV_END_DT DATETIME, 
    LST_UPD_BY_POST NVARCHAR(255),
    LST_UPD_BY_USR NVARCHAR(255),
    LST_UPD_DT DATETIME, 
    MOBILE_CHECKED_OUT_BY NVARCHAR(255),
    RECOM_BY_POST NVARCHAR(255),
    RECOM_BY_USR NVARCHAR(255),
    RECOM_DT DATETIME, 
    RESP_WKR NVARCHAR(255),
    STATUS NVARCHAR(255),
    SUB_TO NVARCHAR(255),
    SUP_REM NVARCHAR(255),
    SVC_USR_REF_NO NVARCHAR(255),
    S_REC_ID NVARCHAR(255),
    VENUE NVARCHAR(255),
    WITHDRAWN_BY_POST NVARCHAR(255),
    WITHDRAWN_BY_USR NVARCHAR(255),
    WITHDRAWN_DT DATETIME 
);
#

CREATE TABLE CASE_EPISODE (
    CASE_CLOSURE_ID NVARCHAR(255), -- Assuming text type; change if needed
    CASE_EPISODE_ID INT PRIMARY KEY, -- Specified as PK in your file
    CASE_ID NVARCHAR(255), -- Assuming this could be a FK to another table
    CASE_NAT NVARCHAR(255), -- Assuming text type; change if needed
    END_DT DATETIME, -- Assuming this is a datetime
    END_REAS NVARCHAR(255), -- Assuming text type; change if needed
    REF_ID NVARCHAR(255), -- Assuming text type; change if needed
    START_DT DATETIME, -- Assuming this is a datetime
    SVC_USR_REF_NO NVARCHAR(255) -- Assuming text type; change if needed
);