SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [evolve].[Title_Budget_Test] AS WITH APL AS
(
    SELECT GIS_Tax_Parcel_Id 
    FROM trust.all_purpose_land apl 
    WHERE Health_Flag = 'Y'
    GROUP BY GIS_Tax_Parcel_Id
)
,est_fut_cost
AS
(
select 
    lbf.Business_Plan_Year__c                                   AS Business_Plan_Year
    ,  lbf.State__c                                             AS State
    ,  lbf.County__c                                            AS County
    ,  cast(lbf1.Forecasted_Unit_Cost__c as float)                            AS Targeted_Scope
    ,  cast(lbf3.Forecasted_Unit_Cost__c as float)                            AS SUAB_Cost
    ,  cast(lbf2.Forecasted_Unit_Cost__c as float)                            AS Upgrade_Cost
    ,  cast(lbf4.Forecasted_Unit_Cost__c as float)                            AS SUTO_Cost
from (   SELECT
        Business_Plan_Year__c
        ,   State__c
        ,   County__c
    FROM heart.sf_land_budget_forecasts__c 
    WHERE Status__c = 'Active' AND Business_Plan_Action__c In ('Order SUTO','Order SUAB','Order Targeted Scope','Convert to SUTO')
    GROUP BY Business_Plan_Year__c, State__c, County__c

) lbf
LEFT JOIN heart.sf_land_budget_forecasts__c lbf2 ON lbf.State__c = lbf2.State__c AND lbf.County__c = lbf2.County__c AND lbf2.Status__c = 'Active' AND lbf2.Business_Plan_Action__c = 'Convert to SUTO' AND lbf.Business_Plan_Year__c = lbf2.Business_Plan_Year__c
LEFT JOIN heart.sf_land_budget_forecasts__c lbf1 ON lbf.State__c = lbf1.State__c AND lbf.County__c = lbf1.County__c AND lbf1.Status__c = 'Active' AND lbf1.Business_Plan_Action__c = 'Order Targeted Scope' AND lbf.Business_Plan_Year__c = lbf1.Business_Plan_Year__c
LEFT JOIN heart.sf_land_budget_forecasts__c lbf3 ON lbf.State__c = lbf3.State__c AND lbf.County__c = lbf3.County__c AND lbf3.Status__c = 'Active' AND lbf3.Business_Plan_Action__c = 'Order SUAB' AND lbf.Business_Plan_Year__c = lbf3.Business_Plan_Year__c
LEFT JOIN heart.sf_land_budget_forecasts__c lbf4 ON lbf.State__c = lbf4.State__c AND lbf.County__c = lbf4.County__c AND lbf4.Status__c = 'Active' AND lbf4.Business_Plan_Action__c = 'Order SUTO' AND lbf.Business_Plan_Year__c = lbf4.Business_Plan_Year__c
GROUP BY 
    lbf.Business_Plan_Year__c  
    ,   lbf.State__c
    ,   lbf.County__c
    ,  lbf1.Forecasted_Unit_Cost__c 
    ,  lbf3.Forecasted_Unit_Cost__c
    ,  lbf2.Forecasted_Unit_Cost__c
    ,  lbf4.Forecasted_Unit_Cost__c
)
,Best_WRP
AS
(SELECT 
      *
FROM
(
      SELECT
            CASE WHEN GIS_EX_ID__c LIKE ('%[_]%') THEN SUBSTRING(GIS_EX_ID__c, 1, (CHARINDEX('_',GIS_EX_ID__c)-1))
			ELSE GIS_EX_ID__c
	      END AS Parcel_Number
            ,  Title_Workflow_Status__c AS Title_Workflow_Status__c
            ,  Case
            WHEN Title_Workflow_Status__c IS NULL THEN 1
            WHEN Title_Workflow_Status__c = 'Needs Inventoried' THEN 2
            WHEN Title_Workflow_Status__c = 'In Ordering Queue' THEN 4
            WHEN Title_Workflow_Status__c = 'Waiting on Vendor' THEN 5
            WHEN Title_Workflow_Status__c = 'Waiting on Heirship' THEN 6
            WHEN Title_Workflow_Status__c = 'In Progress' THEN 8
            WHEN Title_Workflow_Status__c = 'Pending GIS Update' THEN 9
            WHEN Title_Workflow_Status__c = 'Review Delayed' THEN 10
            WHEN Title_Workflow_Status__c = 'Title Complete' THEN 11
            WHEN Title_Workflow_Status__c = 'Pending Review' THEN 7
            WHEN Title_Workflow_Status__c =  'Requires Analyst Evaluation' THEN 3
            ELSE 12
        END AS Title_Workflow_Rank
            ,  ROW_Number() OVER(Partition by CASE WHEN GIS_EX_ID__c LIKE ('%[_]%') THEN SUBSTRING(GIS_EX_ID__c, 1, (CHARINDEX('_',GIS_EX_ID__c)-1))
			ELSE GIS_EX_ID__c
	      END ORDER BY Case
            WHEN Title_Workflow_Status__c IS NULL THEN 1
            WHEN Title_Workflow_Status__c = 'Needs Inventoried' THEN 2
            WHEN Title_Workflow_Status__c = 'In Ordering Queue' THEN 3
            WHEN Title_Workflow_Status__c = 'Waiting on Vendor' THEN 4
            WHEN Title_Workflow_Status__c = 'Waiting on Heirship' THEN 5
            WHEN Title_Workflow_Status__c = 'In Progress' THEN 7
            WHEN Title_Workflow_Status__c = 'Pending GIS Update' THEN 8
            WHEN Title_Workflow_Status__c = 'Review Delayed' THEN 9
            WHEN Title_Workflow_Status__c = 'Title Complete' THEN 10
            WHEN Title_Workflow_Status__c = 'Pending Review' THEN 6
            ELSE 11
        END DESC) AS row
        FROM heart.sf_wellrelatedparcel__c

) tmp
WHERE row = 1 AND Parcel_Number IS NOT NULL
)
/*,Lot_Percent --Updated to identify % of parcel under 3 acres in a unit and flag units where > 80% of parcels are under 3 | UPDATE - THIS WHOLE SECTION HAS BEEN DEPRECATED
AS
(
SELECT
    UnitName
    ,Count(GIS_Link) AS Total_Tracts
    ,SUM(CASE
        WHEN Gross_Acre < 3 THEN 1
        Else 0
    END) AS Under_Three_Tracts
    ,Round(cast(SUM(CASE
        WHEN Gross_Acre < 3 THEN 1
        Else 0
    END)as float)/cast(Count(GIS_Link)as float) * 100,2)  AS Percent_Under_Three
    ,CASE
        WHEN Count(GIS_Link) > 100 AND Round(cast(SUM(CASE
        WHEN Gross_Acre < 3 THEN 1
        Else 0
    END) as float)/cast(Count(GIS_Link)as float) * 100,2) > 80 THEN 'True'
        ELSE 'False'
    END AS QSUTO_NO_ORDER
FROM [heart].[gis_unit_land_research_intersect]
GROUP By UnitName
)*/
/*, logic_factors AS
(
SELECT

      5.0000                                                                  AS Acreage_Threshold_WB
      ,     3.0000                                                            AS Acreage_Threshold_NWB
      ,     'Yes'                                                             AS Order_Unleased_NWB
      ,     'No'                                                              AS Apply_Ac_Threshold_WB
      ,     'Yes'                                                             AS Apply_Ac_Threshold_NWB_Leased

FROM heart.sf_land_budget_forecasts__c 
)*/
,dev_run AS
(
SELECT
      well.Name AS Well_Name
      ,  dr.Name AS Devrun_Name
FROM [heart].[sf_well__c] well
LEFT JOIN [heart].[sf_dev_run__c] dr ON well.Development_Run__c = dr.Id
WHERE well.Development_Run__c IS NOT NULL
)
,  Lateral AS  --collects the actual wellbore parcels
(
    SELECT 
    GIS_UID
    ,   WellName
    ,   GIS_Link
    FROM heart.gis_lateral_landresearch_intersect
    WHERE WellStage = 'Lateral'
    GROUP BY
        GIS_UID
        ,   WellName
        ,   GIS_Link
)
,   Aircurve AS --collects the physically aircurve parcels
(
    SELECT 
    GIS_UID
    ,   WellName
    ,   GIS_Link
    FROM heart.gis_lateral_landresearch_intersect
    WHERE WellStage = 'Swing'
    GROUP BY
        GIS_UID
        ,   WellName
        ,   GIS_Link


)
,   Lateral_Buffer AS --grabs all parcels within 100' of a lateral
(
    SELECT
    GIS_UID
    ,   WellName
    ,   GIS_Link
    FROM heart.gis_lateral_100ft_landresearch_intersect
    GROUP BY
        GIS_UID
        ,   WellName
        ,   GIS_Link

)
,   Unit_Parcels AS --grabs all the parcels inside the unit
(
    SELECT 
    lui1.Well_UID AS GIS_UID
    ,   WellName
    ,   GIS_Link
FROM [heart].[gis_lateral_unit_intersect] AS lui1
            LEFT JOIN [heart].[gis_well_lateral] AS wl ON lui1.Well_UID = wl.GIS_UID
            LEFT JOIN [heart].[gis_unit_shape] AS u ON lui1.Unit_UID = u.GIS_UID
            LEFT JOIN [heart].[gis_unit_land_research_intersect]  AS mors
                    ON mors.GIS_UID LIKE lui1.Unit_UID
WHERE lui1.Intersect_Length > 25
    AND u.Status NOT LIKE '%Producing%'
    AND wl.Status NOT IN
        ('9_Abandoned', '8_Temporary Abandoned', '7_Producing', '6_Frac Completed',
        '10_Long Term Shut-In')
    AND WellStage = 'Lateral'
GROUP BY lui1.Well_UID, WellName, GIS_Link
)
,   Non_Wellbore AS  --ok not real sure why I did this, but it currently works, not rewriting at this time
(
    SELECT
    GIS_UID
    ,   WellName
    ,   GIS_Link
    FROM Unit_Parcels
)

, Combined AS --combines all parcel types into one table that just has the well id, well name, and parcel number, then adds the wellbore status and ranks them from "highest" wellbore status to lowest.
(
    SELECT 
        * 
    ,   'Wellbore' AS Wellbore_Status
    ,   '1'         AS Wellbore_Rank
    FROM Lateral

    UNION

    SELECT 
        * 
    ,   'Aircurve' AS Wellbore_Status
    ,   '2'         AS Wellbore_Rank
    FROM Aircurve

    UNION

    SELECT 
        * 
    ,   'Wellbore Buffer' AS Wellbore_Status
    ,   '3'         AS Wellbore_Rank
    FROM Lateral_Buffer

    UNION

    SELECT
        *
    ,   'Non_Wellbore' AS Wellbore_Status
    ,   '4'         AS Wellbore_Rank
    FROM Non_Wellbore
    
)
,   Unit_Acres AS  --adds in the number of acres in the unit, if unit is in 
(
    SELECT 
    lui1.Well_UID
    ,   mors.GIS_Link
    ,   STRING_AGG(u.UnitName,',')                                AS Units
    ,   CAST(ROUND(SUM(Percent_In_Unit * 100), 8) AS float)           AS Percent_In_Unit
    ,   CAST(ROUND(SUM(Intersect_Acreage), 8) AS float)         AS Intersect_Acreage
FROM [heart].[gis_lateral_unit_intersect] AS lui1
    LEFT JOIN [heart].[gis_well_lateral] AS wl ON lui1.Well_UID = wl.GIS_UID
    LEFT JOIN [heart].[gis_unit_shape] AS u ON u.GIS_UID = lui1.Unit_UID
    LEFT JOIN [heart].[gis_unit_land_research_intersect]  AS mors
            ON mors.GIS_UID LIKE lui1.Unit_UID
WHERE lui1.Intersect_Length > 25
    AND u.Status NOT LIKE '%Producing%'
    AND wl.Status NOT IN
        ('9_Abandoned', '8_Temporary Abandoned', '7_Producing', '6_Frac Completed',
        '10_Long Term Shut-In')
    AND WellStage = 'Lateral'
GROUP BY 
    lui1.Well_UID
    ,   mors.GIS_Link
)
,   Well_Related_Parcel_View AS --
(
SELECT 
    GIS_UID AS Well_UID
    ,   WellName
    ,   cm.GIS_Link AS Parcel_Number
    ,   Percent_In_Unit
    ,   Intersect_Acreage
    ,   Wellbore_Status
    ,   Wellbore_Rank
    ,   Milestones.Start
    ,   Sandbox_Milestones.Start_Date AS Sandbox_Start
    ,   Row_Number() OVER(Partition By GIS_UID, cm.GIS_Link Order By Wellbore_Rank) AS row
FROM Combined cm
    LEFT JOIN Unit_Acres UA ON cm.GIS_Link = UA.GIS_Link AND cm.GIS_UID = UA.Well_UID
    LEFT JOIN heart.r_schedule_milestones AS Milestones ON Milestones.W_UID = cm.GIS_UID AND Milestones.Milestone = 'Horizontal_Drilling' AND Milestones.Start IS NOT Null
    LEFT JOIN trust.mos_draft AS Sandbox_Milestones ON Sandbox_Milestones.Well_UID = cm.GIS_UID AND Sandbox_Milestones.Milestone = 'Horizontal_Drilling' AND Sandbox_Milestones.Start_Date IS NOT Null
WHERE (Milestones.Start IS NOT NULL OR Sandbox_Milestones.Start_Date IS NOT NULL)
), WRPV_FINAL AS (

SELECT 
    CASE WHEN Parcel_Number LIKE ('%[_]%') THEN SUBSTRING(Parcel_Number, 1, (CHARINDEX('_',Parcel_Number)-1))
			ELSE Parcel_Number
	   END AS Adjusted_Parcel_Number
    ,   Devrun_Name
    ,   WellName
    ,   Parcel_Number
    ,   Percent_In_Unit
    ,   Intersect_Acreage
    ,   Wellbore_Status
    ,   Wellbore_Rank
    ,   Start
    ,   Sandbox_Start
    ,   row
FROM Well_Related_Parcel_View wrpv
LEFT JOIN dev_run dr ON dr.Well_Name = wrpv.WellName
WHERE Row = 1

)
,split_parcels AS (
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
      LEFT JOIN split_parcels ON Parcel_Number = GIS_EX_ID__c
      ) T
GROUP BY Parcel_Number
),
well_status AS (
SELECT Adjusted_Parcel_Number AS Parcel_Number
	  ,STRING_AGG(cast(Wellbore_Status AS varchar(max)), ',')  AS Wellbore_Statuses
FROM (SELECT DISTINCT Adjusted_Parcel_Number, Wellbore_Status from WRPV_FINAL WHERE row = 1) T
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
	  ,STRING_AGG(cast(Devrun_Name AS varchar(max)), ',')  AS Devruns
FROM (SELECT DISTINCT Adjusted_Parcel_Number, Devrun_Name from WRPV_FINAL) T
GROUP BY Adjusted_Parcel_Number
)
,date_info AS (
SELECT Adjusted_Parcel_Number AS Parcel_Number
      ,MIN(Start) AS Earliest_Date
      ,MIN(Sandbox_Start) AS Sandbox_Earliest_Date
      ,String_AGG(cast(Start AS varchar(max)), ',') AS HZ_Dates
FROM (SELECT DISTINCT Adjusted_Parcel_Number, Start, Sandbox_Start from WRPV_FINAL) T
GROUP BY Adjusted_Parcel_Number
)
,wellbore_dates AS (
SELECT Adjusted_Parcel_Number AS Parcel_Number
      ,Start AS Earliest_Wellbore_Date
      ,Sandbox_Start AS Earliest_Sandbox_Wellbore_Date
      ,Devrun_Name
      ,WellName
      ,ROW_NUMBER() OVER(Partition by Adjusted_Parcel_Number ORDER BY Start) as prod_row
      ,ROW_NUMBER() OVER(Partition by Adjusted_Parcel_Number ORDER BY Sandbox_Start) as sandbox_row
FROM WRPV_FINAL 
WHERE Wellbore_Status In ('Air Curve','Wellbore') AND (Start IS NOT NULL OR Sandbox_Start IS NOT NULL)
)

