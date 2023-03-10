ALTER VIEW evolve.WBCO_OOC_REVIEW AS 
WITH 
wellbore AS (
SELECT Well_UID
      ,GIS_Link AS Parcel
      ,WellStage AS Wellbore_Status
FROM (SELECT Wellstage
			,GIS_UID as Well_UID
			,GIS_Link
			,ROW_NUMBER() OVER(PARTITION BY CONCAT(GIS_UID, GIS_Link) ORDER BY WellStage) AS row
      FROM [heart].[gis_lateral_landresearch_intersect] WHERE WellStage NOT LIKE '%Abandoned%') AS TEMP
WHERE ROW = 1
),
Wells AS (
SELECT lui1.Well_UID AS Well_ID
		,wl.WellName AS WellName
		,SS_StartHorizontalDrill AS HZ_Date
		,Unit_UID AS Unit_ID
		,u.UnitName AS UnitName
		,Intersect_Length
FROM [heart].[gis_lateral_unit_intersect] AS lui1
LEFT JOIN [heart].[gis_well_lateral] AS wl ON lui1.Well_UID = wl.GIS_UID
LEFT JOIN [heart].[gis_unit_shape] AS u ON u.GIS_UID = lui1.Unit_UID
WHERE lui1.Intersect_Length > 25 AND u.Status NOT LIKE '%Producing%' AND wl.Status NOT In ('9_Abandoned','8_Temporary Abandoned','7_Producing','6_Frac Completed','10_Long Term Shut-In','0_Tentative') AND WellStage = 'Lateral'
),
Well_Related_Parcel_View AS (
SELECT CASE WHEN mors.GIS_LINK LIKE ('%[_]%') THEN SUBSTRING(mors.GIS_LINK, 1, (LEN(mors.GIS_LINK)-2))
			ELSE mors.GIS_LINK
	   END AS Adjusted_Parcel_Number
	  ,WellName
	  ,Well_ID
	  ,HZ_Date
	  ,mors.GIS_LINK as Parcel_Number
	  ,Percent_In_Unit
	  ,Intersect_Acreage
	  ,CASE WHEN wellbore.Wellbore_status = 'Swing' THEN 'Air Curve'
			WHEN wellbore.Wellbore_status = 'Lateral' THEN 'Wellbore'
			ELSE 'Non-wellbore'
	   END AS Wellbore_Status
FROM Wells
LEFT JOIN [heart].[gis_unit_land_research_intersect] AS mors ON mors.GIS_UID LIKE wells.Unit_ID
LEFT JOIN wellbore ON wellbore.Well_UID = Wells.Well_ID AND wellbore.Parcel = mors.GIS_LINK
GROUP BY WellName, Well_ID, HZ_Date, mors.GIS_LINK, wellbore.Wellbore_Status, Intersect_Acreage, Percent_In_Unit

UNION

--THIS portion of the query adds to every well any parcel that the well passes within 100' of that is not in the unit OR any parcel in a producing unit that the well passes within 100' of
SELECT CASE WHEN mors.GIS_LINK LIKE ('%[_]%') THEN SUBSTRING(mors.GIS_LINK, 1, (LEN(mors.GIS_LINK)-2))
			ELSE mors.GIS_LINK
	   END AS Adjusted_Parcel_Number
	  ,WellName
      ,wb.Well_UID as Well_ID
      ,HZ_Date
      ,Parcel
      ,Percent_In_Unit
      ,Intersect_Acreage
      ,CASE WHEN Wellbore_status = 'Swing' THEN 'Air Curve'
			WHEN Wellbore_status = 'Lateral' THEN 'Wellbore'
			ELSE 'Non-wellbore'
	   END AS Wellbore_Status
FROM wellbore wb
LEFT JOIN (SELECT * from Wells
           LEFT JOIN (SELECT GIS_Link
							,Percent_In_Unit
							,Intersect_Acreage
							,GIS_UID
					  FROM [heart].[gis_unit_land_research_intersect] 
                      WHERE STATUS NOT LIKE '%Producing') AS mors ON mors.GIS_UID = wells.Unit_ID
           ) AS mors ON mors.GIS_LINK = wb.Parcel AND mors.Well_ID = wb.Well_UID
WHERE WellName IS NULL
),
WRPV_FINAL AS (
SELECT 
    WRPV.*
    , Start
    , Development_Run__c AS Devrun
    , ROW_Number() OVER(Partition by Adjusted_Parcel_Number ORDER By Start) AS row
FROM Well_Related_Parcel_view WRPV
RIGHT JOIN heart.r_schedule_milestones AS Milestones ON W_UID = Well_ID AND Milestone = 'Horizontal_Drilling' AND Start IS NOT Null
RIGHT JOIN heart.sf_well_bore_dev_run_clearance__c AS wbco ON Well_ID = wbco.Related_Well_GIS_UID__c AND WBCOMacroStatus__c NOT LIKE ('3%') AND WBCOMacroStatus__c NOT LIKE ('4%')
WHERE PARCEL_NUMBER IS NOT NULL
),
split_parcels AS (
SELECT GIS_EX_ID__c,
		CASE WHEN PostDrillingAcreage__c IS NULL THEN Gross_Acreage__c
			 ELSE PostDrillingAcreage__c
		END AS Parcel_Acreage
FROM [heart].[sf_parcels__c] as sfparcels
),
parcel_acreage AS (
SELECT Parcel_Number
      ,STRING_AGG(cast(Unmodified_Parcels AS varchar(max)), ',')  AS Unmodified_Parcels
      ,SUM(Parcel_Acreage) AS Total_Parcel_Acreage
      ,STRING_AGG(cast(Parcel_Acreage AS varchar(max)), ',')  AS Split_Parcel_Acreages
FROM (SELECT DISTINCT
			 Adjusted_Parcel_Number AS Parcel_Number
			,Parcel_Number AS Unmodified_Parcels
			,ROUND(cast(Parcel_Acreage as float),6) AS Parcel_Acreage
	  FROM WRPV_FINAL AS WRPV2
      LEFT JOIN split_parcels ON Parcel_Number = GIS_EX_ID__c) T
GROUP BY Parcel_Number
),
well_status AS (
SELECT Adjusted_Parcel_Number AS Parcel_Number
	  ,STRING_AGG(cast(Wellbore_Status AS varchar(max)), ',')  AS Wellbore_Statuses
FROM (SELECT DISTINCT Adjusted_Parcel_Number, Wellbore_Status from WRPV_FINAL) T
GROUP BY Adjusted_Parcel_Number
),
wells_name AS (
SELECT Adjusted_Parcel_Number AS Parcel_Number
	  ,STRING_AGG(cast(WellName AS varchar(max)), ',')  AS Wells
FROM (SELECT DISTINCT Adjusted_Parcel_Number, WellName from WRPV_FINAL) T
GROUP BY Adjusted_Parcel_Number
),
devruns AS (
SELECT Adjusted_Parcel_Number AS Parcel_Number
	  ,STRING_AGG(cast(Devrun AS varchar(max)), ',')  AS Devruns
FROM (SELECT DISTINCT Adjusted_Parcel_Number, Devrun from WRPV_FINAL) T
GROUP BY Adjusted_Parcel_Number
),
devrun_dates AS (
SELECT Adjusted_Parcel_Number AS Parcel_Number
      ,Start AS Earliest_Devrun_Date
      ,devrun AS Earliest_Devrun
      ,WellName AS Earliest_Well
FROM (SELECT DISTINCT Adjusted_Parcel_Number, WellName, Devrun, Start from WRPV_FINAL where row = 1) T
)

