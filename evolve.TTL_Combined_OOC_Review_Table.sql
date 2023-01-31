DROP TABLE evolve.TTL_Combined_OOC_Review_Table
GO
CREATE TABLE evolve.TTL_Combined_OOC_Review_Table WITH (DISTRIBUTION = ROUND_ROBIN, HEAP)
AS
WITH combined AS
(SELECT
    CASE 
      --  WHEN STATE IS NULL AND Parcel_Number LIKE ('42%') THEN 'PA'
        WHEN STATE IS NULL AND Parcel_Number LIKE ('39%') THEN 'OH'
        WHEN STATE IS NULL AND Parcel_Number LIKE ('54%') THEN 'WV'
        ELSE State
        END AS State
    ,   County
    ,   Parcel_Number
    ,   Wells
    ,   TIL_Dates AS Dates
    ,   Earliest_Date
    ,   Earliest_Devrun_Date
    ,   Earliest_Devrun
    ,   Earliest_Well
    ,   Devruns
    ,   OOC_Review_Year
    ,   OOC_Review_Date
    ,   Average_ORs_Per_Parcel
    ,   MT_Factor
    ,   Adjusted_ORs_Need_Per_Parcel
    ,   Average_ORs_Per_Person_Per_Day
    ,   Analyst_Workdays_per_Parcel
    ,   Workdays_in_Year
    ,   'TIL' AS Category
FROM evolve.TIL_OOC_REVIEW

UNION

SELECT
    State
    ,   County
    ,   Parcel_Number
    ,   Wells
    ,   HZ_Dates AS Dates
    ,   Earliest_Date
    ,   Earliest_Devrun_Date
    ,   Earliest_Devrun
    ,   Earliest_Well
    ,   Devruns
    ,   OOC_Review_Year
    ,   OOC_Review_Date
    ,   Average_ORs_Per_Parcel
    ,   MT_Factor
    ,   Adjusted_ORs_Need_Per_Parcel
    ,   Average_ORs_Per_Person_Per_Day
    ,   Analyst_Workdays_per_Parcel
    ,   Workdays_in_Year
    ,   'WBCO' AS Category
FROM evolve.WBCO_OOC_REVIEW
)


SELECT
        cm.State
    ,   cm.County
    ,   cm.Parcel_Number
    ,   cm.Wells
    ,   cm.Dates
    ,   cm.Earliest_Date
    ,   cm.Earliest_Devrun_Date
    ,   cm.Earliest_Devrun
    ,   cm.Earliest_Well
    ,   cm.Devruns
    ,   cm.OOC_Review_Year
    ,   cm.OOC_Review_Date
    ,   CASE WHEN cm.Average_ORs_Per_Parcel IS NULL Then cm2.Average_ORs_Per_Parcel ELSE cm.Average_ORs_Per_Parcel END AS Average_ORs_Per_Parcel 
    ,   CASE WHEN cm.MT_Factor IS NULL THEN cm2.MT_Factor ELSE cm.MT_Factor END AS MT_Factor
    ,   CASE WHEN cm.Adjusted_ORs_Need_Per_Parcel IS NULL THEN cm2.Adjusted_ORs_Need_Per_Parcel ELSE cm.Adjusted_ORs_Need_Per_Parcel END AS Adjusted_ORs_Need_Per_Parcel
    ,   cm.Average_ORs_Per_Person_Per_Day
    ,   CASE 
            WHEN cm.Analyst_Workdays_per_Parcel IS NULL 
                THEN FORMAT(CASE 
                                WHEN cm.Adjusted_ORs_Need_Per_Parcel IS NULL 
                                    THEN cm2.Adjusted_ORs_Need_Per_Parcel 
                                ELSE cm.Adjusted_ORs_Need_Per_Parcel 
                            END/cm.Average_ORs_Per_Person_Per_Day, '#0.0000') 
                ELSE cm.Analyst_Workdays_per_Parcel 
        END AS Analyst_Workdays_per_Parcel
    ,   cm.Workdays_in_Year
    ,   CASE 
            WHEN cm.Analyst_Workdays_per_Parcel IS NULL 
                THEN FORMAT(CASE 
                                WHEN cm.Adjusted_ORs_Need_Per_Parcel IS NULL 
                                    THEN cm2.Adjusted_ORs_Need_Per_Parcel 
                                ELSE cm.Adjusted_ORs_Need_Per_Parcel 
                            END/cm.Average_ORs_Per_Person_Per_Day, '#0.0000') 
                ELSE cm.Analyst_Workdays_per_Parcel 
        END/cm.Workdays_in_Year AS Analyst_Need
    ,   cm.Category
FROM combined cm
LEFT JOIN combined cm2 ON cm2.state = cm.state AND cm2.County = 'Lycoming' and cm.County = 'Clinton'


GO