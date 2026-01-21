;WITH Raw AS (
    SELECT DISTINCT
        fact.ASSESSMENT_ID AS cinf_assessment_id,
        NULLIF(LTRIM(RTRIM(fact.FACTOR_VALUE)), '') AS factor_code
    FROM dm_cin_assess_factors fact
),
Parsed AS (
    SELECT
        r.cinf_assessment_id,
        r.factor_code,
        TRY_CONVERT(int, LEFT(r.factor_code, CASE
            WHEN PATINDEX('%[^0-9]%', r.factor_code) = 0 THEN LEN(r.factor_code)
            ELSE PATINDEX('%[^0-9]%', r.factor_code) - 1
        END)) AS num_part,
        CASE
            WHEN PATINDEX('%[^0-9]%', r.factor_code) = 0 THEN ''
            ELSE SUBSTRING(r.factor_code, PATINDEX('%[^0-9]%', r.factor_code), 10)
        END AS alpha_part
    FROM Raw r
    WHERE r.factor_code IS NOT NULL
)
SELECT
    NULL AS cinf_table_id,
    p.cinf_assessment_id,
    N'[' +
    STUFF((
        SELECT N', ' + QUOTENAME(x.factor_code, '"')
        FROM Parsed x
        WHERE x.cinf_assessment_id = p.cinf_assessment_id
        ORDER BY x.num_part, x.alpha_part, x.factor_code
        FOR XML PATH(''), TYPE
    ).value('.', 'NVARCHAR(MAX)'), 1, 2, N'')
    + N']' AS cinf_assessment_factors_json
FROM Parsed p
GROUP BY p.cinf_assessment_id;