,prod_dates AS (
SELECT Adjusted_Parcel_Number AS Parcel_Number
      ,Start AS Earliest_Dev_Date
      ,Devrun_Name
      ,WellName
      ,ROW_NUMBER() OVER(Partition by Adjusted_Parcel_Number ORDER BY Start) as row
FROM WRPV_FINAL
WHERE Start IS NOT NULL 
)
,sandbox_dates AS (
SELECT Adjusted_Parcel_Number AS Parcel_Number
      ,Sandbox_Start AS Earliest_Sandbox_Dev_Date
      ,Devrun_Name
      ,WellName
      ,ROW_NUMBER() OVER(Partition by Adjusted_Parcel_Number ORDER BY Sandbox_Start) as row
FROM WRPV_FINAL
WHERE Sandbox_Start IS NOT NULL
),title_tracker_cost AS (
SELECT *
FROM 
(SELECT CASE
			WHEN GIS_EX_ID__c IS NULL AND County__c = 'Allegheny' THEN CONCAT('42-003-', Parcel_TEXT__c)
			WHEN GIS_EX_ID__c IS NULL AND County__c = 'Fayette' THEN CONCAT('42-051-', Parcel_TEXT__c)
			WHEN GIS_EX_ID__c IS NULL AND County__c = 'Greene' THEN CONCAT('42-059-', Parcel_TEXT__c)
			WHEN GIS_EX_ID__c IS NULL AND County__c = 'Lycoming' THEN CONCAT('42-081-', Parcel_TEXT__c)
			WHEN GIS_EX_ID__c IS NULL AND County__c = 'Sullivan' THEN CONCAT('42-113-', Parcel_TEXT__c)
			WHEN GIS_EX_ID__c IS NULL AND County__c = 'Washington' THEN CONCAT('42-125-', Parcel_TEXT__c)
			WHEN GIS_EX_ID__c IS NULL AND County__c = 'Westmoreland' THEN CONCAT('42-129-', Parcel_TEXT__c)
			WHEN GIS_EX_ID__c IS NULL AND County__c = 'Marion' THEN CONCAT('54-049-', Parcel_TEXT__c)
			WHEN GIS_EX_ID__c IS NULL AND County__c = 'Marshall' THEN CONCAT('54-051-', Parcel_TEXT__c)
			WHEN GIS_EX_ID__c IS NULL AND County__c = 'Monongalia' THEN CONCAT('54-061-', Parcel_TEXT__c)
			WHEN GIS_EX_ID__c IS NULL AND County__c = 'Wetzel' THEN CONCAT('54-103-', Parcel_TEXT__c)
			WHEN GIS_EX_ID__c IS NULL AND County__c = 'Belmont' THEN CONCAT('39-013-', Parcel_TEXT__c)
			WHEN GIS_EX_ID__c IS NULL AND State__c = 'WV' AND County__c = 'Harrison' THEN CONCAT('54-033-', Parcel_TEXT__c)
            ELSE GIS_EX_ID__c 
		END AS 'Parcel_Number'
       ,ROW_NUMBER() OVER(PARTITION BY CASE
			WHEN GIS_EX_ID__c IS NULL AND County__c = 'Allegheny' THEN CONCAT('42-003-', Parcel_TEXT__c)
			WHEN GIS_EX_ID__c IS NULL AND County__c = 'Fayette' THEN CONCAT('42-051-', Parcel_TEXT__c)
			WHEN GIS_EX_ID__c IS NULL AND County__c = 'Greene' THEN CONCAT('42-059-', Parcel_TEXT__c)
			WHEN GIS_EX_ID__c IS NULL AND County__c = 'Lycoming' THEN CONCAT('42-081-', Parcel_TEXT__c)
			WHEN GIS_EX_ID__c IS NULL AND County__c = 'Sullivan' THEN CONCAT('42-113-', Parcel_TEXT__c)
			WHEN GIS_EX_ID__c IS NULL AND County__c = 'Washington' THEN CONCAT('42-125-', Parcel_TEXT__c)
			WHEN GIS_EX_ID__c IS NULL AND County__c = 'Westmoreland' THEN CONCAT('42-129-', Parcel_TEXT__c)
			WHEN GIS_EX_ID__c IS NULL AND County__c = 'Marion' THEN CONCAT('54-049-', Parcel_TEXT__c)
			WHEN GIS_EX_ID__c IS NULL AND County__c = 'Marshall' THEN CONCAT('54-051-', Parcel_TEXT__c)
			WHEN GIS_EX_ID__c IS NULL AND County__c = 'Monongalia' THEN CONCAT('54-061-', Parcel_TEXT__c)
			WHEN GIS_EX_ID__c IS NULL AND County__c = 'Wetzel' THEN CONCAT('54-103-', Parcel_TEXT__c)
			WHEN GIS_EX_ID__c IS NULL AND County__c = 'Belmont' THEN CONCAT('39-013-', Parcel_TEXT__c)
			WHEN GIS_EX_ID__c IS NULL AND State__c = 'WV' AND County__c = 'Harrison' THEN CONCAT('54-033-', Parcel_TEXT__c)
			ELSE GIS_EX_ID__c END ORDER BY Date_Ordered__c DESC, Title_Quality__c ASC) AS 'Row'
FROM heart.sf_title_tracker__c
WHERE Title_Quality__c IS NOT NULL
  AND Date_Ordered__c > '2020-01-01' AND Title_Tracker_Type__c NOT IN ('Coal Title', 'Surface Title')
) AS R
WHERE ROW = 1
),
title_tracker_available AS ( --Pulls 
SELECT *
FROM 
(SELECT CASE
			WHEN GIS_EX_ID__c IS NULL AND County__c = 'Allegheny' THEN CONCAT('42-003-', Parcel_TEXT__c)
			WHEN GIS_EX_ID__c IS NULL AND County__c = 'Fayette' THEN CONCAT('42-051-', Parcel_TEXT__c)
			WHEN GIS_EX_ID__c IS NULL AND County__c = 'Greene' THEN CONCAT('42-059-', Parcel_TEXT__c)
			WHEN GIS_EX_ID__c IS NULL AND County__c = 'Lycoming' THEN CONCAT('42-081-', Parcel_TEXT__c)
			WHEN GIS_EX_ID__c IS NULL AND County__c = 'Sullivan' THEN CONCAT('42-113-', Parcel_TEXT__c)
			WHEN GIS_EX_ID__c IS NULL AND County__c = 'Washington' THEN CONCAT('42-125-', Parcel_TEXT__c)
			WHEN GIS_EX_ID__c IS NULL AND County__c = 'Westmoreland' THEN CONCAT('42-129-', Parcel_TEXT__c)
			WHEN GIS_EX_ID__c IS NULL AND County__c = 'Marion' THEN CONCAT('54-049-', Parcel_TEXT__c)
			WHEN GIS_EX_ID__c IS NULL AND County__c = 'Marshall' THEN CONCAT('54-051-', Parcel_TEXT__c)
			WHEN GIS_EX_ID__c IS NULL AND County__c = 'Monongalia' THEN CONCAT('54-061-', Parcel_TEXT__c)
			WHEN GIS_EX_ID__c IS NULL AND County__c = 'Wetzel' THEN CONCAT('54-103-', Parcel_TEXT__c)
			WHEN GIS_EX_ID__c IS NULL AND County__c = 'Belmont' THEN CONCAT('39-013-', Parcel_TEXT__c)
			WHEN GIS_EX_ID__c IS NULL AND State__c = 'WV' AND County__c = 'Harrison' THEN CONCAT('54-033-', Parcel_TEXT__c)
            WHEN GIS_EX_ID__c IS NULL AND State__c = 'WV' AND County__c = 'Doddridge' THEN CONCAT('54-017-', Parcel_TEXT__c)
            ELSE GIS_EX_ID__c 
		END AS 'Parcel_Number'
        , Title_Tracker_Type__c AS Title_Tracker_Type
        , Title_Tracker_Status__c AS Title_Tracker_Status
        , Date_Invoice_Coded__c AS Date_Paid
        , CASE
            WHEN Date_Invoice_Coded__c IS NULL THEN 
            CASE
                WHEN Date_Received__c IS NOT NULL THEN DATEADD(day, 45, Date_Received__c)
                WHEN Vendor_Expected_date__c IS NOT NULL THEN DATEADD(day, 45, Vendor_Expected_date__c)
                WHEN Vendor_Due_Date__c IS NOT NULL THEN DATEADD(day, 45, Vendor_Due_Date__c)
                WHEN Date_Received__c IS NOT NULL THEN Date_Received__c
                WHEN CreatedDate IS NOT NULL THEN CreatedDate     
            END
            ELSE Date_Invoice_Coded__c
          END Dollar_Spend_Date
        , cast(Estimated_Title_Cost__c as float) AS Estimated_Title_Cost
        , CASE
            WHEN Date_Received__c >= DATEADD(day, -180, GETDATE()) AND Title_Tracker_Status__c = 'Title Received (Not Yet Checked In)' AND Date_Invoice_Coded__c IS NULL THEN 'In-flight'
            WHEN Title_Tracker_Status__c = 'Title Received (Not Yet Checked In)' THEN 'Incurred'
            WHEN Date_Received__c >= DATEADD(day, -180, GETDATE()) AND Title_Tracker_Status__c = 'Title Received' AND Date_Invoice_Coded__c IS NULL THEN 'In-flight'
            WHEN Title_Tracker_Status__c = 'Title Received' THEN 'Incurred'
            WHEN Title_Tracker_Status__c = 'Title Ordered' THEN 'In-flight'
            WHEN Title_Tracker_Status__c = 'Needs Ordered' THEN 'Projected'
            WHEN Title_Tracker_Status__c = 'Needs Ordered - On Hold' THEN 'Projected'
            WHEN Title_Tracker_Status__c = 'Final Review Complete - Limited Scope' THEN 'Incurred'
            WHEN Title_Tracker_Status__c = 'Needs Evaluated' THEN 'Projected'
            WHEN Title_Tracker_Status__c = 'Canceled - No Title' THEN 'Projected'
            ELSE Null
            END AS Cost_Type
        , Certifier__c AS Certifier
        , cast(Title_Cost__c as float) AS Actual_Title_Cost
        , Title_Quality__c AS Title_Quality
        ,  ROW_NUMBER() OVER(PARTITION BY CASE
			WHEN GIS_EX_ID__c IS NULL AND County__c = 'Allegheny' THEN CONCAT('42-003-', Parcel_TEXT__c)
			WHEN GIS_EX_ID__c IS NULL AND County__c = 'Fayette' THEN CONCAT('42-051-', Parcel_TEXT__c)
			WHEN GIS_EX_ID__c IS NULL AND County__c = 'Greene' THEN CONCAT('42-059-', Parcel_TEXT__c)
			WHEN GIS_EX_ID__c IS NULL AND County__c = 'Lycoming' THEN CONCAT('42-081-', Parcel_TEXT__c)
			WHEN GIS_EX_ID__c IS NULL AND County__c = 'Sullivan' THEN CONCAT('42-113-', Parcel_TEXT__c)
			WHEN GIS_EX_ID__c IS NULL AND County__c = 'Washington' THEN CONCAT('42-125-', Parcel_TEXT__c)
			WHEN GIS_EX_ID__c IS NULL AND County__c = 'Westmoreland' THEN CONCAT('42-129-', Parcel_TEXT__c)
			WHEN GIS_EX_ID__c IS NULL AND County__c = 'Marion' THEN CONCAT('54-049-', Parcel_TEXT__c)
			WHEN GIS_EX_ID__c IS NULL AND County__c = 'Marshall' THEN CONCAT('54-051-', Parcel_TEXT__c)
			WHEN GIS_EX_ID__c IS NULL AND County__c = 'Monongalia' THEN CONCAT('54-061-', Parcel_TEXT__c)
			WHEN GIS_EX_ID__c IS NULL AND County__c = 'Wetzel' THEN CONCAT('54-103-', Parcel_TEXT__c)
			WHEN GIS_EX_ID__c IS NULL AND County__c = 'Belmont' THEN CONCAT('39-013-', Parcel_TEXT__c)
			WHEN GIS_EX_ID__c IS NULL AND State__c = 'WV' AND County__c = 'Harrison' THEN CONCAT('54-033-', Parcel_TEXT__c)
            WHEN GIS_EX_ID__c IS NULL AND State__c = 'WV' AND County__c = 'Doddridge' THEN CONCAT('54-017-', Parcel_TEXT__c)
            ELSE GIS_EX_ID__c 
		END ORDER BY SUBSTRING(Title_Quality__c, 1, 1) ASC, Date_Ordered__c DESC) as row
FROM heart.sf_title_tracker__c tt
WHERE Title_Tracker_Type__c IS NOT NULL
  AND Title_Tracker_Type__c NOT IN ('Coal Title', 'Surface Title')
) AS R
WHERE ROW = 1 AND Parcel_Number IS NOT NULL AND Title_Tracker_Status <> 'Title Canceled'
)
,parcel_info_pre AS (
SELECT well_status.Parcel_Number
        ,MIN(Earliest_Date) AS Earliest_Dev_Date
        ,MIN(HZ_Dates) AS HZ_Dates
	    ,MIN(Wells) AS Wells
	    ,MIN(Devruns) AS Devruns
        ,MIN(Unmodified_Parcels) AS Unmodified_Parcels
        ,MIN(Total_Parcel_Acreage) AS Parcel_Acreage
        ,MIN(Split_Parcel_Acreages) AS Split_Parcel_Acreages
	    ,STRING_AGG(cast(well_status.Wellbore_Status AS varchar(max)), ',')  AS Wellbore_Statuses
        ,MIN(CASE 
            WHEN well_status.Wellbore_Status = 'Aircurve' THEN '1'
            WHEN well_status.Wellbore_Status = 'Wellbore' THEN '1'
            WHEN well_status.Wellbore_Status = 'Wellbore Buffer' THEN '2'
            WHEN well_status.Wellbore_Status = 'Non_wellbore' THEN '3'
         END) AS Highest_Wellbore_status
	    ,MIN(CASE
            WHEN Title_Tracker_Type = 'Certified' THEN '1'
            WHEN Title_Tracker_Type = 'Bringdown-Certified' THEN '1'
            WHEN Title_Tracker_Type = 'Limited Scope' THEN '4'
            WHEN Title_Tracker_Type = 'Targeted Scope Abstract' THEN '3' --artichoke
            WHEN Title_Tracker_Type = 'Standup Title Opinion' THEN '1'
            WHEN Title_Tracker_Type = 'Coal Title' THEN '4'
            WHEN Title_Tracker_Type = 'Standup Abstract' THEN '2'
            WHEN Title_Tracker_Type = 'Revision' THEN '1'
            WHEN Title_Tracker_Type = 'Limited Scope-Abstract' THEN '3'
            WHEN Title_Tracker_Type = 'Quarter - SUTO' THEN '3'
            WHEN Title_Tracker_Type = 'Full Landman' THEN '4'
            WHEN Title_Tracker_Type = 'Abstract' THEN '2'
            WHEN Title_Tracker_Type = 'Ownership Report' THEN '4'
            WHEN Title_Tracker_Type = 'In House Bringdown' THEN '4'
            WHEN Title_Tracker_Type = 'Bringdown-Abstract' THEN '2'
            WHEN Title_Tracker_Type = 'Upgrade' THEN '1'
            WHEN Title_Tracker_Type = 'Bringdown-Limited Scope' THEN '4'
            WHEN Title_Tracker_Type = 'SUTO Revision' THEN '1'
            WHEN Title_Tracker_Type = 'Targeted Scope Revision' THEN '2'
            WHEN Title_Tracker_Type = 'Standup Abstract Revision' THEN '2'
            WHEN Title_Tracker_Type = 'NULL' THEN '4'
            ELSE '4'
        END) AS Title_Rank_Available
        , MIN(Title_Tracker_Status) AS Title_Tracker_Status
        , MIN(Title_Tracker_Type) AS Title_Tracker_Type
        , MIN(Cost_Type) AS Cost_Type
        , MIN(Actual_Title_Cost) AS Actual_Title_Cost
        , MIN(Dollar_Spend_Date) AS Dollar_Spend_Date
        , MIN(Estimated_Title_Cost) AS Estimated_Title_Cost
        , MIN(Title_Quality) AS Title_Quality
        , MIN(Certifier) AS Certifier
FROM (select distinct Adjusted_Parcel_Number as Parcel_Number, Wellbore_Status from WRPV_FINAL) well_status
LEFT JOIN date_info ON well_status.Parcel_Number = date_info.Parcel_Number
LEFT JOIN wells_name ON well_status.Parcel_Number = wells_name.Parcel_Number
LEFT JOIN parcel_acreage ON well_status.Parcel_Number = parcel_acreage.Parcel_Number
LEFT JOIN title_tracker_available tti ON well_status.Parcel_Number = tti.Parcel_Number
LEFT JOIN devruns ON well_status.Parcel_Number = devruns.Parcel_Number
GROUP BY well_status.Parcel_Number
)
,hist_cost AS (
SELECT State__c
      ,County__c
	  ,Title_Tracker_Type__c
	  ,ROUND(AVG(Title_Cost__c),2) AS Title_Cost
FROM [heart].[sf_title_tracker__c]
WHERE Date_Ordered__c > '2020-01-01'
  AND Title_Tracker_Type__c IN ('Standup Title Opinion', 'Standup Abstract') AND Title_Cost__c IS NOT NULL
GROUP BY State__c
      ,County__c
	  ,Title_Tracker_Type__c
)
,parcel_info AS
( SELECT
      pip.Parcel_Number
  ,cast(ad.Earliest_Dev_Date as date) AS Earliest_Dev_Date
  ,ad.Devrun_Name                                      AS Earliest_Devrun
  ,ad.WellName                                        AS Earliest_Well
  ,cast(wd.Earliest_Wellbore_Date as date) AS Earliest_Wellbore_Date
  ,wd.Devrun_Name                                      AS Earliest_WB_Devrun
  ,wd.WellName                                    AS Earliest_WB_Well
  ,cast(sd.Earliest_Sandbox_Dev_Date as date) AS Earliest_Sandbox_Dev_Date
  ,sd.Devrun_Name                                      AS Earliest_Sandbox_Devrun
  ,sd.WellName                                        AS Earliest_Sandbox_Well
  ,cast(swd.Earliest_Sandbox_Wellbore_Date as date) AS Earliest_Sandbox_Wellbore_Date
  ,swd.Devrun_Name                                      AS Earliest_Sandbox_WB_Devrun
  ,swd.WellName                                    AS Earliest_Sandbox_WB_Well
      ,  Unmodified_Parcels
    ,Wells
  ,Devruns
  ,HZ_Dates
      ,  Parcel_Acreage
      ,  Split_Parcel_Acreages
      ,  Wellbore_Statuses
/*The below CASE statement is what sets this framework in place:
-Wellbore, greater than 5 - SUTO
-Wellbore, less than 5 - Targeted
-Wellbore Buffer, greater than 5 - SUTO
-Wellbore Buffer, less than 5 - Targeted
-NWB, greater than 5 - SUTA
-NWB, less than 5, leased - Targeted
-NWB, less than 5, unleased - nothing

As a Reminder SUTO = 1, SUTA = 2, Targeted Scope = 3, Nothing = 4
*/
      ,  CASE 
            WHEN pip.Parcel_Number NOT LIKE ('54%') AND Highest_Wellbore_status = 1 AND Parcel_Acreage < 5 THEN '3'
            WHEN pip.Parcel_Number NOT LIKE ('54%') AND Highest_Wellbore_status = 2 AND Parcel_Acreage < 5  THEN '3'
            WHEN Highest_Wellbore_status = 3 AND Parcel_Acreage >= 5  THEN '2'         
            WHEN Highest_Wellbore_status = 3 AND CASE WHEN GIS_Tax_Parcel_Id IS NOT NULL THEN 'Yes' ELSE 'No' END = 'No' THEN '4'
            WHEN Highest_Wellbore_status = 3 AND CASE WHEN GIS_Tax_Parcel_Id IS NOT NULL THEN 'Yes' ELSE 'No' END = 'Yes' THEN '3'
            WHEN Highest_Wellbore_status = 2 THEN '1'
            WHEN Highest_Wellbore_status = 1 THEN '1'
         END AS Title_Needed
      ,  Title_Rank_Available
      ,  Title_Quality
      ,  Title_Tracker_Type
      ,  Certifier
      ,  Title_Tracker_Status
      ,  Cost_Type
      ,  Actual_Title_Cost
      ,  Estimated_Title_Cost
      , efc.Targeted_Scope AS LBF_Targeted_Scope
      , efc.SUAB_Cost AS LBF_SUAB_Cost
      , efc.Upgrade_Cost AS LBF_Upgrade_Cost
      , efc.SUTO_Cost AS LBF_SUTO_Cost
      , sefc.Targeted_Scope AS Sandbox_LBF_Targeted_Scope
      , sefc.SUAB_Cost AS Sandbox_LBF_SUAB_Cost
      , sefc.Upgrade_Cost AS Sandbox_LBF_Upgrade_Cost
      , sefc.SUTO_Cost AS Sandbox_LBF_SUTO_Cost
      , Dollar_Spend_Date
      , CASE
            WHEN GIS_Tax_Parcel_Id IS NOT NULL THEN 'Yes'
            ELSE 'No'
        END AS In_All_Purpose_Table
      FROM parcel_info_pre pip
LEFT JOIN APL ON GIS_Tax_Parcel_Id = Parcel_Number
LEFT JOIN wellbore_dates wd ON wd.Parcel_Number = pip.Parcel_Number AND wd.prod_row = 1
LEFT JOIN wellbore_dates swd ON swd.Parcel_Number = pip.Parcel_Number AND swd.sandbox_row = 1
LEFT JOIN prod_dates ad ON ad.Parcel_Number = pip.Parcel_Number AND ad.row = 1
LEFT JOIN sandbox_dates sd ON sd.Parcel_Number = pip.Parcel_Number AND sd.row = 1
LEFT JOIN est_fut_cost efc ON 
        CASE 
            WHEN pip.Parcel_Number LIKE ('42-%') THEN 'PA' 
            WHEN pip.Parcel_Number LIKE ('54-%') THEN 'WV'
            WHEN pip.Parcel_Number LIKE ('39-%') THEN 'OH'
            END = efc.State 
        and	
        CASE 
            WHEN pip.Parcel_Number LIKE ('42-003-%') THEN 'Allegheny' 
            WHEN pip.Parcel_Number LIKE ('42-051-%') THEN 'Fayette' 
            WHEN pip.Parcel_Number LIKE ('42-059-%') THEN 'Greene' 
            WHEN pip.Parcel_Number LIKE ('42-081-%') THEN 'Lycoming' 
            WHEN pip.Parcel_Number LIKE ('42-113-%') THEN 'Sullivan' 
            WHEN pip.Parcel_Number LIKE ('42-125-%') THEN 'Washington' 
            WHEN pip.Parcel_Number LIKE ('42-129-%') THEN 'Westmoreland' 
            WHEN pip.Parcel_Number LIKE ('54-049-%') THEN 'Marion'
            WHEN pip.Parcel_Number LIKE ('54-051-%') THEN 'Marshall'
            WHEN pip.Parcel_Number LIKE ('54-061-%') THEN 'Monongalia'
            WHEN pip.Parcel_Number LIKE ('54-103-%') THEN 'Wetzel'
            WHEN pip.Parcel_Number LIKE ('39-013-%') THEN 'Belmont'
            WHEN pip.Parcel_Number LIKE ('54-033-%') THEN 'Harrison'
            WHEN pip.Parcel_Number LIKE ('42-035-%') THEN 'Clinton'
            WHEN pip.Parcel_Number LIKE ('54-017-%') THEN 'Doddridge'
            WHEN pip.Parcel_Number LIKE ('54-095-%') THEN 'Tyler'
            WHEN pip.Parcel_Number LIKE ('39-111%') THEN 'Monroe'
            END = efc.County
        and efc.Business_Plan_Year = YEAR(ad.Earliest_Dev_Date)
LEFT JOIN est_fut_cost sefc ON 
        CASE 
            WHEN pip.Parcel_Number LIKE ('42-%') THEN 'PA' 
            WHEN pip.Parcel_Number LIKE ('54-%') THEN 'WV'
            WHEN pip.Parcel_Number LIKE ('39-%') THEN 'OH'
            END = sefc.State 
        and	
        CASE 
            WHEN pip.Parcel_Number LIKE ('42-003-%') THEN 'Allegheny' 
            WHEN pip.Parcel_Number LIKE ('42-051-%') THEN 'Fayette' 
            WHEN pip.Parcel_Number LIKE ('42-059-%') THEN 'Greene' 
            WHEN pip.Parcel_Number LIKE ('42-081-%') THEN 'Lycoming' 
            WHEN pip.Parcel_Number LIKE ('42-113-%') THEN 'Sullivan' 
            WHEN pip.Parcel_Number LIKE ('42-125-%') THEN 'Washington' 
            WHEN pip.Parcel_Number LIKE ('42-129-%') THEN 'Westmoreland' 
            WHEN pip.Parcel_Number LIKE ('54-049-%') THEN 'Marion'
            WHEN pip.Parcel_Number LIKE ('54-051-%') THEN 'Marshall'
            WHEN pip.Parcel_Number LIKE ('54-061-%') THEN 'Monongalia'
            WHEN pip.Parcel_Number LIKE ('54-103-%') THEN 'Wetzel'
            WHEN pip.Parcel_Number LIKE ('39-013-%') THEN 'Belmont'
            WHEN pip.Parcel_Number LIKE ('54-033-%') THEN 'Harrison'
            WHEN pip.Parcel_Number LIKE ('42-035-%') THEN 'Clinton'
            WHEN pip.Parcel_Number LIKE ('54-017-%') THEN 'Doddridge'
            WHEN pip.Parcel_Number LIKE ('54-095-%') THEN 'Tyler'
            WHEN pip.Parcel_Number LIKE ('39-111%') THEN 'Monroe'
            END = sefc.County
        and sefc.Business_Plan_Year = YEAR(sd.Earliest_Sandbox_Dev_Date)
)
,results AS (
SELECT
   CASE WHEN parcel_info.Parcel_Number LIKE ('42-%') THEN 'PA' 
        WHEN parcel_info.Parcel_Number LIKE ('54-%') THEN 'WV'
        WHEN parcel_info.Parcel_Number LIKE ('39-%') THEN 'OH'
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
        WHEN parcel_info.Parcel_Number LIKE ('54-017-%') THEN 'Doddridge'
        WHEN parcel_info.Parcel_Number LIKE ('54-095-%') THEN 'Tyler'
        WHEN parcel_info.Parcel_Number LIKE ('39-111%') THEN 'Monroe'
   END AS County
  ,parcel_info.Parcel_Number
  ,Wellbore_Statuses
  ,cast(Parcel_Acreage as float) AS Parcel_Acreage
  ,Split_Parcel_Acreages
  ,Title_Needed
  ,Title_Rank_Available
  ,  Title_Quality
  ,  Title_Tracker_Type
  ,  Certifier
  ,  Title_Tracker_Status
  ,Unmodified_Parcels
  ,Wells
  ,Devruns
  ,CASE 
        WHEN YEAR(Earliest_Dev_Date) <= 2021 THEN YEAR(Earliest_Dev_Date)
        WHEN YEAR(Earliest_Dev_Date) <= 2024 THEN 2022
        ELSE YEAR(DATEADD(year, -3, Earliest_Dev_Date))
  END           AS Business_Plan_Year
  ,CASE 
        WHEN YEAR(Earliest_Dev_Date) <= 2021 THEN 1
        WHEN YEAR(Earliest_Dev_Date) <= 2024 THEN 2
        ELSE 3
  END          AS Business_Plan_Year_Formula_Checker
  ,HZ_Dates
  ,Earliest_Dev_Date
  ,Earliest_Devrun
  ,Earliest_Well
  ,Earliest_Wellbore_Date
  ,Earliest_WB_Devrun
  ,Earliest_WB_Well
  ,Dollar_Spend_Date 
  ,Earliest_Sandbox_Dev_Date
  ,Earliest_Sandbox_Devrun
  ,Earliest_Sandbox_Well
  ,Earliest_Sandbox_Wellbore_Date
  ,Earliest_Sandbox_WB_Devrun
  ,Earliest_Sandbox_WB_Well
  ,CASE WHEN Title_Needed >= Title_Rank_Available THEN 'No Title Needed'
        WHEN Title_Needed = '1' AND Title_Rank_Available = '2' THEN 'Upgrade Abstract to Opinion'
        WHEN Title_Needed = '1' AND (Title_Rank_Available > '1' OR Title_Rank_Available IS NULL) THEN 'Order Standup Opinion'
        WHEN Title_Needed = '2' AND (Title_Rank_Available > '2' OR Title_Rank_Available IS NULL) THEN 'Order Standup Abstract'
        WHEN Title_Needed = '3' AND (Title_Rank_Available > '3' OR Title_Rank_Available IS NULL) THEN 'Order Targeted Scope Abstract'
        WHEN Title_Needed = '4' THEN 'No Title Needed'
        WHEN Title_Needed = '6' AND Title_Rank_Available = '1' THEN 'No Title Needed'
        WHEN Title_Needed = '5' AND Title_Rank_Available = '1' THEN 'No Title Needed'
        WHEN Title_Needed = '6' AND Title_Rank_Available = '2' THEN 'No Title Needed'
        WHEN Title_Needed = '5' AND Title_Rank_Available = '2' THEN 'No Title Needed'
        WHEN Title_Needed = '6' AND Title_Rank_Available = '3' THEN 'No Title Needed'
        WHEN Title_Needed = '5' AND Title_Rank_Available = '3' THEN 'No Title Needed'
        WHEN Title_Needed = '2' AND Title_Rank_Available = '1' THEN 'No Title Needed'
        WHEN Title_Needed = '3' AND Title_Rank_Available = '1' THEN 'No Title Needed'
        WHEN Title_Needed = '3' AND Title_Rank_Available = '2' THEN 'No Title Needed'
        WHEN Title_Needed = '1' AND Title_Rank_Available = '2' THEN 'Upgrade abstract to opinion'
        WHEN Title_Needed = '2' AND Title_Rank_Available = '3' THEN 'Order Standup Abstract'
        WHEN Title_Needed = '2' AND Title_Rank_Available = '4' THEN 'Order Standup Abstract'
        WHEN Title_Needed = '1' AND Title_Rank_Available IS NULL THEN 'Order Standup Opinion'
        WHEN Title_Needed = '1' AND Title_Rank_Available = '3' THEN 'Order Standup Opinion'
        WHEN Title_Needed = '1' AND Title_Rank_Available = '4' THEN 'Order Standup Opinion'
        WHEN Title_Needed = '2' AND Title_Rank_Available IS NULL THEN 'Order Standup Abstract'
        WHEN Title_Needed = '3' AND Title_Rank_Available = '4' THEN 'Order Targeted Scope'
        WHEN Title_Needed = '3' AND Title_Rank_Available IS NULL THEN 'Order Targeted Scope'
        WHEN Title_Needed = '3' AND Title_Rank_Available = '1' THEN 'No Title Needed'
        WHEN Title_Needed = '3' AND Title_Rank_Available = '2' THEN 'No Title Needed'
        ELSE 'I missed a combination of Title_Needed and Title_Rank_Available'
   END AS Title_Order_Action
   , CASE WHEN Title_Needed >= Title_Rank_Available THEN 'None'
        WHEN Title_Needed = '1' AND Title_Rank_Available = '2' THEN 'Upgrade'
        WHEN Title_Needed = '1' AND (Title_Rank_Available > '1' OR Title_Rank_Available IS NULL) THEN 'New'
        WHEN Title_Needed = '2' AND (Title_Rank_Available > '2' OR Title_Rank_Available IS NULL) THEN 'New'
        WHEN Title_Needed = '3' AND (Title_Rank_Available > '3' OR Title_Rank_Available IS NULL) THEN 'New'
        WHEN Title_Needed = '4' THEN 'Do not order'
        WHEN Title_Needed = '6' AND Title_Rank_Available = '1' THEN 'None'
        WHEN Title_Needed = '5' AND Title_Rank_Available = '1' THEN 'None'
        WHEN Title_Needed = '6' AND Title_Rank_Available = '2' THEN 'None'
        WHEN Title_Needed = '5' AND Title_Rank_Available = '2' THEN 'None'
        WHEN Title_Needed = '6' AND Title_Rank_Available = '3' THEN 'None'
        WHEN Title_Needed = '5' AND Title_Rank_Available = '3' THEN 'None'
        WHEN Title_Needed = '2' AND Title_Rank_Available = '1' THEN 'None'
        WHEN Title_Needed = '3' AND Title_Rank_Available = '1' THEN 'None'
        WHEN Title_Needed = '3' AND Title_Rank_Available = '2' THEN 'None'
        WHEN Title_Needed = '1' AND Title_Rank_Available = '2' THEN 'Upgrade'
        WHEN Title_Needed = '2' AND Title_Rank_Available = '3' THEN 'New'
        WHEN Title_Needed = '2' AND Title_Rank_Available = '4' THEN 'New'
        WHEN Title_Needed = '1' AND Title_Rank_Available IS NULL THEN 'New'
        WHEN Title_Needed = '1' AND Title_Rank_Available = '3' THEN 'New'
        WHEN Title_Needed = '1' AND Title_Rank_Available = '4' THEN 'New'
        WHEN Title_Needed = '2' AND Title_Rank_Available IS NULL THEN 'New'
        WHEN Title_Needed = '3' AND Title_Rank_Available = '4' THEN 'New'
        WHEN Title_Needed = '3' AND Title_Rank_Available IS NULL THEN 'New'
        WHEN Title_Needed = '3' AND Title_Rank_Available = '1' THEN 'None'
        WHEN Title_Needed = '3' AND Title_Rank_Available = '2' THEN 'None'
        ELSE 'I missed a combination of Title_Needed and Title_Rank_Available'
   END AS Title_Order_Action_Macro
   , LBF_Upgrade_Cost
   , LBF_SUTO_Cost
   , LBF_SUAB_Cost
   , LBF_Targeted_Scope
   , Sandbox_LBF_Targeted_Scope
   , Sandbox_LBF_SUAB_Cost
   , Sandbox_LBF_Upgrade_Cost
   , Sandbox_LBF_SUTO_Cost
   , CASE WHEN Cost_Type = 'In-flight' OR Cost_Type = 'Incurred' THEN Cost_Type
          WHEN Cost_Type IS NULL THEN 'Projected'
            ELSE 'Projected'
        END AS Cost_Type
  ,CASE WHEN (Cost_Type <> 'Incurred' AND Cost_Type <> 'In-flight' OR Cost_Type IS NULL)
        THEN CASE 
            WHEN Title_Needed >= Title_Rank_Available THEN 00.00
            WHEN Title_Needed = '1' AND Title_Rank_Available = '2' THEN LBF_Upgrade_Cost
            WHEN Title_Needed = '1' AND (Title_Rank_Available > '1' OR Title_Rank_Available IS NULL) THEN LBF_SUTO_Cost
            WHEN Title_Needed = '2' AND (Title_Rank_Available > '2' OR Title_Rank_Available IS NULL) THEN LBF_SUAB_Cost
            WHEN Title_Needed = '3' AND (Title_Rank_Available > '3' OR Title_Rank_Available IS NULL) THEN LBF_Targeted_Scope
            WHEN Title_Needed = '4' THEN 00.00
            ELSE 00.00
            END
        ELSE 00.00
   END AS Projected_Costs
   , CASE WHEN Title_Needed >= Title_Rank_Available AND Cost_Type = 'In-flight' THEN
     CASE WHEN Estimated_Title_Cost IS NOT NULL THEN Estimated_Title_Cost
          WHEN Title_Needed = '1' AND Title_Rank_Available = '2' THEN LBF_Upgrade_Cost
          WHEN Title_Needed = '1' AND (Title_Rank_Available > '1' OR Title_Rank_Available IS NULL) THEN LBF_SUTO_Cost
          WHEN Title_Needed = '2' AND (Title_Rank_Available > '2' OR Title_Rank_Available IS NULL) THEN LBF_SUAB_Cost
          WHEN Title_Needed = '3' AND (Title_Rank_Available > '3' OR Title_Rank_Available IS NULL) THEN LBF_Targeted_Scope
        END
        ELSE 00.00
    END AS In_flight_Costs
   , CASE WHEN Title_Needed >= Title_Rank_Available AND Cost_Type = 'Incurred' THEN
     CASE WHEN Actual_Title_Cost IS NOT NULL THEN Actual_Title_Cost
          WHEN Title_Needed = '1' AND Title_Rank_Available = '2' THEN LBF_Upgrade_Cost
          WHEN Title_Needed = '1' AND (Title_Rank_Available > '1' OR Title_Rank_Available IS NULL) THEN LBF_SUTO_Cost
          WHEN Title_Needed = '2' AND (Title_Rank_Available > '2' OR Title_Rank_Available IS NULL) THEN LBF_SUAB_Cost
          WHEN Title_Needed = '3' AND (Title_Rank_Available > '3' OR Title_Rank_Available IS NULL) THEN LBF_Targeted_Scope
        END  
        ELSE 00.00
    END AS Incurred_Title_Costs
    ,CASE 
            
            WHEN Cost_Type = 'In-flight' AND Actual_Title_Cost IS NOT NULL THEN Actual_Title_Cost
            WHEN Cost_Type = 'In-flight' AND Estimated_Title_Cost IS NOT NULL THEN Estimated_Title_Cost
            WHEN Cost_Type = 'Incurred' AND Actual_Title_Cost IS NOT NULL THEN Actual_Title_Cost
            WHEN Cost_Type = 'Incurred' AND Estimated_Title_Cost IS NOT NULL THEN Estimated_Title_Cost
            ELSE CASE 
                    WHEN Title_Needed >= Title_Rank_Available THEN 00.00
                    WHEN Title_Needed = '1' AND Title_Rank_Available = '2' THEN LBF_Upgrade_Cost
                    WHEN Title_Needed = '1' AND (Title_Rank_Available > '1' OR Title_Rank_Available IS NULL) THEN LBF_SUTO_Cost
                    WHEN Title_Needed = '2' AND (Title_Rank_Available > '2' OR Title_Rank_Available IS NULL) THEN LBF_SUAB_Cost
                    WHEN Title_Needed = '3' AND (Title_Rank_Available > '3' OR Title_Rank_Available IS NULL) THEN LBF_Targeted_Scope
                    WHEN Title_Needed = '4' THEN 00.00
                    ELSE 00.00
                    END
    END AS Consolidated_Costs
    ,Actual_Title_Cost
    ,Estimated_Title_Cost
    ,In_All_Purpose_Table
    , bw.Title_Workflow_Status__c AS WRP_Status
    , bw.Title_Workflow_Rank
FROM parcel_info
LEFT JOIN BEST_WRP bw ON bw.Parcel_Number = parcel_info.Parcel_Number
--WHERE Earliest_Dev_Date IS NOT NULL OR Earliest_Sandbox_Dev_Date IS NOT NULL --AND Unmodified_Parcels LIKE '%[_]%'
)
, has_nulls AS
(
SELECT 
Parcel_Number
,MIN(State) AS State
,MIN(County) AS County
,MIN(Wellbore_Statuses) AS Wellbore_Statuses
,MIN(Parcel_Acreage) AS Parcel_Acreage
,MIN(Split_Parcel_Acreages) AS Split_Parcel_Acreages
,MIN(Title_Needed) AS Title_Needed
,MIN(Title_Rank_Available) AS Title_Rank_Available
,MIN(Title_Quality) AS Title_Quality
,MIN(Title_Tracker_Type) AS Title_Tracker_Type
,MIN(Certifier) AS Certifier
,MIN(Title_Tracker_Status) AS Title_Tracker_Status
,MIN(Unmodified_Parcels) AS Unmodified_Parcels
,MIN(Wells) AS Wells
,MIN(Devruns) AS Devruns
,MIN(Business_Plan_Year) AS Business_Plan_Year
,MIN(Business_Plan_Year_Formula_Checker) AS Business_Plan_Year_Formula_Checker
,MIN(HZ_Dates) AS HZ_Dates
,MIN(Earliest_Dev_Date) AS Earliest_Dev_Date
,MIN(Earliest_Devrun) AS Earliest_Devrun
,MIN(Earliest_Well) AS Earliest_Well
,MIN(Earliest_Wellbore_Date) AS Earliest_Wellbore_Date
,MIN(Earliest_WB_Devrun) AS Earliest_WB_Devrun
,MIN(Earliest_WB_Well) AS Earliest_WB_Well
,MIN(Earliest_Sandbox_Dev_Date) AS Earliest_Sandbox_Dev_Date
,MIN(Earliest_Sandbox_Devrun) AS Earliest_Sandbox_Devrun
,MIN(Earliest_Sandbox_Well) AS Earliest_Sandbox_Well
,MIN(Earliest_Sandbox_Wellbore_Date) AS Earliest_Sandbox_Wellbore_Date
,MIN(Earliest_Sandbox_WB_Devrun) AS Earliest_Sandbox_WB_Devrun
,MIN(Earliest_Sandbox_WB_Well) AS Earliest_Sandbox_WB_Well
,MIN(Title_Order_Action) AS Title_Order_Action
,MIN(Title_Order_Action_Macro) AS Title_Order_Action_Macro
,MIN(FORMAT(cast(LBF_Upgrade_Cost as float), '.00')) AS LBF_Upgrade_Cost
,MIN(FORMAT(cast(LBF_SUTO_Cost as float), '.00')) AS LBF_SUTO_Cost
,MIN(FORMAT(cast(LBF_SUAB_Cost as float), '.00')) AS LBF_SUAB_Cost
,MIN(FORMAT(cast(LBF_Targeted_Scope as float), '.00')) AS LBF_Targeted_Scope
,MIN(FORMAT(cast(Sandbox_LBF_Targeted_Scope as float), '.00')) AS Sandbox_LBF_Targeted_Scope
,MIN(FORMAT(cast(Sandbox_LBF_SUAB_Cost as float), '.00')) AS Sandbox_LBF_SUAB_Cost
,MIN(FORMAT(cast(Sandbox_LBF_Upgrade_Cost as float), '.00')) AS Sandbox_LBF_Upgrade_Cost
,MIN(FORMAT(cast(Sandbox_LBF_SUTO_Cost as float), '.00')) AS Sandbox_LBF_SUTO_Cost
,MIN(CASE WHEN Cost_Type IN ('Incurred','In-flight') AND Title_Order_Action_Macro <> 'None' THEN 'Projected' ELSE Cost_Type END) AS Cost_Type
,MIN(FORMAT(cast(Projected_Costs as float), '.00')) AS Projected_Costs
,MIN(FORMAT(cast(In_flight_Costs as float), '.00')) AS In_flight_Costs
,MIN(FORMAT(cast(Incurred_Title_Costs as float), '.00')) AS Paid_Title_Costs
,MIN(FORMAT(cast(Consolidated_Costs as float), '.00')) AS Consolidated_Costs
,MIN(Dollar_Spend_Date) AS Dollar_Spend_Date
,YEAR(MIN(Dollar_Spend_Date)) AS Dollar_Spend_Date_Year
,MIN(Actual_Title_Cost) AS Actual_Title_Cost
,MIN(Estimated_Title_Cost) AS Estimated_Title_Cost
,MIN(In_All_Purpose_Table) AS In_All_Purpose_Table
,MIN(WRP_Status) AS WRP_Status
,MIN(Title_Workflow_Rank) AS Title_Workflow_Rank
FROM results 
GROUP BY 
    Parcel_Number
)
,  current_reduced AS
(
SELECT 
ISNULL(Parcel_Number, 'BLANK') AS Parcel_Number
,ISNULL(State, 'BLANK') AS State
,ISNULL(County, 'BLANK') AS County
,ISNULL(Wellbore_Statuses, 'BLANK') AS Wellbore_Statuses
,ISNULL(Parcel_Acreage, 0.00) AS Parcel_Acreage
,ISNULL(Split_Parcel_Acreages, 'BLANK') AS Split_Parcel_Acreages
,ISNULL(Title_Needed, 'BLANK') AS Title_Needed
,ISNULL(Title_Rank_Available, 'BLANK') AS Title_Rank_Available
,ISNULL(Title_Quality, 'BLANK') AS Title_Quality
,ISNULL(Title_Tracker_Type, 'BLANK') AS Title_Tracker_Type
,ISNULL(Certifier, 'BLANK') AS Certifier
,ISNULL(Title_Tracker_Status, 'BLANK') AS Title_Tracker_Status
,ISNULL(Unmodified_Parcels, 'BLANK') AS Unmodified_Parcels
,ISNULL(Wells, 'BLANK') AS Wells
,ISNULL(Devruns, 'BLANK') AS Devruns
,ISNULL(Business_Plan_Year, 0) AS Business_Plan_Year 
,ISNULL(Business_Plan_Year_Formula_Checker, 0) AS Business_Plan_Year_Formula_Checker 
,ISNULL(HZ_Dates, 'BLANK') AS HZ_Dates
,ISNULL(Earliest_Dev_Date, '1900-01-01') AS Earliest_Dev_Date
,ISNULL(Earliest_Devrun, 'BLANK') AS Earliest_Devrun
,ISNULL(Earliest_Well, 'BLANK') AS Earliest_Well
,ISNULL(Earliest_Wellbore_Date, '1900-01-01') AS Earliest_Wellbore_Date
,ISNULL(Earliest_WB_Devrun, 'BLANK') AS Earliest_WB_Devrun
,ISNULL(Earliest_WB_Well, 'BLANK') AS Earliest_WB_Well
,ISNULL(Earliest_Sandbox_Dev_Date, '1900-01-01') AS Earliest_Sandbox_Dev_Date
,ISNULL(Earliest_Sandbox_Devrun, 'BLANK') AS Earliest_Sandbox_Devrun
,ISNULL(Earliest_Sandbox_Well, 'BLANK') AS Earliest_Sandbox_Well
,ISNULL(Earliest_Sandbox_Wellbore_Date, '1900-01-01') AS Earliest_Sandbox_Wellbore_Date
,ISNULL(Earliest_Sandbox_WB_Devrun, 'BLANK') AS Earliest_Sandbox_WB_Devrun
,ISNULL(Earliest_Sandbox_WB_Well, 'BLANK') AS Earliest_Sandbox_WB_Well
,ISNULL(Title_Order_Action, 'BLANK') AS Title_Order_Action
,ISNULL(Title_Order_Action_Macro, 'BLANK') AS Title_Order_Action_Macro
,ISNULL(LBF_Upgrade_Cost, 0.00) AS LBF_Upgrade_Cost
,ISNULL(LBF_SUTO_Cost, 0.00) AS LBF_SUTO_Cost
,ISNULL(LBF_SUAB_Cost, 0.00) AS LBF_SUAB_Cost
,ISNULL(LBF_Targeted_Scope, 0.00) AS LBF_Targeted_Scope
,ISNULL(Sandbox_LBF_Targeted_Scope, 0.00) AS Sandbox_LBF_Targeted_Scope
,ISNULL(Sandbox_LBF_SUAB_Cost, 0.00) AS Sandbox_LBF_SUAB_Cost
,ISNULL(Sandbox_LBF_Upgrade_Cost, 0.00) AS Sandbox_LBF_Upgrade_Cost
,ISNULL(Sandbox_LBF_SUTO_Cost, 0.00) AS Sandbox_LBF_SUTO_Cost
,ISNULL(Cost_Type, 'BLANK') AS Cost_Type
,ISNULL(Projected_Costs, 0.00) AS Projected_Costs
,ISNULL(In_flight_Costs, 0.00) AS In_flight_Costs
,ISNULL(Paid_Title_Costs, 0.00) AS Paid_Title_Costs
,ISNULL(Consolidated_Costs, 0.00) AS Consolidated_Costs
,ISNULL(
    Dollar_Spend_Date, 
        CASE 
            WHEN DATEADD(day, -1095, Earliest_Dev_Date) < GETDate() THEN GetDate() 
            ELSE DATEADD(day, -1095, Earliest_Dev_Date)
            END) AS Dollar_Spend_Date
,ISNULL(Dollar_Spend_Date_Year, YEAR(ISNULL(Dollar_Spend_Date, CASE WHEN DATEADD(day, -1095, Earliest_Dev_Date) < GETDate() THEN GetDate() ELSE DATEADD(day, -1095, Earliest_Dev_Date)END))) AS Dollar_Spend_Date_Year
,ISNULL(Actual_Title_Cost, 0.00) AS Actual_Title_Cost
,ISNULL(Estimated_Title_Cost, 0.00) AS Estimated_Title_Cost
,ISNULL(In_All_Purpose_Table, 'BLANK') AS In_All_Purpose_Table
,ISNULL(WRP_Status, 'BLANK') AS WRP_Status
,ISNULL(Title_Workflow_Rank, 0) AS Title_Workflow_Rank

FROM has_nulls
)

