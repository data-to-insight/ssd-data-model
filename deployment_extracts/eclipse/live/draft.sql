              
     /*   SELECT 
            CLA.CODE,
            CLA.NAME
            FROM(*/
             SELECT 
                   CLA.PERSONID, 
                   CLA.CODE,
                   CLA.NAME,
                   CLA.CLASSIFICATIONPATHID,
                   CLA.CLASSIFICATIONASSIGNMENTID                                      AS EPISODEID,
	               CLA.STARTDATE::DATE                                                 AS PRIMARY_CODE_STARTDATE,
                   CLA.ENDDATE::DATE                                                   AS PRIMARY_CODE_ENDDATE,
                   CLA.ENDREASON
                        
               FROM CLASSIFICATIONPERSONVIEW  CLA
               WHERE CLA.STATUS NOT IN ('DELETED')
                   AND CLA.CLASSIFICATIONPATHID = 23
                 --  AND CLA.CODE IN ('CIN_PLAN','CF','FHP')
                   AND PERSONID = 101284
                ORDER BY CLA.PERSONID   
    /*           ) CLA
	   GROUP BY CLA.CODE,
                   CLA.NAME  */               
----////////////////////////////////////////////////////////////         
 
                
WITH CIN_EPISODE AS (  ----------CIN Episodes
    SELECT 
        CINE_PERSON_ID,
        CINE_REFERRAL_DATE,
        MIN(CINE_CIN_PRIMARY_NEED_RANK) AS CINE_CIN_PRIMARY_NEED_RANK,
        CINE_CLOSE_DATE,
        MAX(CINE_CLOSE_REASON)          AS CINE_CLOSE_REASON,
        MIN(CINE_REFERRAL_ID)           AS CINE_REFERRAL_ID
    FROM (    
        SELECT 
            CLA.PERSONID                                                  AS CINE_PERSON_ID,
            MIN(CLA.PRIMARY_CODE_STARTDATE)                               AS CINE_REFERRAL_DATE,
            MIN(CINE_CIN_PRIMARY_NEED_RANK)                               AS CINE_CIN_PRIMARY_NEED_RANK,
            CASE
	    	    WHEN BOOL_AND(PRIMARY_CODE_ENDDATE IS NOT NULL) IS FALSE
	    	    THEN NULL
	            ELSE MAX(PRIMARY_CODE_ENDDATE)
	        END                                                           AS CINE_CLOSE_DATE,
	        MAX(ENDREASON)                                                AS CINE_CLOSE_REASON,
	        MAX(EPISODE_ID)                                               AS CINE_REFERRAL_ID
	        
	        
	        
WITH PRIMARY_CODE_ALL AS (
            SELECT  
                *,
                SUM(NEXT_START_FLAG) OVER (PARTITION BY PERSONID ORDER BY PERSONID, PRIMARY_CODE_STARTDATE) AS EPISODE
	           -- CASE WHEN NEXT_START_FLAG = 1
	            --     THEN EPISODEID
	           -- END                                                                                                                  AS EPISODE_ID     
           FROM (
               SELECT 
                   CLA.PERSONID, 
                   CLA.CLASSIFICATIONASSIGNMENTID                                      AS EPISODEID,
	               CASE WHEN CLA.NAME = 'Abuse or neglect'                THEN 'N1'
                        WHEN CLA.NAME = 'Child''s disability'             THEN 'N2'
                        WHEN CLA.NAME = 'Parental illness/disability'     THEN 'N3'
                        WHEN CLA.NAME = 'Family in acute stress'          THEN 'N4'
                        WHEN CLA.NAME = 'Family dysfunction'              THEN 'N5'
                        WHEN CLA.NAME = 'Socially unacceptable behaviour' THEN 'N6'
                        WHEN CLA.NAME = 'Low income'                      THEN 'N7'
                        WHEN CLA.NAME = 'Absent parenting'                THEN 'N8'
                        WHEN CLA.NAME = 'Cases other than child in need'  THEN 'N9'
                        WHEN CLA.NAME = 'Not stated'                      THEN 'N0'
                   END                                                                 AS PRIMARY_NEED,
                   CLA.STARTDATE::DATE                                                 AS PRIMARY_CODE_STARTDATE,
                   CLA.ENDDATE::DATE                                                   AS PRIMARY_CODE_ENDDATE,
                   CLA.ENDREASON,
                   CASE WHEN CLA.STARTDATE >= LAG(CLA.STARTDATE ) OVER (PARTITION BY CLA.PERSONID ORDER BY CLA.STARTDATE, CLA.ENDDATE NULLS LAST) 
                           AND CLA.STARTDATE <= COALESCE(LAG(CLA.ENDDATE) OVER (PARTITION BY CLA.PERSONID ORDER BY CLA.STARTDATE, CLA.ENDDATE NULLS LAST), CURRENT_DATE)+ INTERVAL '1 day' 
                        THEN 0
                        ELSE 1
                   END                                                                 AS NEXT_START_FLAG     
               FROM CLASSIFICATIONPERSONVIEW  CLA
               WHERE CLA.STATUS NOT IN ('DELETED')
                   AND CLA.CLASSIFICATIONPATHID = 23
                   AND PERSONID = 101284
               ORDER BY CLA.PERSONID,
	                    CLA.ENDDATE:: DATE DESC NULLS FIRST,
	                    CLA.STARTDATE:: DATE DESC 
	             ) CLA
	       
	          )
	          
, PRIMARY_CODE_GROUP AS (
SELECT
            CLA.*,
            PC_FIRST.PRIMARY_NEED AS FIRST_PRIMARY_NEED,
            
	        PC_FIRST.EPISODEID AS FIRST_EPISODEID,
	        PC_LAST.EPISODEID AS LAST_EPISODEID,
	        PC_LAST.ENDREASON AS LAST_ENDREASON
FROM PRIMARY_CODE_ALL CLA

LEFT JOIN LATERAL (  
        SELECT *  
        FROM PRIMARY_CODE_ALL PC_FIRST
        WHERE CLA.PERSONID = PC_FIRST.PERSONID
           AND CLA.EPISODE = PC_FIRST.EPISODE
       ORDER BY PC_FIRST.PRIMARY_CODE_STARTDATE 
       FETCH FIRST 1 ROW ONLY
           ) PC_FIRST  ON TRUE 
LEFT JOIN LATERAL (  
        SELECT *  
        FROM PRIMARY_CODE_ALL PC_LAST
        WHERE CLA.PERSONID = PC_LAST.PERSONID
           AND CLA.EPISODE = PC_LAST.EPISODE
       ORDER BY PC_LAST.PRIMARY_CODE_STARTDATE DESC
       FETCH FIRST 1 ROW ONLY
           ) PC_LAST  ON TRUE            
--GROUP BY CLA.PERSONID, CLA.EPISODE 

)	          
	          
, PRIMARYNEED_CODE_EPISODES AS (	

SELECT 
            PERSONID                                                  AS PERSONID,
            MIN(PRIMARY_CODE_STARTDATE)                               AS PRIMARY_CODE_STARTDATE,
            LAST_ENDREASON                               AS PRIMARY_CODE_ENDREASON ,
            FIRST_PRIMARY_NEED AS PRIMARY_NEED,
            CASE
	    	    WHEN BOOL_AND(PRIMARY_CODE_ENDDATE IS NOT NULL) IS FALSE
	    	    THEN NULL
	            ELSE MAX(PRIMARY_CODE_ENDDATE)
	        END                                                           AS PRIMARY_CODE_CLOSE_DATE,
	       FIRST_EPISODEID                                               AS PRIMARY_CODE_REFERRAL_ID
FROM PRIMARY_CODE_GROUP CLA
	          
	          
    	--WHERE  PERSONID = 69     
        GROUP BY PERSONID, EPISODE,LAST_ENDREASON, FIRST_EPISODEID,FIRST_PRIMARY_NEED 
        
              
)


,
	                    