,
date_info AS (
SELECT Adjusted_Parcel_Number AS Parcel_Number
      ,MIN(Start) AS Earliest_Date
      ,String_AGG(cast(Start AS varchar(max)), ',') AS HZ_Dates
	  ,CONVERT(date, DATEADD(yy, -3, MIN(Start)), 103) AS OOC_Evaluation_Date
      ,CONVERT(date, DATEADD(yy, -2, MIN(Start)), 103) AS OOC_Review_Date
      ,CONVERT(date, DATEADD(mm, -18, MIN(Start)), 103) AS Short_Term_Target_Review_Date
FROM (SELECT DISTINCT Adjusted_Parcel_Number, Start from WRPV_FINAL) T
GROUP BY Adjusted_Parcel_Number
),
parcel_info AS (
SELECT well_status.Parcel_Number
        ,MIN(Earliest_Date) AS Earliest_Date
		,MIN(OOC_Evaluation_Date) AS OOC_Evaluation_Date
		,MIN(OOC_Review_Date) AS OOC_Review_Date
		,MIN(Short_Term_Target_Review_Date) AS Short_Term_Target_Review_Date
        ,MIN(HZ_Dates) AS HZ_Dates
		,MIN(Wells) AS Wells
		,MIN(Unmodified_Parcels) AS Unmodified_Parcels
        ,MIN(Total_Parcel_Acreage) AS Parcel_Acreage
        ,MIN(Split_Parcel_Acreages) AS Split_Parcel_Acreages
        ,MIN(Earliest_Devrun_Date) AS Earliest_Devrun_Date
        ,MIN(Earliest_Devrun) AS Earliest_Devrun
        ,MIN(Earliest_Well) AS Earliest_Well
        ,STRING_AGG(Devruns,',') AS Devruns
	  ,STRING_AGG(cast(Wellbore_Status AS varchar(max)), ',')  AS Wellbore_Statuses

FROM (select distinct Adjusted_Parcel_Number as Parcel_Number , Wellbore_Status from WRPV_FINAL) well_status
LEFT JOIN date_info ON well_status.Parcel_Number = date_info.Parcel_Number
LEFT JOIN wells_name ON well_status.Parcel_Number = wells_name.Parcel_Number
LEFT JOIN parcel_acreage ON well_status.Parcel_Number = parcel_acreage.Parcel_Number
LEFT JOIN devruns ON well_status.Parcel_Number = devruns.Parcel_Number
LEFT JOIN devrun_dates dd ON dd.Parcel_Number = well_status.Parcel_Number
GROUP BY well_status.Parcel_Number
)
,Title_Budget
AS
(
SELECT
   CASE WHEN parcel_info.Parcel_Number LIKE ('42-003-%') THEN 'PA' 
        WHEN parcel_info.Parcel_Number LIKE ('42-051-%') THEN 'PA' 
        WHEN parcel_info.Parcel_Number LIKE ('42-059-%') THEN 'PA' 
        WHEN parcel_info.Parcel_Number LIKE ('42-081-%') THEN 'PA' 
        WHEN parcel_info.Parcel_Number LIKE ('42-113-%') THEN 'PA' 
        WHEN parcel_info.Parcel_Number LIKE ('42-125-%') THEN 'PA' 
        WHEN parcel_info.Parcel_Number LIKE ('42-129-%') THEN 'PA' 
        WHEN parcel_info.Parcel_Number LIKE ('54-049-%') THEN 'WV'
        WHEN parcel_info.Parcel_Number LIKE ('54-051-%') THEN 'WV'
        WHEN parcel_info.Parcel_Number LIKE ('54-061-%') THEN 'WV'
        WHEN parcel_info.Parcel_Number LIKE ('54-103-%') THEN 'WV'
        WHEN parcel_info.Parcel_Number LIKE ('39-013-%') THEN 'OH'
        WHEN parcel_info.Parcel_Number LIKE ('54-033-%') THEN 'WV'
        WHEN parcel_info.Parcel_Number LIKE ('42-035-%') THEN 'PA'
   END AS State
  ,CASE WHEN parcel_info.Parcel_Number LIKE ('42-003-%') THEN 'Allegheny' 
        WHEN parcel_info.Parcel_Number LIKE ('42-051-%') THEN 'Fayette' 
        WHEN parcel_info.Parcel_Number LIKE ('42-059-%') THEN 'Greene' 
        WHEN parcel_info.Parcel_Number LIKE ('42-081-%') THEN 'Lycoming' 
        WHEN parcel_info.Parcel_Number LIKE ('42-113-%') THEN 'Sullivan' 
        WHEN parcel_info.Parcel_Number LIKE ('42-125-%') THEN 'Washington' 
        WHEN parcel_info.Parcel_Number LIKE ('42-129-%') THEN 'Westmoreland' 
        WHEN parcel_info.Parcel_Number LIKE ('54-049-%') THEN 'Marion'
        WHEN parcel_info.Parcel_Number LIKE ('54-051-%') THEN 'Marshall'
        WHEN parcel_info.Parcel_Number LIKE ('54-061-%') THEN 'Monongalia'
        WHEN parcel_info.Parcel_Number LIKE ('54-103-%') THEN 'Wetzel'
        WHEN parcel_info.Parcel_Number LIKE ('39-013-%') THEN 'Belmont'
        WHEN parcel_info.Parcel_Number LIKE ('54-033-%') THEN 'Harrison'
        WHEN parcel_info.Parcel_Number LIKE ('42-035-%') THEN 'Clinton' 
   END AS County
  ,parcel_info.Parcel_Number
  ,Wellbore_Statuses
  ,cast(Parcel_Acreage as float) AS Parcel_Acreage
  ,Split_Parcel_Acreages

  ,Unmodified_Parcels
  ,Wells
  ,HZ_Dates
  ,Earliest_Date
  ,OOC_Evaluation_Date
  ,OOC_Review_Date
  ,Short_Term_Target_Review_Date
      ,parcel_info.Earliest_Devrun_Date
    ,parcel_info.Earliest_Devrun
    ,parcel_info.Earliest_Well
    ,parcel_info.Devruns


FROM parcel_info
WHERE Earliest_Date IS NOT NULL
)
,MTPP
AS 
(
SELECT
    State__c
    ,County__c
    ,mt.Name
    ,CAST(COUNT(mtrp.Id) AS decimal(9,5)) AS Count
FROM [heart].[sf_mineral_tract__c] AS mt
LEFT JOIN [heart].[sf_mineral_tract_related_parcel__c] AS mtrp ON mt.Id = mtrp.Mineral_Tract__c
WHERE Title_Workflow_Status__c = 'Complete'
GROUP BY State__c, County__c, mt.Name
)
,MTPP2
AS
(
SELECT 
    State__c
    ,County__c
    ,CAST(1/CAST(AVG(Count) AS DECIMAL(9,5)) AS DECIMAL(6,5)) AS MT_Factor
FROM MTPP
GROUP BY State__c, County__c
)
,ORBP 
AS
(
SELECT 
    parcels.State__c AS State
    ,parcels.County__c AS County
    ,parcels.GIS_EX_ID__c
    ,parcels.Name AS Tax_Parcel_Number
    ,mtrp.Mineral_Tract__c
    ,mt.Name AS Mineral_Tract
    ,Case 
        WHEN PostDrillingAcreage__c IS NULL THEN parcels.Gross_Acreage__c
        ELSE PostDrillingAcreage__c
    END AS Parcel_Acreage
    ,CAST(Round(ors.Interest__c, 8) AS DECIMAL(10,8)) * 
    Case 
        WHEN PostDrillingAcreage__c IS NULL THEN parcels.Gross_Acreage__c
    ELSE PostDrillingAcreage__c
    END AS Net_Acreage
    ,ors.Owner_Name__c
    ,ors.OwnerNameText__c AS OwnerNameText__c
    ,CASE
        WHEN ors.RecordTypeId = '0125000000022zNAAQ' THEN 'Mineral Owner'
        WHEN ors.RecordTypeId = '0125000000022zQAAQ' THEN 'Royalty Owner'
        WHEN ors.RecordTypeId = '0125000000022zSAAQ' THEN 'WI Owner'
        WHEN ors.RecordTypeId = '0125000000022zOAAQ' THEN 'NPRI Owner'
        WHEN ors.RecordTypeId = '0125000000022zRAAQ' THEN 'Surface Owner'
        WHEN ors.RecordTypeId = '0125000000022zPAAQ' THEN 'ORRI Owner'
        WHEN ors.RecordTypeId = '0125000000022xGAAQ' THEN 'Coal Owner'
        ELSE Null
    END AS Record_Type
    ,CAST(Round(ors.Interest__c, 8) AS DECIMAL(10,8)) AS Interest_Decimal
    ,RoyaltyRate__c
    ,Lease_Burdens__c AS Lease_Burden
    ,ors.UnitFormation__c
    ,ors.WIStatus__c
    ,ors.Status__c
    ,ors.Suspense_Recommended__c
    ,ors.Comments__c
    ,ors.CreatedDate
FROM [heart].[sf_parcels__c] as parcels
LEFT JOIN heart.sf_mineral_tract_related_parcel__c as mtrp ON mtrp.Parcel__c = parcels.Id
LEFT JOIN heart.sf_mineral_tract__c as mt ON mt.ID = mtrp.Mineral_Tract__c AND mt.Name NOT Like ('%Apportionment')
RIGHT JOIN heart.sf_ownership_rights__c as ors ON ors.Mineral_Tract__c = mt.Id AND ors.UnitFormation__c = 1
WHERE ors.RecordTypeId In ('0125000000022zNAAQ','0125000000022zSAAQ')
)
,ORPP
AS
(
SELECT
    State
    ,County
    ,COUNT(Owner_Name__c) AS Ownership_Rights_Count
    ,COUNT(DISTINCT GIS_EX_ID__c) AS Parcel_Count
    ,CAST(CAST(COUNT(Owner_Name__c) AS DECIMAL(12,5))/CAST(COUNT(DISTINCT GIS_EX_ID__c) AS DECIMAL(12,5)) AS DECIMAL(8,5)) AS Average_ORs_Per_Parcel
    ,CASE
        WHEN MIN(MTPP2.MT_Factor) IS NULL THEN '0.75'
        ELSE MIN(MTPP2.MT_Factor)
    END AS MT_Factor
    ,CAST((CASE
        WHEN MIN(MTPP2.MT_Factor) IS NULL THEN '0.75'
        ELSE MIN(MTPP2.MT_Factor)
    END) * CAST(COUNT(Owner_Name__c) AS DECIMAL(12,5))/CAST(COUNT(DISTINCT GIS_EX_ID__c) AS DECIMAL(12,5)) AS DECIMAL(9,5)) AS Adjusted_ORs_Need_Per_Parcel 
FROM ORBP
LEFT JOIN MTPP2 ON MTPP2.State__c = ORBP.State AND MTPP2.County__c = ORBP.County
WHERE GIS_EX_ID__c IS NOT NULL AND OwnerNameText__c IS NOT NULL
GROUP BY 
    State
    ,County
)
,AOC
AS
(
SELECT 
    CAST(AVG(Avg_ORs_Per_Active_Day) AS DECIMAL(6,2)) AS Average_ORs_Per_Person_Per_Day
FROM
(
    SELECT ors.CreatedById, 
    /*accts.Name, 
    accts.Title, */
    CONCAT('Title Analyst ', ROW_NUMBER()OVER(ORDER BY accts.Name)) AS Title_Analyst,
    COUNT(DISTINCT CONVERT(date, ors.CreatedDate, 103)) AS Active_Days, 
    COUNT(ors.Id) AS Ownership_Rights_Created, 
    CAST(COUNT(ors.Id)/COUNT(DISTINCT CONVERT(date, ors.CreatedDate, 103)) AS decimal(6,2)) AS Avg_ORs_Per_Active_Day
    FROM [heart].[sf_ownership_rights__c] AS ors
    LEFT JOIN [heart].[sf_user] AS accts ON accts.Id = ors.CreatedById
    WHERE ors.CreatedDate > '1/1/2021' AND accts.Title LIKE ('%Title%') AND accts.Name NOT IN ('Danielle St Onge','Amanda Godwin (Inactive)','Bethany Parker (Inactive)','Ryan Wagley')
    GROUP BY ors.CreatedById, accts.Name, accts.Title
--ORDER BY COUNT(ors.Id)/COUNT(DISTINCT CONVERT(date, ors.CreatedDate, 103))

) AS OR_Avgs
)
,Incomplete_MT
AS 
(
SELECT
    State__c
    ,County__c
    ,mt.Name
    ,mtrp.Parcel_GIS_EX_ID_Text_Formula__c AS Parcel_Number
    ,Title_Workflow_Status__c
    ,ROW_NUMBER() OVER(PARTITION BY Parcel_GIS_EX_ID_Text_Formula__c ORDER BY mt.Id) AS row
FROM [heart].[sf_mineral_tract__c] AS mt
LEFT JOIN [heart].[sf_mineral_tract_related_parcel__c] AS mtrp ON mt.Id = mtrp.Mineral_Tract__c
WHERE Title_Workflow_Status__c <> 'Complete' AND mt.name NOT LIKE ('%Apportionment%')
)
, result AS
(
SELECT
    TB.State
    ,TB.County
    ,TB.Parcel_Number
    --,TB.Title_Order_Action
    --,TB.Unmodified_Parcels
    ,TB.Wells
    ,TB.HZ_Dates
    ,TB.Earliest_Date
    ,Earliest_Devrun_Date
    ,Earliest_Devrun
    ,Earliest_Well
    ,Devruns
    --,TB.OOC_Evaluation_Date
    ,YEAR(TB.OOC_Review_Date) AS OOC_Review_Year
    ,TB.OOC_Review_Date
    ,TB.Short_Term_Target_Review_Date
    --,TB.Historic_Average_Cost
    --,TB.Estimated_Cost
    ,Ownership_Rights_Count
    --,Parcel_Count
    ,Average_ORs_Per_Parcel
    ,MT_Factor
    ,Adjusted_ORs_Need_Per_Parcel
    ,Average_ORs_Per_Person_Per_Day
    ,CAST(ROUND(Adjusted_ORs_Need_Per_Parcel/Average_ORs_Per_Person_Per_Day,2) AS float) AS Analyst_Workdays_per_Parcel
    ,CASE 
        WHEN TB.OOC_Review_Date < '2024-01-01' THEN FLOOR(DATEDIFF(day, GETDATE(), '2023-12-31')*0.6876)
        ELSE 251
    END AS Workdays_in_Year
    --,Title_Workflow_Status__c
FROM Title_Budget AS TB
LEFT JOIN ORPP ON ORPP.County = TB.County
LEFT JOIN AOC ON TB.Parcel_Number IS NOT NULL
LEFT JOIN Incomplete_MT ON Incomplete_MT.Parcel_Number = TB.Parcel_Number AND Incomplete_MT.row = 1
--LEFT JOIN devruns ON TB.Parcel_Number = devruns.Parcel_Number
--LEFT JOIN devrun_dates dd ON dd.Parcel_Number = TB.Parcel_Number
)

SELECT * FROM result-- WHERE Earliest_Devrun_date <> Earliest_Date
GO