,parcel_info2 AS
( SELECT
      pip.Parcel_Number
  ,cast(ad.Earliest_Dev_Date as date) AS Earliest_Dev_Date
  ,ad.Devrun_Name                                      AS Earliest_Devrun
  ,ad.WellName                                        AS Earliest_Well
  ,cast(wd.Earliest_Wellbore_Date as date) AS Earliest_Wellbore_Date
  ,wd.Devrun_Name                                      AS Earliest_WB_Devrun
  ,wd.WellName                                    AS Earliest_WB_Well
  ,cast(sd.Earliest_Sandbox_Dev_Date as date) AS Earliest_Sandbox_Dev_Date
  ,sd.Devrun_Name                                      AS Earliest_Sandbox_Devrun
  ,sd.WellName                                        AS Earliest_Sandbox_Well
  ,cast(swd.Earliest_Sandbox_Wellbore_Date as date) AS Earliest_Sandbox_Wellbore_Date
  ,swd.Devrun_Name                                      AS Earliest_Sandbox_WB_Devrun
  ,swd.WellName                                    AS Earliest_Sandbox_WB_Well
      ,  Unmodified_Parcels
    ,Wells
  ,Devruns
  ,HZ_Dates
      ,  Parcel_Acreage
      ,  Split_Parcel_Acreages
      ,  Wellbore_Statuses
/*The below CASE statement eliminates the limited ordering scope from above

As a Reminder SUTO = 1, SUTA = 2, Targeted Scope = 3, Nothing = 4
*/
      ,  CASE 
            WHEN Highest_Wellbore_status = 3 THEN '2'         
            WHEN Highest_Wellbore_status = 2 THEN '1'
            WHEN Highest_Wellbore_status = 1 THEN '1'
         END AS Title_Needed
      ,  Title_Rank_Available
      ,  Title_Quality
      ,  Title_Tracker_Type
      ,  Certifier
      ,  Title_Tracker_Status
      ,  Cost_Type
      ,  Actual_Title_Cost
      ,  Estimated_Title_Cost
      , efc.Targeted_Scope AS LBF_Targeted_Scope
      , efc.SUAB_Cost AS LBF_SUAB_Cost
      , efc.Upgrade_Cost AS LBF_Upgrade_Cost
      , efc.SUTO_Cost AS LBF_SUTO_Cost
      , sefc.Targeted_Scope AS Sandbox_LBF_Targeted_Scope
      , sefc.SUAB_Cost AS Sandbox_LBF_SUAB_Cost
      , sefc.Upgrade_Cost AS Sandbox_LBF_Upgrade_Cost
      , sefc.SUTO_Cost AS Sandbox_LBF_SUTO_Cost
      , Dollar_Spend_Date
      , CASE
            WHEN GIS_Tax_Parcel_Id IS NOT NULL THEN 'Yes'
            ELSE 'No'
        END AS In_All_Purpose_Table
      FROM parcel_info_pre pip
LEFT JOIN APL ON GIS_Tax_Parcel_Id = Parcel_Number
LEFT JOIN wellbore_dates wd ON wd.Parcel_Number = pip.Parcel_Number AND wd.prod_row = 1
LEFT JOIN wellbore_dates swd ON swd.Parcel_Number = pip.Parcel_Number AND swd.sandbox_row = 1
LEFT JOIN prod_dates ad ON ad.Parcel_Number = pip.Parcel_Number AND ad.row = 1
LEFT JOIN sandbox_dates sd ON sd.Parcel_Number = pip.Parcel_Number AND sd.row = 1
LEFT JOIN est_fut_cost efc ON 
        CASE 
            WHEN pip.Parcel_Number LIKE ('42-%') THEN 'PA' 
            WHEN pip.Parcel_Number LIKE ('54-%') THEN 'WV'
            WHEN pip.Parcel_Number LIKE ('39-%') THEN 'OH'
            END = efc.State 
        and	
        CASE 
            WHEN pip.Parcel_Number LIKE ('42-003-%') THEN 'Allegheny' 
            WHEN pip.Parcel_Number LIKE ('42-051-%') THEN 'Fayette' 
            WHEN pip.Parcel_Number LIKE ('42-059-%') THEN 'Greene' 
            WHEN pip.Parcel_Number LIKE ('42-081-%') THEN 'Lycoming' 
            WHEN pip.Parcel_Number LIKE ('42-113-%') THEN 'Sullivan' 
            WHEN pip.Parcel_Number LIKE ('42-125-%') THEN 'Washington' 
            WHEN pip.Parcel_Number LIKE ('42-129-%') THEN 'Westmoreland' 
            WHEN pip.Parcel_Number LIKE ('54-049-%') THEN 'Marion'
            WHEN pip.Parcel_Number LIKE ('54-051-%') THEN 'Marshall'
            WHEN pip.Parcel_Number LIKE ('54-061-%') THEN 'Monongalia'
            WHEN pip.Parcel_Number LIKE ('54-103-%') THEN 'Wetzel'
            WHEN pip.Parcel_Number LIKE ('39-013-%') THEN 'Belmont'
            WHEN pip.Parcel_Number LIKE ('54-033-%') THEN 'Harrison'
            WHEN pip.Parcel_Number LIKE ('42-035-%') THEN 'Clinton'
            WHEN pip.Parcel_Number LIKE ('54-017-%') THEN 'Doddridge'
            END = efc.County
        and efc.Business_Plan_Year = YEAR(ad.Earliest_Dev_Date)
LEFT JOIN est_fut_cost sefc ON 
        CASE 
            WHEN pip.Parcel_Number LIKE ('42-%') THEN 'PA' 
            WHEN pip.Parcel_Number LIKE ('54-%') THEN 'WV'
            WHEN pip.Parcel_Number LIKE ('39-%') THEN 'OH'
            END = efc.State 
        and	
        CASE 
            WHEN pip.Parcel_Number LIKE ('42-003-%') THEN 'Allegheny' 
            WHEN pip.Parcel_Number LIKE ('42-051-%') THEN 'Fayette' 
            WHEN pip.Parcel_Number LIKE ('42-059-%') THEN 'Greene' 
            WHEN pip.Parcel_Number LIKE ('42-081-%') THEN 'Lycoming' 
            WHEN pip.Parcel_Number LIKE ('42-113-%') THEN 'Sullivan' 
            WHEN pip.Parcel_Number LIKE ('42-125-%') THEN 'Washington' 
            WHEN pip.Parcel_Number LIKE ('42-129-%') THEN 'Westmoreland' 
            WHEN pip.Parcel_Number LIKE ('54-049-%') THEN 'Marion'
            WHEN pip.Parcel_Number LIKE ('54-051-%') THEN 'Marshall'
            WHEN pip.Parcel_Number LIKE ('54-061-%') THEN 'Monongalia'
            WHEN pip.Parcel_Number LIKE ('54-103-%') THEN 'Wetzel'
            WHEN pip.Parcel_Number LIKE ('39-013-%') THEN 'Belmont'
            WHEN pip.Parcel_Number LIKE ('54-033-%') THEN 'Harrison'
            WHEN pip.Parcel_Number LIKE ('42-035-%') THEN 'Clinton'
            WHEN pip.Parcel_Number LIKE ('54-017-%') THEN 'Doddridge'
            END = efc.County
        and sefc.Business_Plan_Year = YEAR(sd.Earliest_Sandbox_Dev_Date)
)
,results2 AS (
SELECT
   CASE WHEN parcel_info.Parcel_Number LIKE ('42-%') THEN 'PA' 
        WHEN parcel_info.Parcel_Number LIKE ('54-%') THEN 'WV'
        WHEN parcel_info.Parcel_Number LIKE ('39-%') THEN 'OH'
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
        WHEN parcel_info.Parcel_Number LIKE ('54-017-%') THEN 'Doddridge'
   END AS County
  ,parcel_info.Parcel_Number
  ,Wellbore_Statuses
  ,cast(Parcel_Acreage as float) AS Parcel_Acreage
  ,Split_Parcel_Acreages
  ,Title_Needed
  ,Title_Rank_Available
  ,  Title_Quality
  ,  Title_Tracker_Type
  ,  Certifier
  ,  Title_Tracker_Status
  ,Unmodified_Parcels
  ,Wells
  ,Devruns
  ,CASE 
        WHEN YEAR(Earliest_Dev_Date) <= 2021 THEN YEAR(Earliest_Dev_Date)
        WHEN YEAR(Earliest_Dev_Date) <= 2024 THEN 2022
        ELSE YEAR(DATEADD(year, -3, Earliest_Dev_Date))
  END            Business_Plan_Year
  ,CASE 
        WHEN YEAR(Earliest_Dev_Date) <= 2021 THEN 1
        WHEN YEAR(Earliest_Dev_Date) <= 2024 THEN 2
        ELSE 3
  END          AS Business_Plan_Year_Formula_Checker
  ,HZ_Dates
  ,Earliest_Dev_Date
  ,Earliest_Devrun
  ,Earliest_Well
  ,Earliest_Wellbore_Date
  ,Earliest_WB_Devrun
  ,Earliest_WB_Well
  ,Dollar_Spend_Date 
  ,Earliest_Sandbox_Dev_Date
  ,Earliest_Sandbox_Devrun
  ,Earliest_Sandbox_Well
  ,Earliest_Sandbox_Wellbore_Date
  ,Earliest_Sandbox_WB_Devrun
  ,Earliest_Sandbox_WB_Well
  ,CASE WHEN Title_Needed >= Title_Rank_Available THEN 'No Title Needed'
        WHEN Title_Needed = '1' AND Title_Rank_Available = '2' THEN 'Upgrade Abstract to Opinion'
        WHEN Title_Needed = '1' AND (Title_Rank_Available > '1' OR Title_Rank_Available IS NULL) THEN 'Order Standup Opinion'
        WHEN Title_Needed = '2' AND (Title_Rank_Available > '2' OR Title_Rank_Available IS NULL) THEN 'Order Standup Abstract'
        WHEN Title_Needed = '3' AND (Title_Rank_Available > '3' OR Title_Rank_Available IS NULL) THEN 'Order Targeted Scope Abstract'
        WHEN Title_Needed = '2' AND Title_Rank_Available = '1' THEN 'No Title Needed'
        WHEN Title_Needed = '3' AND Title_Rank_Available = '1' THEN 'No Title Needed'
        WHEN Title_Needed = '3' AND Title_Rank_Available = '2' THEN 'No Title Needed'
        WHEN Title_Needed = '1' AND Title_Rank_Available = '2' THEN 'Upgrade abstract to opinion'
        WHEN Title_Needed = '2' AND Title_Rank_Available = '3' THEN 'Order Standup Abstract'
        WHEN Title_Needed = '2' AND Title_Rank_Available = '4' THEN 'Order Standup Abstract'
        WHEN Title_Needed = '1' AND Title_Rank_Available IS NULL THEN 'Order Standup Opinion'
        WHEN Title_Needed = '1' AND Title_Rank_Available = '3' THEN 'Order Standup Opinion'
        WHEN Title_Needed = '1' AND Title_Rank_Available = '4' THEN 'Order Standup Opinion'
        WHEN Title_Needed = '2' AND Title_Rank_Available IS NULL THEN 'Order Standup Abstract'
        WHEN Title_Needed = '3' AND Title_Rank_Available = '4' THEN 'Order Targeted Scope'
        WHEN Title_Needed = '3' AND Title_Rank_Available IS NULL THEN 'Order Targeted Scope'
        WHEN Title_Needed = '3' AND Title_Rank_Available = '1' THEN 'No Title Needed'
        WHEN Title_Needed = '3' AND Title_Rank_Available = '2' THEN 'No Title Needed'
        ELSE 'I missed a combination of Title_Needed and Title_Rank_Available'
   END AS Title_Order_Action
   , CASE WHEN Title_Needed >= Title_Rank_Available THEN 'None'
        WHEN Title_Needed = '1' AND Title_Rank_Available = '2' THEN 'Upgrade'
        WHEN Title_Needed = '1' AND (Title_Rank_Available > '1' OR Title_Rank_Available IS NULL) THEN 'New'
        WHEN Title_Needed = '2' AND (Title_Rank_Available > '2' OR Title_Rank_Available IS NULL) THEN 'New'
        WHEN Title_Needed = '3' AND (Title_Rank_Available > '3' OR Title_Rank_Available IS NULL) THEN 'New'
        WHEN Title_Needed = '4' THEN 'Do not order'
        WHEN Title_Needed = '6' AND Title_Rank_Available = '1' THEN 'None'
        WHEN Title_Needed = '5' AND Title_Rank_Available = '1' THEN 'None'
        WHEN Title_Needed = '6' AND Title_Rank_Available = '2' THEN 'None'
        WHEN Title_Needed = '5' AND Title_Rank_Available = '2' THEN 'None'
        WHEN Title_Needed = '6' AND Title_Rank_Available = '3' THEN 'None'
        WHEN Title_Needed = '5' AND Title_Rank_Available = '3' THEN 'None'
        WHEN Title_Needed = '2' AND Title_Rank_Available = '1' THEN 'None'
        WHEN Title_Needed = '3' AND Title_Rank_Available = '1' THEN 'None'
        WHEN Title_Needed = '3' AND Title_Rank_Available = '2' THEN 'None'
        WHEN Title_Needed = '1' AND Title_Rank_Available = '2' THEN 'Upgrade'
        WHEN Title_Needed = '2' AND Title_Rank_Available = '3' THEN 'New'
        WHEN Title_Needed = '2' AND Title_Rank_Available = '4' THEN 'New'
        WHEN Title_Needed = '1' AND Title_Rank_Available IS NULL THEN 'New'
        WHEN Title_Needed = '1' AND Title_Rank_Available = '3' THEN 'New'
        WHEN Title_Needed = '1' AND Title_Rank_Available = '4' THEN 'New'
        WHEN Title_Needed = '2' AND Title_Rank_Available IS NULL THEN 'New'
        WHEN Title_Needed = '3' AND Title_Rank_Available = '4' THEN 'New'
        WHEN Title_Needed = '3' AND Title_Rank_Available IS NULL THEN 'New'
        WHEN Title_Needed = '3' AND Title_Rank_Available = '1' THEN 'None'
        WHEN Title_Needed = '3' AND Title_Rank_Available = '2' THEN 'None'
        ELSE 'I missed a combination of Title_Needed and Title_Rank_Available'
   END AS Title_Order_Action_Macro
   , LBF_Upgrade_Cost
   , LBF_SUTO_Cost
   , LBF_SUAB_Cost
   , LBF_Targeted_Scope
   , Sandbox_LBF_Targeted_Scope
   , Sandbox_LBF_SUAB_Cost
   , Sandbox_LBF_Upgrade_Cost
   , Sandbox_LBF_SUTO_Cost
   , CASE WHEN Cost_Type = 'In-flight' OR Cost_Type = 'Incurred' THEN Cost_Type
          WHEN Cost_Type IS NULL THEN 'Projected'
            ELSE 'Projected'
        END AS Cost_Type
  ,CASE WHEN (Cost_Type <> 'Incurred' AND Cost_Type <> 'In-flight' OR Cost_Type IS NULL)
        THEN CASE 
            WHEN Title_Needed >= Title_Rank_Available THEN 00.00
            WHEN Title_Needed = '1' AND Title_Rank_Available = '2' THEN LBF_Upgrade_Cost
            WHEN Title_Needed = '1' AND (Title_Rank_Available > '1' OR Title_Rank_Available IS NULL) THEN LBF_SUTO_Cost
            WHEN Title_Needed = '2' AND (Title_Rank_Available > '2' OR Title_Rank_Available IS NULL) THEN LBF_SUAB_Cost
            WHEN Title_Needed = '3' AND (Title_Rank_Available > '3' OR Title_Rank_Available IS NULL) THEN LBF_Targeted_Scope
            WHEN Title_Needed = '4' THEN 00.00
            ELSE 00.00
            END
        ELSE 00.00
   END AS Projected_Costs
   , CASE WHEN Title_Needed >= Title_Rank_Available AND Cost_Type = 'In-flight' THEN
     CASE WHEN Estimated_Title_Cost IS NOT NULL THEN Estimated_Title_Cost
          WHEN Title_Needed = '1' AND Title_Rank_Available = '2' THEN LBF_Upgrade_Cost
          WHEN Title_Needed = '1' AND (Title_Rank_Available > '1' OR Title_Rank_Available IS NULL) THEN LBF_SUTO_Cost
          WHEN Title_Needed = '2' AND (Title_Rank_Available > '2' OR Title_Rank_Available IS NULL) THEN LBF_SUAB_Cost
          WHEN Title_Needed = '3' AND (Title_Rank_Available > '3' OR Title_Rank_Available IS NULL) THEN LBF_Targeted_Scope
        END
        ELSE 00.00
    END AS In_flight_Costs
   , CASE WHEN Title_Needed >= Title_Rank_Available AND Cost_Type = 'Incurred' THEN
     CASE WHEN Actual_Title_Cost IS NOT NULL THEN Actual_Title_Cost
          WHEN Title_Needed = '1' AND Title_Rank_Available = '2' THEN LBF_Upgrade_Cost
          WHEN Title_Needed = '1' AND (Title_Rank_Available > '1' OR Title_Rank_Available IS NULL) THEN LBF_SUTO_Cost
          WHEN Title_Needed = '2' AND (Title_Rank_Available > '2' OR Title_Rank_Available IS NULL) THEN LBF_SUAB_Cost
          WHEN Title_Needed = '3' AND (Title_Rank_Available > '3' OR Title_Rank_Available IS NULL) THEN LBF_Targeted_Scope
        END  
        ELSE 00.00
    END AS Incurred_Title_Costs
    ,CASE 
            WHEN Cost_Type = 'In-flight' AND Actual_Title_Cost IS NOT NULL THEN Actual_Title_Cost
            WHEN Cost_Type = 'In-flight' AND Estimated_Title_Cost IS NOT NULL THEN Estimated_Title_Cost
            WHEN Cost_Type = 'Incurred' AND Actual_Title_Cost IS NOT NULL THEN Actual_Title_Cost
            WHEN Cost_Type = 'Incurred' AND Estimated_Title_Cost IS NOT NULL THEN Estimated_Title_Cost
            ELSE CASE 
                    WHEN Title_Needed >= Title_Rank_Available THEN 00.00
                    WHEN Title_Needed = '1' AND Title_Rank_Available = '2' THEN LBF_Upgrade_Cost
                    WHEN Title_Needed = '1' AND (Title_Rank_Available > '1' OR Title_Rank_Available IS NULL) THEN LBF_SUTO_Cost
                    WHEN Title_Needed = '2' AND (Title_Rank_Available > '2' OR Title_Rank_Available IS NULL) THEN LBF_SUAB_Cost
                    WHEN Title_Needed = '3' AND (Title_Rank_Available > '3' OR Title_Rank_Available IS NULL) THEN LBF_Targeted_Scope
                    WHEN Title_Needed = '4' THEN 00.00
                    ELSE 00.00
                    END
    END AS Consolidated_Costs
    ,Actual_Title_Cost
    ,Estimated_Title_Cost
    ,In_All_Purpose_Table
    , bw.Title_Workflow_Status__c AS WRP_Status
    , bw.Title_Workflow_Rank
FROM parcel_info2 parcel_info
LEFT JOIN BEST_WRP bw ON bw.Parcel_Number = parcel_info.Parcel_Number
--WHERE Earliest_Dev_Date IS NOT NULL OR Earliest_Sandbox_Dev_Date IS NOT NULL --AND Unmodified_Parcels LIKE '%[_]%'
)
, has_nulls2 AS
(
SELECT 
Parcel_Number
,MIN(State) AS State
,MIN(County) AS County
,MIN(Wellbore_Statuses) AS Wellbore_Statuses
,MIN(Parcel_Acreage) AS Parcel_Acreage
,MIN(Split_Parcel_Acreages) AS Split_Parcel_Acreages
,MIN(Title_Needed) AS Title_Needed
,MIN(Title_Rank_Available) AS Title_Rank_Available
,MIN(Title_Quality) AS Title_Quality
,MIN(Title_Tracker_Type) AS Title_Tracker_Type
,MIN(Certifier) AS Certifier
,MIN(Title_Tracker_Status) AS Title_Tracker_Status
,MIN(Unmodified_Parcels) AS Unmodified_Parcels
,MIN(Wells) AS Wells
,MIN(Devruns) AS Devruns
,MIN(Business_Plan_Year) AS Business_Plan_Year
,MIN(Business_Plan_Year_Formula_Checker) AS Business_Plan_Year_Formula_Checker
,MIN(HZ_Dates) AS HZ_Dates
,MIN(Earliest_Dev_Date) AS Earliest_Dev_Date
,MIN(Earliest_Devrun) AS Earliest_Devrun
,MIN(Earliest_Well) AS Earliest_Well
,MIN(Earliest_Wellbore_Date) AS Earliest_Wellbore_Date
,MIN(Earliest_WB_Devrun) AS Earliest_WB_Devrun
,MIN(Earliest_WB_Well) AS Earliest_WB_Well
,MIN(Earliest_Sandbox_Dev_Date) AS Earliest_Sandbox_Dev_Date
,MIN(Earliest_Sandbox_Devrun) AS Earliest_Sandbox_Devrun
,MIN(Earliest_Sandbox_Well) AS Earliest_Sandbox_Well
,MIN(Earliest_Sandbox_Wellbore_Date) AS Earliest_Sandbox_Wellbore_Date
,MIN(Earliest_Sandbox_WB_Devrun) AS Earliest_Sandbox_WB_Devrun
,MIN(Earliest_Sandbox_WB_Well) AS Earliest_Sandbox_WB_Well
,MIN(Title_Order_Action) AS Title_Order_Action
,MIN(Title_Order_Action_Macro) AS Title_Order_Action_Macro
,MIN(FORMAT(cast(LBF_Upgrade_Cost as float), '.00')) AS LBF_Upgrade_Cost
,MIN(FORMAT(cast(LBF_SUTO_Cost as float), '.00')) AS LBF_SUTO_Cost
,MIN(FORMAT(cast(LBF_SUAB_Cost as float), '.00')) AS LBF_SUAB_Cost
,MIN(FORMAT(cast(LBF_Targeted_Scope as float), '.00')) AS LBF_Targeted_Scope
,MIN(FORMAT(cast(Sandbox_LBF_Targeted_Scope as float), '.00')) AS Sandbox_LBF_Targeted_Scope
,MIN(FORMAT(cast(Sandbox_LBF_SUAB_Cost as float), '.00')) AS Sandbox_LBF_SUAB_Cost
,MIN(FORMAT(cast(Sandbox_LBF_Upgrade_Cost as float), '.00')) AS Sandbox_LBF_Upgrade_Cost
,MIN(FORMAT(cast(Sandbox_LBF_SUTO_Cost as float), '.00')) AS Sandbox_LBF_SUTO_Cost
,MIN(CASE WHEN Cost_Type IN ('Incurred','In-flight') AND Title_Order_Action_Macro <> 'None' THEN 'Projected' ELSE Cost_Type END ) AS Cost_Type
,MIN(FORMAT(cast(Projected_Costs as float), '.00')) AS Projected_Costs
,MIN(FORMAT(cast(In_flight_Costs as float), '.00')) AS In_flight_Costs
,MIN(FORMAT(cast(Incurred_Title_Costs as float), '.00')) AS Paid_Title_Costs
,MIN(FORMAT(cast(Consolidated_Costs as float), '.00')) AS Consolidated_Costs
,MIN(Dollar_Spend_Date) AS Dollar_Spend_Date
,YEAR(MIN(Dollar_Spend_Date)) AS Dollar_Spend_Date_Year
,MIN(Actual_Title_Cost) AS Actual_Title_Cost
,MIN(Estimated_Title_Cost) AS Estimated_Title_Cost
,MIN(In_All_Purpose_Table) AS In_All_Purpose_Table
,MIN(WRP_Status) AS WRP_Status
,MIN(Title_Workflow_Rank) AS Title_Workflow_Rank
FROM results2 
GROUP BY 
    Parcel_Number
)
,  Ideal AS
(
SELECT 
ISNULL(Parcel_Number, 'BLANK') AS Parcel_Number
,ISNULL(State, 'BLANK') AS State
,ISNULL(County, 'BLANK') AS County
,ISNULL(Wellbore_Statuses, 'BLANK') AS Wellbore_Statuses
,ISNULL(Parcel_Acreage, 0.00) AS Parcel_Acreage
,ISNULL(Split_Parcel_Acreages, 'BLANK') AS Split_Parcel_Acreages
,ISNULL(Title_Needed, 'BLANK') AS Title_Needed
,ISNULL(Title_Rank_Available, 'BLANK') AS Title_Rank_Available
,ISNULL(Title_Quality, 'BLANK') AS Title_Quality
,ISNULL(Title_Tracker_Type, 'BLANK') AS Title_Tracker_Type
,ISNULL(Certifier, 'BLANK') AS Certifier
,ISNULL(Title_Tracker_Status, 'BLANK') AS Title_Tracker_Status
,ISNULL(Unmodified_Parcels, 'BLANK') AS Unmodified_Parcels
,ISNULL(Wells, 'BLANK') AS Wells
,ISNULL(Devruns, 'BLANK') AS Devruns
,ISNULL(Business_Plan_Year, 0) AS Business_Plan_Year
,ISNULL(Business_Plan_Year_Formula_Checker, 0) AS Business_Plan_Year_Formula_Checker  
,ISNULL(HZ_Dates, 'BLANK') AS HZ_Dates
,ISNULL(Earliest_Dev_Date, '1900-01-01') AS Earliest_Dev_Date
,ISNULL(Earliest_Devrun, 'BLANK') AS Earliest_Devrun
,ISNULL(Earliest_Well, 'BLANK') AS Earliest_Well
,ISNULL(Earliest_Wellbore_Date, '1900-01-01') AS Earliest_Wellbore_Date
,ISNULL(Earliest_WB_Devrun, 'BLANK') AS Earliest_WB_Devrun
,ISNULL(Earliest_WB_Well, 'BLANK') AS Earliest_WB_Well
,ISNULL(Earliest_Sandbox_Dev_Date, '1900-01-01') AS Earliest_Sandbox_Dev_Date
,ISNULL(Earliest_Sandbox_Devrun, 'BLANK') AS Earliest_Sandbox_Devrun
,ISNULL(Earliest_Sandbox_Well, 'BLANK') AS Earliest_Sandbox_Well
,ISNULL(Earliest_Sandbox_Wellbore_Date, '1900-01-01') AS Earliest_Sandbox_Wellbore_Date
,ISNULL(Earliest_Sandbox_WB_Devrun, 'BLANK') AS Earliest_Sandbox_WB_Devrun
,ISNULL(Earliest_Sandbox_WB_Well, 'BLANK') AS Earliest_Sandbox_WB_Well
,ISNULL(Title_Order_Action, 'BLANK') AS Title_Order_Action
,ISNULL(Title_Order_Action_Macro, 'BLANK') AS Title_Order_Action_Macro
,ISNULL(LBF_Upgrade_Cost, 0.00) AS LBF_Upgrade_Cost
,ISNULL(LBF_SUTO_Cost, 0.00) AS LBF_SUTO_Cost
,ISNULL(LBF_SUAB_Cost, 0.00) AS LBF_SUAB_Cost
,ISNULL(LBF_Targeted_Scope, 0.00) AS LBF_Targeted_Scope
,ISNULL(Sandbox_LBF_Targeted_Scope, 0.00) AS Sandbox_LBF_Targeted_Scope
,ISNULL(Sandbox_LBF_SUAB_Cost, 0.00) AS Sandbox_LBF_SUAB_Cost
,ISNULL(Sandbox_LBF_Upgrade_Cost, 0.00) AS Sandbox_LBF_Upgrade_Cost
,ISNULL(Sandbox_LBF_SUTO_Cost, 0.00) AS Sandbox_LBF_SUTO_Cost
,ISNULL(Cost_Type, 'BLANK') AS Cost_Type
,ISNULL(Projected_Costs, 0.00) AS Projected_Costs
,ISNULL(In_flight_Costs, 0.00) AS In_flight_Costs
,ISNULL(Paid_Title_Costs, 0.00) AS Paid_Title_Costs
,ISNULL(cast(Consolidated_Costs as float), 0.00) AS Consolidated_Costs
,ISNULL(
    Dollar_Spend_Date, 
        CASE 
            WHEN DATEADD(day, -1095, Earliest_Dev_Date) < GETDate() THEN GetDate() 
            ELSE DATEADD(day, -1095, Earliest_Dev_Date)
            END) AS Dollar_Spend_Date
,ISNULL(Dollar_Spend_Date_Year, YEAR(ISNULL(Dollar_Spend_Date, CASE WHEN DATEADD(day, -1095, Earliest_Dev_Date) < GETDate() THEN GetDate() ELSE DATEADD(day, -1095, Earliest_Dev_Date)END))) AS Dollar_Spend_Date_Year
,ISNULL(Actual_Title_Cost, 0.00) AS Actual_Title_Cost
,ISNULL(Estimated_Title_Cost, 0.00) AS Estimated_Title_Cost
,ISNULL(In_All_Purpose_Table, 'BLANK') AS In_All_Purpose_Table
,ISNULL(WRP_Status, 'BLANK') AS WRP_Status
,ISNULL(Title_Workflow_Rank, 0) AS Title_Workflow_Rank

FROM has_nulls2
)
,parcel_info3 AS
( SELECT
      pip.Parcel_Number
  ,cast(ad.Earliest_Dev_Date as date) AS Earliest_Dev_Date
  ,ad.Devrun_Name                                      AS Earliest_Devrun
  ,ad.WellName                                        AS Earliest_Well
  ,cast(wd.Earliest_Wellbore_Date as date) AS Earliest_Wellbore_Date
  ,wd.Devrun_Name                                      AS Earliest_WB_Devrun
  ,wd.WellName                                    AS Earliest_WB_Well
  ,cast(sd.Earliest_Sandbox_Dev_Date as date) AS Earliest_Sandbox_Dev_Date
  ,sd.Devrun_Name                                      AS Earliest_Sandbox_Devrun
  ,sd.WellName                                        AS Earliest_Sandbox_Well
  ,cast(swd.Earliest_Sandbox_Wellbore_Date as date) AS Earliest_Sandbox_Wellbore_Date
  ,swd.Devrun_Name                                      AS Earliest_Sandbox_WB_Devrun
  ,swd.WellName                                    AS Earliest_Sandbox_WB_Well
      ,  Unmodified_Parcels
    ,Wells
  ,Devruns
  ,HZ_Dates
      ,  Parcel_Acreage
      ,  Split_Parcel_Acreages
      ,  Wellbore_Statuses
/*The below CASE statement sets up the medium-low ordering model

As a Reminder SUTO = 1, SUTA = 2, Targeted Scope = 3, Nothing = 4
*/
      ,  CASE 
            WHEN Highest_Wellbore_status = 3 THEN '3'
            WHEN Highest_Wellbore_status = 2 and pip.Parcel_Number NOT LIKE ('54%') THEN 3
            WHEN Highest_Wellbore_status = 2 THEN '1'
            WHEN Highest_Wellbore_status = 1 THEN '1'
         END AS Title_Needed
      ,  Title_Rank_Available
      ,  Title_Quality
      ,  Title_Tracker_Type
      ,  Certifier
      ,  Title_Tracker_Status
      ,  Cost_Type
      ,  Actual_Title_Cost
      ,  Estimated_Title_Cost
      , efc.Targeted_Scope AS LBF_Targeted_Scope
      , efc.SUAB_Cost AS LBF_SUAB_Cost
      , efc.Upgrade_Cost AS LBF_Upgrade_Cost
      , efc.SUTO_Cost AS LBF_SUTO_Cost
      , sefc.Targeted_Scope AS Sandbox_LBF_Targeted_Scope
      , sefc.SUAB_Cost AS Sandbox_LBF_SUAB_Cost
      , sefc.Upgrade_Cost AS Sandbox_LBF_Upgrade_Cost
      , sefc.SUTO_Cost AS Sandbox_LBF_SUTO_Cost
      , Dollar_Spend_Date
      , CASE
            WHEN GIS_Tax_Parcel_Id IS NOT NULL THEN 'Yes'
            ELSE 'No'
        END AS In_All_Purpose_Table
      FROM parcel_info_pre pip
LEFT JOIN APL ON GIS_Tax_Parcel_Id = Parcel_Number
LEFT JOIN wellbore_dates wd ON wd.Parcel_Number = pip.Parcel_Number AND wd.prod_row = 1
LEFT JOIN wellbore_dates swd ON swd.Parcel_Number = pip.Parcel_Number AND swd.sandbox_row = 1
LEFT JOIN prod_dates ad ON ad.Parcel_Number = pip.Parcel_Number AND ad.row = 1
LEFT JOIN sandbox_dates sd ON sd.Parcel_Number = pip.Parcel_Number AND sd.row = 1
LEFT JOIN est_fut_cost efc ON 
        CASE 
            WHEN pip.Parcel_Number LIKE ('42-%') THEN 'PA' 
            WHEN pip.Parcel_Number LIKE ('54-%') THEN 'WV'
            WHEN pip.Parcel_Number LIKE ('39-%') THEN 'OH'
            END = efc.State 
        and	
        CASE 
            WHEN pip.Parcel_Number LIKE ('42-003-%') THEN 'Allegheny' 
            WHEN pip.Parcel_Number LIKE ('42-051-%') THEN 'Fayette' 
            WHEN pip.Parcel_Number LIKE ('42-059-%') THEN 'Greene' 
            WHEN pip.Parcel_Number LIKE ('42-081-%') THEN 'Lycoming' 
            WHEN pip.Parcel_Number LIKE ('42-113-%') THEN 'Sullivan' 
            WHEN pip.Parcel_Number LIKE ('42-125-%') THEN 'Washington' 
            WHEN pip.Parcel_Number LIKE ('42-129-%') THEN 'Westmoreland' 
            WHEN pip.Parcel_Number LIKE ('54-049-%') THEN 'Marion'
            WHEN pip.Parcel_Number LIKE ('54-051-%') THEN 'Marshall'
            WHEN pip.Parcel_Number LIKE ('54-061-%') THEN 'Monongalia'
            WHEN pip.Parcel_Number LIKE ('54-103-%') THEN 'Wetzel'
            WHEN pip.Parcel_Number LIKE ('39-013-%') THEN 'Belmont'
            WHEN pip.Parcel_Number LIKE ('54-033-%') THEN 'Harrison'
            WHEN pip.Parcel_Number LIKE ('42-035-%') THEN 'Clinton'
            WHEN pip.Parcel_Number LIKE ('54-017-%') THEN 'Doddridge'
            END = efc.County
        and efc.Business_Plan_Year = YEAR(ad.Earliest_Dev_Date)
LEFT JOIN est_fut_cost sefc ON 
        CASE 
            WHEN pip.Parcel_Number LIKE ('42-%') THEN 'PA' 
            WHEN pip.Parcel_Number LIKE ('54-%') THEN 'WV'
            WHEN pip.Parcel_Number LIKE ('39-%') THEN 'OH'
            END = efc.State 
        and	
        CASE 
            WHEN pip.Parcel_Number LIKE ('42-003-%') THEN 'Allegheny' 
            WHEN pip.Parcel_Number LIKE ('42-051-%') THEN 'Fayette' 
            WHEN pip.Parcel_Number LIKE ('42-059-%') THEN 'Greene' 
            WHEN pip.Parcel_Number LIKE ('42-081-%') THEN 'Lycoming' 
            WHEN pip.Parcel_Number LIKE ('42-113-%') THEN 'Sullivan' 
            WHEN pip.Parcel_Number LIKE ('42-125-%') THEN 'Washington' 
            WHEN pip.Parcel_Number LIKE ('42-129-%') THEN 'Westmoreland' 
            WHEN pip.Parcel_Number LIKE ('54-049-%') THEN 'Marion'
            WHEN pip.Parcel_Number LIKE ('54-051-%') THEN 'Marshall'
            WHEN pip.Parcel_Number LIKE ('54-061-%') THEN 'Monongalia'
            WHEN pip.Parcel_Number LIKE ('54-103-%') THEN 'Wetzel'
            WHEN pip.Parcel_Number LIKE ('39-013-%') THEN 'Belmont'
            WHEN pip.Parcel_Number LIKE ('54-033-%') THEN 'Harrison'
            WHEN pip.Parcel_Number LIKE ('42-035-%') THEN 'Clinton'
            WHEN pip.Parcel_Number LIKE ('54-017-%') THEN 'Doddridge'
            END = efc.County
        and sefc.Business_Plan_Year = YEAR(sd.Earliest_Sandbox_Dev_Date)
)
,results3 AS (
SELECT
   CASE WHEN parcel_info.Parcel_Number LIKE ('42-%') THEN 'PA' 
        WHEN parcel_info.Parcel_Number LIKE ('54-%') THEN 'WV'
        WHEN parcel_info.Parcel_Number LIKE ('39-%') THEN 'OH'
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
        WHEN parcel_info.Parcel_Number LIKE ('54-017-%') THEN 'Doddridge'
   END AS County
  ,parcel_info.Parcel_Number
  ,Wellbore_Statuses
  ,cast(Parcel_Acreage as float) AS Parcel_Acreage
  ,Split_Parcel_Acreages
  ,Title_Needed
  ,Title_Rank_Available
  ,  Title_Quality
  ,  Title_Tracker_Type
  ,  Certifier
  ,  Title_Tracker_Status
  ,Unmodified_Parcels
  ,Wells
  ,Devruns
  ,CASE 
        WHEN YEAR(Earliest_Dev_Date) <= 2021 THEN YEAR(Earliest_Dev_Date)
        WHEN YEAR(Earliest_Dev_Date) <= 2024 THEN 2022
        ELSE YEAR(DATEADD(year, -3, Earliest_Dev_Date))
  END            Business_Plan_Year
  ,CASE 
        WHEN YEAR(Earliest_Dev_Date) <= 2021 THEN 1
        WHEN YEAR(Earliest_Dev_Date) <= 2024 THEN 2
        ELSE 3
  END          AS Business_Plan_Year_Formula_Checker
  ,HZ_Dates
  ,Earliest_Dev_Date
  ,Earliest_Devrun
  ,Earliest_Well
  ,Earliest_Wellbore_Date
  ,Earliest_WB_Devrun
  ,Earliest_WB_Well
  ,Dollar_Spend_Date 
  ,Earliest_Sandbox_Dev_Date
  ,Earliest_Sandbox_Devrun
  ,Earliest_Sandbox_Well
  ,Earliest_Sandbox_Wellbore_Date
  ,Earliest_Sandbox_WB_Devrun
  ,Earliest_Sandbox_WB_Well
  ,CASE WHEN Title_Needed >= Title_Rank_Available THEN 'No Title Needed'
        WHEN Title_Needed = '1' AND Title_Rank_Available = '2' THEN 'Upgrade Abstract to Opinion'
        WHEN Title_Needed = '1' AND (Title_Rank_Available > '1' OR Title_Rank_Available IS NULL) THEN 'Order Standup Opinion'
        WHEN Title_Needed = '2' AND (Title_Rank_Available > '2' OR Title_Rank_Available IS NULL) THEN 'Order Standup Abstract'
        WHEN Title_Needed = '3' AND (Title_Rank_Available > '3' OR Title_Rank_Available IS NULL) THEN 'Order Targeted Scope Abstract'
        WHEN Title_Needed = '2' AND Title_Rank_Available = '1' THEN 'No Title Needed'
        WHEN Title_Needed = '3' AND Title_Rank_Available = '1' THEN 'No Title Needed'
        WHEN Title_Needed = '3' AND Title_Rank_Available = '2' THEN 'No Title Needed'
        WHEN Title_Needed = '1' AND Title_Rank_Available = '2' THEN 'Upgrade abstract to opinion'
        WHEN Title_Needed = '2' AND Title_Rank_Available = '3' THEN 'Order Standup Abstract'
        WHEN Title_Needed = '2' AND Title_Rank_Available = '4' THEN 'Order Standup Abstract'
        WHEN Title_Needed = '1' AND Title_Rank_Available IS NULL THEN 'Order Standup Opinion'
        WHEN Title_Needed = '1' AND Title_Rank_Available = '3' THEN 'Order Standup Opinion'
        WHEN Title_Needed = '1' AND Title_Rank_Available = '4' THEN 'Order Standup Opinion'
        WHEN Title_Needed = '2' AND Title_Rank_Available IS NULL THEN 'Order Standup Abstract'
        WHEN Title_Needed = '3' AND Title_Rank_Available = '4' THEN 'Order Targeted Scope'
        WHEN Title_Needed = '3' AND Title_Rank_Available IS NULL THEN 'Order Targeted Scope'
        WHEN Title_Needed = '3' AND Title_Rank_Available = '1' THEN 'No Title Needed'
        WHEN Title_Needed = '3' AND Title_Rank_Available = '2' THEN 'No Title Needed'
        ELSE 'I missed a combination of Title_Needed and Title_Rank_Available'
   END AS Title_Order_Action
   , CASE WHEN Title_Needed >= Title_Rank_Available THEN 'None'
        WHEN Title_Needed = '1' AND Title_Rank_Available = '2' THEN 'Upgrade'
        WHEN Title_Needed = '1' AND (Title_Rank_Available > '1' OR Title_Rank_Available IS NULL) THEN 'New'
        WHEN Title_Needed = '2' AND (Title_Rank_Available > '2' OR Title_Rank_Available IS NULL) THEN 'New'
        WHEN Title_Needed = '3' AND (Title_Rank_Available > '3' OR Title_Rank_Available IS NULL) THEN 'New'
        WHEN Title_Needed = '4' THEN 'Do not order'
        WHEN Title_Needed = '6' AND Title_Rank_Available = '1' THEN 'None'
        WHEN Title_Needed = '5' AND Title_Rank_Available = '1' THEN 'None'
        WHEN Title_Needed = '6' AND Title_Rank_Available = '2' THEN 'None'
        WHEN Title_Needed = '5' AND Title_Rank_Available = '2' THEN 'None'
        WHEN Title_Needed = '6' AND Title_Rank_Available = '3' THEN 'None'
        WHEN Title_Needed = '5' AND Title_Rank_Available = '3' THEN 'None'
        WHEN Title_Needed = '2' AND Title_Rank_Available = '1' THEN 'None'
        WHEN Title_Needed = '3' AND Title_Rank_Available = '1' THEN 'None'
        WHEN Title_Needed = '3' AND Title_Rank_Available = '2' THEN 'None'
        WHEN Title_Needed = '1' AND Title_Rank_Available = '2' THEN 'Upgrade'
        WHEN Title_Needed = '2' AND Title_Rank_Available = '3' THEN 'New'
        WHEN Title_Needed = '2' AND Title_Rank_Available = '4' THEN 'New'
        WHEN Title_Needed = '1' AND Title_Rank_Available IS NULL THEN 'New'
        WHEN Title_Needed = '1' AND Title_Rank_Available = '3' THEN 'New'
        WHEN Title_Needed = '1' AND Title_Rank_Available = '4' THEN 'New'
        WHEN Title_Needed = '2' AND Title_Rank_Available IS NULL THEN 'New'
        WHEN Title_Needed = '3' AND Title_Rank_Available = '4' THEN 'New'
        WHEN Title_Needed = '3' AND Title_Rank_Available IS NULL THEN 'New'
        WHEN Title_Needed = '3' AND Title_Rank_Available = '1' THEN 'None'
        WHEN Title_Needed = '3' AND Title_Rank_Available = '2' THEN 'None'
        ELSE 'I missed a combination of Title_Needed and Title_Rank_Available'
   END AS Title_Order_Action_Macro
   , LBF_Upgrade_Cost
   , LBF_SUTO_Cost
   , LBF_SUAB_Cost
   , LBF_Targeted_Scope
   , Sandbox_LBF_Targeted_Scope
   , Sandbox_LBF_SUAB_Cost
   , Sandbox_LBF_Upgrade_Cost
   , Sandbox_LBF_SUTO_Cost
   , CASE WHEN Cost_Type = 'In-flight' OR Cost_Type = 'Incurred' THEN Cost_Type
          WHEN Cost_Type IS NULL THEN 'Projected'
            ELSE 'Projected'
        END AS Cost_Type
  ,CASE WHEN (Cost_Type <> 'Incurred' AND Cost_Type <> 'In-flight' OR Cost_Type IS NULL)
        THEN CASE 
            WHEN Title_Needed >= Title_Rank_Available THEN 00.00
            WHEN Title_Needed = '1' AND Title_Rank_Available = '2' THEN LBF_Upgrade_Cost
            WHEN Title_Needed = '1' AND (Title_Rank_Available > '1' OR Title_Rank_Available IS NULL) THEN LBF_SUTO_Cost
            WHEN Title_Needed = '2' AND (Title_Rank_Available > '2' OR Title_Rank_Available IS NULL) THEN LBF_SUAB_Cost
            WHEN Title_Needed = '3' AND (Title_Rank_Available > '3' OR Title_Rank_Available IS NULL) THEN LBF_Targeted_Scope
            WHEN Title_Needed = '4' THEN 00.00
            ELSE 00.00
            END
        ELSE 00.00
   END AS Projected_Costs
   , CASE WHEN Title_Needed >= Title_Rank_Available AND Cost_Type = 'In-flight' THEN
     CASE WHEN Estimated_Title_Cost IS NOT NULL THEN Estimated_Title_Cost
          WHEN Title_Needed = '1' AND Title_Rank_Available = '2' THEN LBF_Upgrade_Cost
          WHEN Title_Needed = '1' AND (Title_Rank_Available > '1' OR Title_Rank_Available IS NULL) THEN LBF_SUTO_Cost
          WHEN Title_Needed = '2' AND (Title_Rank_Available > '2' OR Title_Rank_Available IS NULL) THEN LBF_SUAB_Cost
          WHEN Title_Needed = '3' AND (Title_Rank_Available > '3' OR Title_Rank_Available IS NULL) THEN LBF_Targeted_Scope
        END
        ELSE 00.00
    END AS In_flight_Costs
   , CASE WHEN Title_Needed >= Title_Rank_Available AND Cost_Type = 'Incurred' THEN
     CASE WHEN Actual_Title_Cost IS NOT NULL THEN Actual_Title_Cost
          WHEN Title_Needed = '1' AND Title_Rank_Available = '2' THEN LBF_Upgrade_Cost
          WHEN Title_Needed = '1' AND (Title_Rank_Available > '1' OR Title_Rank_Available IS NULL) THEN LBF_SUTO_Cost
          WHEN Title_Needed = '2' AND (Title_Rank_Available > '2' OR Title_Rank_Available IS NULL) THEN LBF_SUAB_Cost
          WHEN Title_Needed = '3' AND (Title_Rank_Available > '3' OR Title_Rank_Available IS NULL) THEN LBF_Targeted_Scope
        END  
        ELSE 00.00
    END AS Incurred_Title_Costs
    ,CASE 
            WHEN Cost_Type = 'In-flight' AND Actual_Title_Cost IS NOT NULL THEN Actual_Title_Cost
            WHEN Cost_Type = 'In-flight' AND Estimated_Title_Cost IS NOT NULL THEN Estimated_Title_Cost
            WHEN Cost_Type = 'Incurred' AND Actual_Title_Cost IS NOT NULL THEN Actual_Title_Cost
            WHEN Cost_Type = 'Incurred' AND Estimated_Title_Cost IS NOT NULL THEN Estimated_Title_Cost
            ELSE CASE 
                    WHEN Title_Needed >= Title_Rank_Available THEN 00.00
                    WHEN Title_Needed = '1' AND Title_Rank_Available = '2' THEN LBF_Upgrade_Cost
                    WHEN Title_Needed = '1' AND (Title_Rank_Available > '1' OR Title_Rank_Available IS NULL) THEN LBF_SUTO_Cost
                    WHEN Title_Needed = '2' AND (Title_Rank_Available > '2' OR Title_Rank_Available IS NULL) THEN LBF_SUAB_Cost
                    WHEN Title_Needed = '3' AND (Title_Rank_Available > '3' OR Title_Rank_Available IS NULL) THEN LBF_Targeted_Scope
                    WHEN Title_Needed = '4' THEN 00.00
                    ELSE 00.00
                    END
    END AS Consolidated_Costs
    ,Actual_Title_Cost
    ,Estimated_Title_Cost
    ,In_All_Purpose_Table
    , bw.Title_Workflow_Status__c AS WRP_Status
    , bw.Title_Workflow_Rank
FROM parcel_info3 parcel_info
LEFT JOIN BEST_WRP bw ON bw.Parcel_Number = parcel_info.Parcel_Number
--WHERE Earliest_Dev_Date IS NOT NULL OR Earliest_Sandbox_Dev_Date IS NOT NULL --AND Unmodified_Parcels LIKE '%[_]%'
)
, has_nulls3 AS
(
SELECT 
Parcel_Number
,MIN(State) AS State
,MIN(County) AS County
,MIN(Wellbore_Statuses) AS Wellbore_Statuses
,MIN(Parcel_Acreage) AS Parcel_Acreage
,MIN(Split_Parcel_Acreages) AS Split_Parcel_Acreages
,MIN(Title_Needed) AS Title_Needed
,MIN(Title_Rank_Available) AS Title_Rank_Available
,MIN(Title_Quality) AS Title_Quality
,MIN(Title_Tracker_Type) AS Title_Tracker_Type
,MIN(Certifier) AS Certifier
,MIN(Title_Tracker_Status) AS Title_Tracker_Status
,MIN(Unmodified_Parcels) AS Unmodified_Parcels
,MIN(Wells) AS Wells
,MIN(Devruns) AS Devruns
,MIN(Business_Plan_Year) AS Business_Plan_Year
,MIN(Business_Plan_Year_Formula_Checker) AS Business_Plan_Year_Formula_Checker
,MIN(HZ_Dates) AS HZ_Dates
,MIN(Earliest_Dev_Date) AS Earliest_Dev_Date
,MIN(Earliest_Devrun) AS Earliest_Devrun
,MIN(Earliest_Well) AS Earliest_Well
,MIN(Earliest_Wellbore_Date) AS Earliest_Wellbore_Date
,MIN(Earliest_WB_Devrun) AS Earliest_WB_Devrun
,MIN(Earliest_WB_Well) AS Earliest_WB_Well
,MIN(Earliest_Sandbox_Dev_Date) AS Earliest_Sandbox_Dev_Date
,MIN(Earliest_Sandbox_Devrun) AS Earliest_Sandbox_Devrun
,MIN(Earliest_Sandbox_Well) AS Earliest_Sandbox_Well
,MIN(Earliest_Sandbox_Wellbore_Date) AS Earliest_Sandbox_Wellbore_Date
,MIN(Earliest_Sandbox_WB_Devrun) AS Earliest_Sandbox_WB_Devrun
,MIN(Earliest_Sandbox_WB_Well) AS Earliest_Sandbox_WB_Well
,MIN(Title_Order_Action) AS Title_Order_Action
,MIN(Title_Order_Action_Macro) AS Title_Order_Action_Macro
,MIN(FORMAT(cast(LBF_Upgrade_Cost as float), '.00')) AS LBF_Upgrade_Cost
,MIN(FORMAT(cast(LBF_SUTO_Cost as float), '.00')) AS LBF_SUTO_Cost
,MIN(FORMAT(cast(LBF_SUAB_Cost as float), '.00')) AS LBF_SUAB_Cost
,MIN(FORMAT(cast(LBF_Targeted_Scope as float), '.00')) AS LBF_Targeted_Scope
,MIN(FORMAT(cast(Sandbox_LBF_Targeted_Scope as float), '.00')) AS Sandbox_LBF_Targeted_Scope
,MIN(FORMAT(cast(Sandbox_LBF_SUAB_Cost as float), '.00')) AS Sandbox_LBF_SUAB_Cost
,MIN(FORMAT(cast(Sandbox_LBF_Upgrade_Cost as float), '.00')) AS Sandbox_LBF_Upgrade_Cost
,MIN(FORMAT(cast(Sandbox_LBF_SUTO_Cost as float), '.00')) AS Sandbox_LBF_SUTO_Cost
,MIN(CASE WHEN Cost_Type IN ('Incurred','In-flight') AND Title_Order_Action_Macro <> 'None' THEN 'Projected' ELSE Cost_Type END ) AS Cost_Type
,MIN(FORMAT(cast(Projected_Costs as float), '.00')) AS Projected_Costs
,MIN(FORMAT(cast(In_flight_Costs as float), '.00')) AS In_flight_Costs
,MIN(FORMAT(cast(Incurred_Title_Costs as float), '.00')) AS Paid_Title_Costs
,MIN(FORMAT(cast(Consolidated_Costs as float), '.00')) AS Consolidated_Costs
,MIN(Dollar_Spend_Date) AS Dollar_Spend_Date
,YEAR(MIN(Dollar_Spend_Date)) AS Dollar_Spend_Date_Year
,MIN(Actual_Title_Cost) AS Actual_Title_Cost
,MIN(Estimated_Title_Cost) AS Estimated_Title_Cost
,MIN(In_All_Purpose_Table) AS In_All_Purpose_Table
,MIN(WRP_Status) AS WRP_Status
,MIN(Title_Workflow_Rank) AS Title_Workflow_Rank
FROM results3 
GROUP BY 
    Parcel_Number
)
,  medium_low AS
(
SELECT 
ISNULL(Parcel_Number, 'BLANK') AS Parcel_Number
,ISNULL(State, 'BLANK') AS State
,ISNULL(County, 'BLANK') AS County
,ISNULL(Wellbore_Statuses, 'BLANK') AS Wellbore_Statuses
,ISNULL(Parcel_Acreage, 0.00) AS Parcel_Acreage
,ISNULL(Split_Parcel_Acreages, 'BLANK') AS Split_Parcel_Acreages
,ISNULL(Title_Needed, 'BLANK') AS Title_Needed
,ISNULL(Title_Rank_Available, 'BLANK') AS Title_Rank_Available
,ISNULL(Title_Quality, 'BLANK') AS Title_Quality
,ISNULL(Title_Tracker_Type, 'BLANK') AS Title_Tracker_Type
,ISNULL(Certifier, 'BLANK') AS Certifier
,ISNULL(Title_Tracker_Status, 'BLANK') AS Title_Tracker_Status
,ISNULL(Unmodified_Parcels, 'BLANK') AS Unmodified_Parcels
,ISNULL(Wells, 'BLANK') AS Wells
,ISNULL(Devruns, 'BLANK') AS Devruns
,ISNULL(Business_Plan_Year, 0) AS Business_Plan_Year 
,ISNULL(Business_Plan_Year_Formula_Checker, 0) AS Business_Plan_Year_Formula_Checker 
,ISNULL(HZ_Dates, 'BLANK') AS HZ_Dates
,ISNULL(Earliest_Dev_Date, '1900-01-01') AS Earliest_Dev_Date
,ISNULL(Earliest_Devrun, 'BLANK') AS Earliest_Devrun
,ISNULL(Earliest_Well, 'BLANK') AS Earliest_Well
,ISNULL(Earliest_Wellbore_Date, '1900-01-01') AS Earliest_Wellbore_Date
,ISNULL(Earliest_WB_Devrun, 'BLANK') AS Earliest_WB_Devrun
,ISNULL(Earliest_WB_Well, 'BLANK') AS Earliest_WB_Well
,ISNULL(Earliest_Sandbox_Dev_Date, '1900-01-01') AS Earliest_Sandbox_Dev_Date
,ISNULL(Earliest_Sandbox_Devrun, 'BLANK') AS Earliest_Sandbox_Devrun
,ISNULL(Earliest_Sandbox_Well, 'BLANK') AS Earliest_Sandbox_Well
,ISNULL(Earliest_Sandbox_Wellbore_Date, '1900-01-01') AS Earliest_Sandbox_Wellbore_Date
,ISNULL(Earliest_Sandbox_WB_Devrun, 'BLANK') AS Earliest_Sandbox_WB_Devrun
,ISNULL(Earliest_Sandbox_WB_Well, 'BLANK') AS Earliest_Sandbox_WB_Well
,ISNULL(Title_Order_Action, 'BLANK') AS Title_Order_Action
,ISNULL(Title_Order_Action_Macro, 'BLANK') AS Title_Order_Action_Macro
,ISNULL(LBF_Upgrade_Cost, 0.00) AS LBF_Upgrade_Cost
,ISNULL(LBF_SUTO_Cost, 0.00) AS LBF_SUTO_Cost
,ISNULL(LBF_SUAB_Cost, 0.00) AS LBF_SUAB_Cost
,ISNULL(LBF_Targeted_Scope, 0.00) AS LBF_Targeted_Scope
,ISNULL(Sandbox_LBF_Targeted_Scope, 0.00) AS Sandbox_LBF_Targeted_Scope
,ISNULL(Sandbox_LBF_SUAB_Cost, 0.00) AS Sandbox_LBF_SUAB_Cost
,ISNULL(Sandbox_LBF_Upgrade_Cost, 0.00) AS Sandbox_LBF_Upgrade_Cost
,ISNULL(Sandbox_LBF_SUTO_Cost, 0.00) AS Sandbox_LBF_SUTO_Cost
,ISNULL(Cost_Type, 'BLANK') AS Cost_Type
,ISNULL(Projected_Costs, 0.00) AS Projected_Costs
,ISNULL(In_flight_Costs, 0.00) AS In_flight_Costs
,ISNULL(Paid_Title_Costs, 0.00) AS Paid_Title_Costs
,ISNULL(cast(Consolidated_Costs as float), 0.00) AS Consolidated_Costs
,ISNULL(
    Dollar_Spend_Date, 
        CASE 
            WHEN DATEADD(day, -1095, Earliest_Dev_Date) < GETDate() THEN GetDate() 
            ELSE DATEADD(day, -1095, Earliest_Dev_Date)
            END) AS Dollar_Spend_Date
,ISNULL(Dollar_Spend_Date_Year, YEAR(ISNULL(Dollar_Spend_Date, CASE WHEN DATEADD(day, -1095, Earliest_Dev_Date) < GETDate() THEN GetDate() ELSE DATEADD(day, -1095, Earliest_Dev_Date)END))) AS Dollar_Spend_Date_Year
,ISNULL(Actual_Title_Cost, 0.00) AS Actual_Title_Cost
,ISNULL(Estimated_Title_Cost, 0.00) AS Estimated_Title_Cost
,ISNULL(In_All_Purpose_Table, 'BLANK') AS In_All_Purpose_Table
,ISNULL(WRP_Status, 'BLANK') AS WRP_Status
,ISNULL(Title_Workflow_Rank, 0) AS Title_Workflow_Rank

FROM has_nulls3
)
,parcel_info4 AS
( SELECT
      pip.Parcel_Number
  ,cast(ad.Earliest_Dev_Date as date) AS Earliest_Dev_Date
  ,ad.Devrun_Name                                      AS Earliest_Devrun
  ,ad.WellName                                        AS Earliest_Well
  ,cast(wd.Earliest_Wellbore_Date as date) AS Earliest_Wellbore_Date
  ,wd.Devrun_Name                                      AS Earliest_WB_Devrun
  ,wd.WellName                                    AS Earliest_WB_Well
  ,cast(sd.Earliest_Sandbox_Dev_Date as date) AS Earliest_Sandbox_Dev_Date
  ,sd.Devrun_Name                                      AS Earliest_Sandbox_Devrun
  ,sd.WellName                                        AS Earliest_Sandbox_Well
  ,cast(swd.Earliest_Sandbox_Wellbore_Date as date) AS Earliest_Sandbox_Wellbore_Date
  ,swd.Devrun_Name                                      AS Earliest_Sandbox_WB_Devrun
  ,swd.WellName                                    AS Earliest_Sandbox_WB_Well
      ,  Unmodified_Parcels
    ,Wells
  ,Devruns
  ,HZ_Dates
      ,  Parcel_Acreage
      ,  Split_Parcel_Acreages
      ,  Wellbore_Statuses
/*The below CASE statement sets up the medium-low ordering model

As a Reminder SUTO = 1, SUTA = 2, Targeted Scope = 3, Nothing = 4
*/
      , CASE 
            WHEN pip.Parcel_Number NOT LIKE ('54%') AND Highest_Wellbore_status = 1 AND Parcel_Acreage < 5 THEN '3'
            WHEN pip.Parcel_Number NOT LIKE ('54%') AND Highest_Wellbore_status = 2 AND Parcel_Acreage < 5  THEN '3'
            WHEN Highest_Wellbore_status = 3 AND Parcel_Acreage >= 5  THEN '2'         
            WHEN Highest_Wellbore_status = 3 AND CASE WHEN GIS_Tax_Parcel_Id IS NOT NULL THEN 'Yes' ELSE 'No' END = 'No' THEN '3'
            WHEN Highest_Wellbore_status = 3 AND CASE WHEN GIS_Tax_Parcel_Id IS NOT NULL THEN 'Yes' ELSE 'No' END = 'Yes' THEN '3'
            WHEN Highest_Wellbore_status = 2 THEN '1'
            WHEN Highest_Wellbore_status = 1 THEN '1'
         END AS Title_Needed
      ,  Title_Rank_Available
      ,  Title_Quality
      ,  Title_Tracker_Type
      ,  Certifier
      ,  Title_Tracker_Status
      ,  Cost_Type
      ,  Actual_Title_Cost
      ,  Estimated_Title_Cost
      , efc.Targeted_Scope AS LBF_Targeted_Scope
      , efc.SUAB_Cost AS LBF_SUAB_Cost
      , efc.Upgrade_Cost AS LBF_Upgrade_Cost
      , efc.SUTO_Cost AS LBF_SUTO_Cost
      , sefc.Targeted_Scope AS Sandbox_LBF_Targeted_Scope
      , sefc.SUAB_Cost AS Sandbox_LBF_SUAB_Cost
      , sefc.Upgrade_Cost AS Sandbox_LBF_Upgrade_Cost
      , sefc.SUTO_Cost AS Sandbox_LBF_SUTO_Cost
      , Dollar_Spend_Date
      , CASE
            WHEN GIS_Tax_Parcel_Id IS NOT NULL THEN 'Yes'
            ELSE 'No'
        END AS In_All_Purpose_Table
      FROM parcel_info_pre pip
LEFT JOIN APL ON GIS_Tax_Parcel_Id = Parcel_Number
LEFT JOIN wellbore_dates wd ON wd.Parcel_Number = pip.Parcel_Number AND wd.prod_row = 1
LEFT JOIN wellbore_dates swd ON swd.Parcel_Number = pip.Parcel_Number AND swd.sandbox_row = 1
LEFT JOIN prod_dates ad ON ad.Parcel_Number = pip.Parcel_Number AND ad.row = 1
LEFT JOIN sandbox_dates sd ON sd.Parcel_Number = pip.Parcel_Number AND sd.row = 1
LEFT JOIN est_fut_cost efc ON 
        CASE 
            WHEN pip.Parcel_Number LIKE ('42-%') THEN 'PA' 
            WHEN pip.Parcel_Number LIKE ('54-%') THEN 'WV'
            WHEN pip.Parcel_Number LIKE ('39-%') THEN 'OH'
            END = efc.State 
        and	
        CASE 
            WHEN pip.Parcel_Number LIKE ('42-003-%') THEN 'Allegheny' 
            WHEN pip.Parcel_Number LIKE ('42-051-%') THEN 'Fayette' 
            WHEN pip.Parcel_Number LIKE ('42-059-%') THEN 'Greene' 
            WHEN pip.Parcel_Number LIKE ('42-081-%') THEN 'Lycoming' 
            WHEN pip.Parcel_Number LIKE ('42-113-%') THEN 'Sullivan' 
            WHEN pip.Parcel_Number LIKE ('42-125-%') THEN 'Washington' 
            WHEN pip.Parcel_Number LIKE ('42-129-%') THEN 'Westmoreland' 
            WHEN pip.Parcel_Number LIKE ('54-049-%') THEN 'Marion'
            WHEN pip.Parcel_Number LIKE ('54-051-%') THEN 'Marshall'
            WHEN pip.Parcel_Number LIKE ('54-061-%') THEN 'Monongalia'
            WHEN pip.Parcel_Number LIKE ('54-103-%') THEN 'Wetzel'
            WHEN pip.Parcel_Number LIKE ('39-013-%') THEN 'Belmont'
            WHEN pip.Parcel_Number LIKE ('54-033-%') THEN 'Harrison'
            WHEN pip.Parcel_Number LIKE ('42-035-%') THEN 'Clinton'
            WHEN pip.Parcel_Number LIKE ('54-017-%') THEN 'Doddridge'
            END = efc.County
        and efc.Business_Plan_Year = YEAR(ad.Earliest_Dev_Date)
LEFT JOIN est_fut_cost sefc ON 
        CASE 
            WHEN pip.Parcel_Number LIKE ('42-%') THEN 'PA' 
            WHEN pip.Parcel_Number LIKE ('54-%') THEN 'WV'
            WHEN pip.Parcel_Number LIKE ('39-%') THEN 'OH'
            END = efc.State 
        and	
        CASE 
            WHEN pip.Parcel_Number LIKE ('42-003-%') THEN 'Allegheny' 
            WHEN pip.Parcel_Number LIKE ('42-051-%') THEN 'Fayette' 
            WHEN pip.Parcel_Number LIKE ('42-059-%') THEN 'Greene' 
            WHEN pip.Parcel_Number LIKE ('42-081-%') THEN 'Lycoming' 
            WHEN pip.Parcel_Number LIKE ('42-113-%') THEN 'Sullivan' 
            WHEN pip.Parcel_Number LIKE ('42-125-%') THEN 'Washington' 
            WHEN pip.Parcel_Number LIKE ('42-129-%') THEN 'Westmoreland' 
            WHEN pip.Parcel_Number LIKE ('54-049-%') THEN 'Marion'
            WHEN pip.Parcel_Number LIKE ('54-051-%') THEN 'Marshall'
            WHEN pip.Parcel_Number LIKE ('54-061-%') THEN 'Monongalia'
            WHEN pip.Parcel_Number LIKE ('54-103-%') THEN 'Wetzel'
            WHEN pip.Parcel_Number LIKE ('39-013-%') THEN 'Belmont'
            WHEN pip.Parcel_Number LIKE ('54-033-%') THEN 'Harrison'
            WHEN pip.Parcel_Number LIKE ('42-035-%') THEN 'Clinton'
            WHEN pip.Parcel_Number LIKE ('54-017-%') THEN 'Doddridge'
            END = efc.County
        and sefc.Business_Plan_Year = YEAR(sd.Earliest_Sandbox_Dev_Date)
)
,results4 AS (
SELECT
   CASE WHEN parcel_info.Parcel_Number LIKE ('42-%') THEN 'PA' 
        WHEN parcel_info.Parcel_Number LIKE ('54-%') THEN 'WV'
        WHEN parcel_info.Parcel_Number LIKE ('39-%') THEN 'OH'
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
        WHEN parcel_info.Parcel_Number LIKE ('54-017-%') THEN 'Doddridge'
   END AS County
  ,parcel_info.Parcel_Number
  ,Wellbore_Statuses
  ,cast(Parcel_Acreage as float) AS Parcel_Acreage
  ,Split_Parcel_Acreages
  ,Title_Needed
  ,Title_Rank_Available
  ,  Title_Quality
  ,  Title_Tracker_Type
  ,  Certifier
  ,  Title_Tracker_Status
  ,Unmodified_Parcels
  ,Wells
  ,Devruns
  ,CASE 
        WHEN YEAR(Earliest_Dev_Date) <= 2021 THEN YEAR(Earliest_Dev_Date)
        WHEN YEAR(Earliest_Dev_Date) <= 2024 THEN 2022
        ELSE YEAR(DATEADD(year, -3, Earliest_Dev_Date))
  END            Business_Plan_Year
  ,CASE 
        WHEN YEAR(Earliest_Dev_Date) <= 2021 THEN 1
        WHEN YEAR(Earliest_Dev_Date) <= 2024 THEN 2
        ELSE 3
  END          AS Business_Plan_Year_Formula_Checker
  ,HZ_Dates
  ,Earliest_Dev_Date
  ,Earliest_Devrun
  ,Earliest_Well
  ,Earliest_Wellbore_Date
  ,Earliest_WB_Devrun
  ,Earliest_WB_Well
  ,Dollar_Spend_Date 
  ,Earliest_Sandbox_Dev_Date
  ,Earliest_Sandbox_Devrun
  ,Earliest_Sandbox_Well
  ,Earliest_Sandbox_Wellbore_Date
  ,Earliest_Sandbox_WB_Devrun
  ,Earliest_Sandbox_WB_Well
  ,CASE WHEN Title_Needed >= Title_Rank_Available THEN 'No Title Needed'
        WHEN Title_Needed = '1' AND Title_Rank_Available = '2' THEN 'Upgrade Abstract to Opinion'
        WHEN Title_Needed = '1' AND (Title_Rank_Available > '1' OR Title_Rank_Available IS NULL) THEN 'Order Standup Opinion'
        WHEN Title_Needed = '2' AND (Title_Rank_Available > '2' OR Title_Rank_Available IS NULL) THEN 'Order Standup Abstract'
        WHEN Title_Needed = '3' AND (Title_Rank_Available > '3' OR Title_Rank_Available IS NULL) THEN 'Order Targeted Scope Abstract'
        WHEN Title_Needed = '2' AND Title_Rank_Available = '1' THEN 'No Title Needed'
        WHEN Title_Needed = '3' AND Title_Rank_Available = '1' THEN 'No Title Needed'
        WHEN Title_Needed = '3' AND Title_Rank_Available = '2' THEN 'No Title Needed'
        WHEN Title_Needed = '1' AND Title_Rank_Available = '2' THEN 'Upgrade abstract to opinion'
        WHEN Title_Needed = '2' AND Title_Rank_Available = '3' THEN 'Order Standup Abstract'
        WHEN Title_Needed = '2' AND Title_Rank_Available = '4' THEN 'Order Standup Abstract'
        WHEN Title_Needed = '1' AND Title_Rank_Available IS NULL THEN 'Order Standup Opinion'
        WHEN Title_Needed = '1' AND Title_Rank_Available = '3' THEN 'Order Standup Opinion'
        WHEN Title_Needed = '1' AND Title_Rank_Available = '4' THEN 'Order Standup Opinion'
        WHEN Title_Needed = '2' AND Title_Rank_Available IS NULL THEN 'Order Standup Abstract'
        WHEN Title_Needed = '3' AND Title_Rank_Available = '4' THEN 'Order Targeted Scope'
        WHEN Title_Needed = '3' AND Title_Rank_Available IS NULL THEN 'Order Targeted Scope'
        WHEN Title_Needed = '3' AND Title_Rank_Available = '1' THEN 'No Title Needed'
        WHEN Title_Needed = '3' AND Title_Rank_Available = '2' THEN 'No Title Needed'
        ELSE 'I missed a combination of Title_Needed and Title_Rank_Available'
   END AS Title_Order_Action
   , CASE WHEN Title_Needed >= Title_Rank_Available THEN 'None'
        WHEN Title_Needed = '1' AND Title_Rank_Available = '2' THEN 'Upgrade'
        WHEN Title_Needed = '1' AND (Title_Rank_Available > '1' OR Title_Rank_Available IS NULL) THEN 'New'
        WHEN Title_Needed = '2' AND (Title_Rank_Available > '2' OR Title_Rank_Available IS NULL) THEN 'New'
        WHEN Title_Needed = '3' AND (Title_Rank_Available > '3' OR Title_Rank_Available IS NULL) THEN 'New'
        WHEN Title_Needed = '4' THEN 'Do not order'
        WHEN Title_Needed = '6' AND Title_Rank_Available = '1' THEN 'None'
        WHEN Title_Needed = '5' AND Title_Rank_Available = '1' THEN 'None'
        WHEN Title_Needed = '6' AND Title_Rank_Available = '2' THEN 'None'
        WHEN Title_Needed = '5' AND Title_Rank_Available = '2' THEN 'None'
        WHEN Title_Needed = '6' AND Title_Rank_Available = '3' THEN 'None'
        WHEN Title_Needed = '5' AND Title_Rank_Available = '3' THEN 'None'
        WHEN Title_Needed = '2' AND Title_Rank_Available = '1' THEN 'None'
        WHEN Title_Needed = '3' AND Title_Rank_Available = '1' THEN 'None'
        WHEN Title_Needed = '3' AND Title_Rank_Available = '2' THEN 'None'
        WHEN Title_Needed = '1' AND Title_Rank_Available = '2' THEN 'Upgrade'
        WHEN Title_Needed = '2' AND Title_Rank_Available = '3' THEN 'New'
        WHEN Title_Needed = '2' AND Title_Rank_Available = '4' THEN 'New'
        WHEN Title_Needed = '1' AND Title_Rank_Available IS NULL THEN 'New'
        WHEN Title_Needed = '1' AND Title_Rank_Available = '3' THEN 'New'
        WHEN Title_Needed = '1' AND Title_Rank_Available = '4' THEN 'New'
        WHEN Title_Needed = '2' AND Title_Rank_Available IS NULL THEN 'New'
        WHEN Title_Needed = '3' AND Title_Rank_Available = '4' THEN 'New'
        WHEN Title_Needed = '3' AND Title_Rank_Available IS NULL THEN 'New'
        WHEN Title_Needed = '3' AND Title_Rank_Available = '1' THEN 'None'
        WHEN Title_Needed = '3' AND Title_Rank_Available = '2' THEN 'None'
        ELSE 'I missed a combination of Title_Needed and Title_Rank_Available'
   END AS Title_Order_Action_Macro
   , LBF_Upgrade_Cost
   , LBF_SUTO_Cost
   , LBF_SUAB_Cost
   , LBF_Targeted_Scope
   , Sandbox_LBF_Targeted_Scope
   , Sandbox_LBF_SUAB_Cost
   , Sandbox_LBF_Upgrade_Cost
   , Sandbox_LBF_SUTO_Cost
   , CASE WHEN Cost_Type = 'In-flight' OR Cost_Type = 'Incurred' THEN Cost_Type
          WHEN Cost_Type IS NULL THEN 'Projected'
            ELSE 'Projected'
        END AS Cost_Type
  ,CASE WHEN (Cost_Type <> 'Incurred' AND Cost_Type <> 'In-flight' OR Cost_Type IS NULL)
        THEN CASE 
            WHEN Title_Needed >= Title_Rank_Available THEN 00.00
            WHEN Title_Needed = '1' AND Title_Rank_Available = '2' THEN LBF_Upgrade_Cost
            WHEN Title_Needed = '1' AND (Title_Rank_Available > '1' OR Title_Rank_Available IS NULL) THEN LBF_SUTO_Cost
            WHEN Title_Needed = '2' AND (Title_Rank_Available > '2' OR Title_Rank_Available IS NULL) THEN LBF_SUAB_Cost
            WHEN Title_Needed = '3' AND (Title_Rank_Available > '3' OR Title_Rank_Available IS NULL) THEN LBF_Targeted_Scope
            WHEN Title_Needed = '4' THEN 00.00
            ELSE 00.00
            END
        ELSE 00.00
   END AS Projected_Costs
   , CASE WHEN Title_Needed >= Title_Rank_Available AND Cost_Type = 'In-flight' THEN
     CASE WHEN Estimated_Title_Cost IS NOT NULL THEN Estimated_Title_Cost
          WHEN Title_Needed = '1' AND Title_Rank_Available = '2' THEN LBF_Upgrade_Cost
          WHEN Title_Needed = '1' AND (Title_Rank_Available > '1' OR Title_Rank_Available IS NULL) THEN LBF_SUTO_Cost
          WHEN Title_Needed = '2' AND (Title_Rank_Available > '2' OR Title_Rank_Available IS NULL) THEN LBF_SUAB_Cost
          WHEN Title_Needed = '3' AND (Title_Rank_Available > '3' OR Title_Rank_Available IS NULL) THEN LBF_Targeted_Scope
        END
        ELSE 00.00
    END AS In_flight_Costs
   , CASE WHEN Title_Needed >= Title_Rank_Available AND Cost_Type = 'Incurred' THEN
     CASE WHEN Actual_Title_Cost IS NOT NULL THEN Actual_Title_Cost
          WHEN Title_Needed = '1' AND Title_Rank_Available = '2' THEN LBF_Upgrade_Cost
          WHEN Title_Needed = '1' AND (Title_Rank_Available > '1' OR Title_Rank_Available IS NULL) THEN LBF_SUTO_Cost
          WHEN Title_Needed = '2' AND (Title_Rank_Available > '2' OR Title_Rank_Available IS NULL) THEN LBF_SUAB_Cost
          WHEN Title_Needed = '3' AND (Title_Rank_Available > '3' OR Title_Rank_Available IS NULL) THEN LBF_Targeted_Scope
        END  
        ELSE 00.00
    END AS Incurred_Title_Costs
    ,CASE 
            WHEN Cost_Type = 'In-flight' AND Actual_Title_Cost IS NOT NULL THEN Actual_Title_Cost
            WHEN Cost_Type = 'In-flight' AND Estimated_Title_Cost IS NOT NULL THEN Estimated_Title_Cost
            WHEN Cost_Type = 'Incurred' AND Actual_Title_Cost IS NOT NULL THEN Actual_Title_Cost
            WHEN Cost_Type = 'Incurred' AND Estimated_Title_Cost IS NOT NULL THEN Estimated_Title_Cost
            ELSE CASE 
                    WHEN Title_Needed >= Title_Rank_Available THEN 00.00
                    WHEN Title_Needed = '1' AND Title_Rank_Available = '2' THEN LBF_Upgrade_Cost
                    WHEN Title_Needed = '1' AND (Title_Rank_Available > '1' OR Title_Rank_Available IS NULL) THEN LBF_SUTO_Cost
                    WHEN Title_Needed = '2' AND (Title_Rank_Available > '2' OR Title_Rank_Available IS NULL) THEN LBF_SUAB_Cost
                    WHEN Title_Needed = '3' AND (Title_Rank_Available > '3' OR Title_Rank_Available IS NULL) THEN LBF_Targeted_Scope
                    WHEN Title_Needed = '4' THEN 00.00
                    ELSE 00.00
                    END
    END AS Consolidated_Costs
    ,Actual_Title_Cost
    ,Estimated_Title_Cost
    ,In_All_Purpose_Table
    , bw.Title_Workflow_Status__c AS WRP_Status
    , bw.Title_Workflow_Rank
FROM parcel_info4 parcel_info
LEFT JOIN BEST_WRP bw ON bw.Parcel_Number = parcel_info.Parcel_Number
--WHERE Earliest_Dev_Date IS NOT NULL OR Earliest_Sandbox_Dev_Date IS NOT NULL --AND Unmodified_Parcels LIKE '%[_]%'
)
, has_nulls4 AS
(
SELECT 
Parcel_Number
,MIN(State) AS State
,MIN(County) AS County
,MIN(Wellbore_Statuses) AS Wellbore_Statuses
,MIN(Parcel_Acreage) AS Parcel_Acreage
,MIN(Split_Parcel_Acreages) AS Split_Parcel_Acreages
,MIN(Title_Needed) AS Title_Needed
,MIN(Title_Rank_Available) AS Title_Rank_Available
,MIN(Title_Quality) AS Title_Quality
,MIN(Title_Tracker_Type) AS Title_Tracker_Type
,MIN(Certifier) AS Certifier
,MIN(Title_Tracker_Status) AS Title_Tracker_Status
,MIN(Unmodified_Parcels) AS Unmodified_Parcels
,MIN(Wells) AS Wells
,MIN(Devruns) AS Devruns
,MIN(Business_Plan_Year) AS Business_Plan_Year
,MIN(Business_Plan_Year_Formula_Checker) AS Business_Plan_Year_Formula_Checker
,MIN(HZ_Dates) AS HZ_Dates
,MIN(Earliest_Dev_Date) AS Earliest_Dev_Date
,MIN(Earliest_Devrun) AS Earliest_Devrun
,MIN(Earliest_Well) AS Earliest_Well
,MIN(Earliest_Wellbore_Date) AS Earliest_Wellbore_Date
,MIN(Earliest_WB_Devrun) AS Earliest_WB_Devrun
,MIN(Earliest_WB_Well) AS Earliest_WB_Well
,MIN(Earliest_Sandbox_Dev_Date) AS Earliest_Sandbox_Dev_Date
,MIN(Earliest_Sandbox_Devrun) AS Earliest_Sandbox_Devrun
,MIN(Earliest_Sandbox_Well) AS Earliest_Sandbox_Well
,MIN(Earliest_Sandbox_Wellbore_Date) AS Earliest_Sandbox_Wellbore_Date
,MIN(Earliest_Sandbox_WB_Devrun) AS Earliest_Sandbox_WB_Devrun
,MIN(Earliest_Sandbox_WB_Well) AS Earliest_Sandbox_WB_Well
,MIN(Title_Order_Action) AS Title_Order_Action
,MIN(Title_Order_Action_Macro) AS Title_Order_Action_Macro
,MIN(FORMAT(cast(LBF_Upgrade_Cost as float), '.00')) AS LBF_Upgrade_Cost
,MIN(FORMAT(cast(LBF_SUTO_Cost as float), '.00')) AS LBF_SUTO_Cost
,MIN(FORMAT(cast(LBF_SUAB_Cost as float), '.00')) AS LBF_SUAB_Cost
,MIN(FORMAT(cast(LBF_Targeted_Scope as float), '.00')) AS LBF_Targeted_Scope
,MIN(FORMAT(cast(Sandbox_LBF_Targeted_Scope as float), '.00')) AS Sandbox_LBF_Targeted_Scope
,MIN(FORMAT(cast(Sandbox_LBF_SUAB_Cost as float), '.00')) AS Sandbox_LBF_SUAB_Cost
,MIN(FORMAT(cast(Sandbox_LBF_Upgrade_Cost as float), '.00')) AS Sandbox_LBF_Upgrade_Cost
,MIN(FORMAT(cast(Sandbox_LBF_SUTO_Cost as float), '.00')) AS Sandbox_LBF_SUTO_Cost
,MIN(CASE WHEN Cost_Type IN ('Incurred','In-flight') AND Title_Order_Action_Macro <> 'None' THEN 'Projected' ELSE Cost_Type END ) AS Cost_Type
,MIN(FORMAT(cast(Projected_Costs as float), '.00')) AS Projected_Costs
,MIN(FORMAT(cast(In_flight_Costs as float), '.00')) AS In_flight_Costs
,MIN(FORMAT(cast(Incurred_Title_Costs as float), '.00')) AS Paid_Title_Costs
,MIN(FORMAT(cast(Consolidated_Costs as float), '.00')) AS Consolidated_Costs
,MIN(Dollar_Spend_Date) AS Dollar_Spend_Date
,YEAR(MIN(Dollar_Spend_Date)) AS Dollar_Spend_Date_Year
,MIN(Actual_Title_Cost) AS Actual_Title_Cost
,MIN(Estimated_Title_Cost) AS Estimated_Title_Cost
,MIN(In_All_Purpose_Table) AS In_All_Purpose_Table
,MIN(WRP_Status) AS WRP_Status
,MIN(Title_Workflow_Rank) AS Title_Workflow_Rank
FROM results4 
GROUP BY 
    Parcel_Number
)
,  medium_high AS
(
SELECT 
ISNULL(Parcel_Number, 'BLANK') AS Parcel_Number
,ISNULL(State, 'BLANK') AS State
,ISNULL(County, 'BLANK') AS County
,ISNULL(Wellbore_Statuses, 'BLANK') AS Wellbore_Statuses
,ISNULL(Parcel_Acreage, 0.00) AS Parcel_Acreage
,ISNULL(Split_Parcel_Acreages, 'BLANK') AS Split_Parcel_Acreages
,ISNULL(Title_Needed, 'BLANK') AS Title_Needed
,ISNULL(Title_Rank_Available, 'BLANK') AS Title_Rank_Available
,ISNULL(Title_Quality, 'BLANK') AS Title_Quality
,ISNULL(Title_Tracker_Type, 'BLANK') AS Title_Tracker_Type
,ISNULL(Certifier, 'BLANK') AS Certifier
,ISNULL(Title_Tracker_Status, 'BLANK') AS Title_Tracker_Status
,ISNULL(Unmodified_Parcels, 'BLANK') AS Unmodified_Parcels
,ISNULL(Wells, 'BLANK') AS Wells
,ISNULL(Devruns, 'BLANK') AS Devruns
,ISNULL(Business_Plan_Year, 0) AS Business_Plan_Year 
,ISNULL(Business_Plan_Year_Formula_Checker, 0) AS Business_Plan_Year_Formula_Checker
,ISNULL(HZ_Dates, 'BLANK') AS HZ_Dates
,ISNULL(Earliest_Dev_Date, '1900-01-01') AS Earliest_Dev_Date
,ISNULL(Earliest_Devrun, 'BLANK') AS Earliest_Devrun
,ISNULL(Earliest_Well, 'BLANK') AS Earliest_Well
,ISNULL(Earliest_Wellbore_Date, '1900-01-01') AS Earliest_Wellbore_Date
,ISNULL(Earliest_WB_Devrun, 'BLANK') AS Earliest_WB_Devrun
,ISNULL(Earliest_WB_Well, 'BLANK') AS Earliest_WB_Well
,ISNULL(Earliest_Sandbox_Dev_Date, '1900-01-01') AS Earliest_Sandbox_Dev_Date
,ISNULL(Earliest_Sandbox_Devrun, 'BLANK') AS Earliest_Sandbox_Devrun
,ISNULL(Earliest_Sandbox_Well, 'BLANK') AS Earliest_Sandbox_Well
,ISNULL(Earliest_Sandbox_Wellbore_Date, '1900-01-01') AS Earliest_Sandbox_Wellbore_Date
,ISNULL(Earliest_Sandbox_WB_Devrun, 'BLANK') AS Earliest_Sandbox_WB_Devrun
,ISNULL(Earliest_Sandbox_WB_Well, 'BLANK') AS Earliest_Sandbox_WB_Well
,ISNULL(Title_Order_Action, 'BLANK') AS Title_Order_Action
,ISNULL(Title_Order_Action_Macro, 'BLANK') AS Title_Order_Action_Macro
,ISNULL(LBF_Upgrade_Cost, 0.00) AS LBF_Upgrade_Cost
,ISNULL(LBF_SUTO_Cost, 0.00) AS LBF_SUTO_Cost
,ISNULL(LBF_SUAB_Cost, 0.00) AS LBF_SUAB_Cost
,ISNULL(LBF_Targeted_Scope, 0.00) AS LBF_Targeted_Scope
,ISNULL(Sandbox_LBF_Targeted_Scope, 0.00) AS Sandbox_LBF_Targeted_Scope
,ISNULL(Sandbox_LBF_SUAB_Cost, 0.00) AS Sandbox_LBF_SUAB_Cost
,ISNULL(Sandbox_LBF_Upgrade_Cost, 0.00) AS Sandbox_LBF_Upgrade_Cost
,ISNULL(Sandbox_LBF_SUTO_Cost, 0.00) AS Sandbox_LBF_SUTO_Cost
,ISNULL(Cost_Type, 'BLANK') AS Cost_Type
,ISNULL(Projected_Costs, 0.00) AS Projected_Costs
,ISNULL(In_flight_Costs, 0.00) AS In_flight_Costs
,ISNULL(Paid_Title_Costs, 0.00) AS Paid_Title_Costs
,ISNULL(cast(Consolidated_Costs as float), 0.00) AS Consolidated_Costs
,ISNULL(
    Dollar_Spend_Date, 
        CASE 
            WHEN DATEADD(day, -1095, Earliest_Dev_Date) < GETDate() THEN GetDate() 
            ELSE DATEADD(day, -1095, Earliest_Dev_Date)
            END) AS Dollar_Spend_Date
,ISNULL(Dollar_Spend_Date_Year, YEAR(ISNULL(Dollar_Spend_Date, CASE WHEN DATEADD(day, -1095, Earliest_Dev_Date) < GETDate() THEN GetDate() ELSE DATEADD(day, -1095, Earliest_Dev_Date)END))) AS Dollar_Spend_Date_Year
,ISNULL(Actual_Title_Cost, 0.00) AS Actual_Title_Cost
,ISNULL(Estimated_Title_Cost, 0.00) AS Estimated_Title_Cost
,ISNULL(In_All_Purpose_Table, 'BLANK') AS In_All_Purpose_Table
,ISNULL(WRP_Status, 'BLANK') AS WRP_Status
,ISNULL(Title_Workflow_Rank, 0) AS Title_Workflow_Rank

FROM has_nulls4
)
, merged AS
(
SELECT
Parcel_Number + '-Current-(Reduced)' AS Parcel_Budget_Key
,   *
,   'Current (Reduced)' AS Budget_Type
FROM current_reduced
UNION

SELECT
Parcel_Number + '-Ideal' AS Parcel_Budget_Key
,   Ideal.*
,   'Ideal' AS Budget_Type
FROM Ideal
/*
UNion

SELECT
Parcel_Number + '-Medium-Low' AS Parcel_Budget_Key
,   medium_low.*
,   'Medium Low' AS Budget_Type
FROM medium_low
*/UNION

SELECT
Parcel_Number + '-Medium' AS Parcel_Budget_Key
,   medium_high.*
,   'Medium' AS Budget_Type
FROM medium_high
)

