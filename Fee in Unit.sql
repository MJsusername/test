
CREATE VIEW evolve.fee_in_unit
AS
SELECT 
    Unit_UID, 
    UnitName, 
    GIS_Link, 
    Agreement_Number, 
    Agreement_type,
    Agreement_Name, 
    original_lessee, 
    agreement_date
    Acres_Gross, 
    acres_Net, 
    Participant_Name_line_1
From trust.Unit_Landresearch_Intersect
LEFT JOIN trust.All_Purpose_Land
    ON trust.Unit_Landresearch_Intersect.GIS_Link = trust.all_purpose_land.GIS_Tax_Parcel_Id
WHERE arrangement_status_description = 'Active' and agreement_type = 'fee' 


GO