SELECT 
    cm.*
    ,   CASE
            WHEN WRP_Status <> 'Title Complete' THEN
            CASE
                WHEN County = 'Allegheny' THEN 10200 * 0.002
                WHEN County = 'Fayette' THEN 10200 * 0.005
                WHEN County = 'Greene' THEN 10200 * 0.009
                WHEN County = 'Marion' THEN 10200 * 0.063
                WHEN County = 'Marshall' THEN 10200 * 0.009
                WHEN County = 'Washington' THEN 10200 * 0.005
                WHEN County = 'Wetzel' THEN 10200 * 0.143
                ELSE 0.001 * 10200
                END
            ELSE 0
        END AS Heirship_Cost
    ,   CASE
        WHEN County = 'Allegheny' THEN 10200 * 0.002
            WHEN County = 'Fayette' THEN 10200 * 0.005
            WHEN County = 'Greene' THEN 10200 * 0.009
            WHEN County = 'Marion' THEN 10200 * 0.063
            WHEN County = 'Marshall' THEN 10200 * 0.009
            WHEN County = 'Washington' THEN 10200 * 0.005
            WHEN County = 'Wetzel' THEN 10200 * 0.143
            ELSE 0.001 * 10200
    END AS Heirship_Cost_Incl_TC  

FROM merged cm;
GO
