SELECT ors.CreatedById, 
accts.Name, 
accts.Title,
contact.Status__c,
CASE
        WHEN contact.Status__c = 'FALSE' THEN 'Inactive'
        WHEN contact.Status__c = 'TRUE' THEN 'Active'
        ELSE '<CHECK>'
END AS Active_Status,
rpts.Name AS Reports_To,
CASE 
    When rpts.Name IN ('Mike Rush', 'Corey Peck') THEN 'Title Team Leaders'
    WHEN accts.Name = 'Amy Mayle' THEN 'WBCO Taskforce'
    WHEN accts.Name = 'Shalyn Martell' THEN 'Bullpen Taskforce'
    WHEN accts.Name = 'Brenda Weir' THEN 'TIL Taskforce'
    WHEN accts.Name = 'Bobbi Greene' THEN 'Payments Taskforce'
    WHEN accts.Name = 'Tyler Clifford' THEN 'TIL Taskforce'
    WHEN accts.Name = 'Ryan Wagley' THEN 'Requests Taskforce'
    WHEN accts.Name = 'Abigail Marusic' THEN 'Requests Taskforce'
    WHEN accts.Name = 'Ross Oberdick' THEN 'Requests Taskforce'
    WHEN rpts.Name = 'Amy Mayle' THEN 'WBCO Taskforce'
    WHEN rpts.Name = 'Shalyn Martell' THEN 'Bullpen Taskforce'
    WHEN rpts.Name = 'Brenda Weir' THEN 'TIL Taskforce'
    WHEN rpts.Name = 'Bobbi Greene' THEN 'Payments Taskforce'
    WHEN rpts.Name = 'Ross Oberdick' THEN 'Requests Taskforce'
    WHEN rpts.Name = 'Zita Lammay' THEN 'Title Admin Taskforce'
    ELSE 'Oops'
    END AS Taskforce,
CONCAT('Title Analyst ', ROW_NUMBER()OVER(ORDER BY accts.Name)) AS Title_Analyst,
COUNT(DISTINCT CONVERT(date, ors.CreatedDate, 103)) AS Active_Days, 
COUNT(ors.Id) AS Ownership_Rights_Created, 
CAST((CAST(COUNT(ors.Id) AS DECIMAL(10,4))/CAST(COUNT(DISTINCT CONVERT(date, ors.CreatedDate, 103)) AS decimal(10,4))) AS DECIMAL(10,4)) AS Avg_ORs_Per_Active_Day
FROM [heart].[sf_ownership_rights__c] AS ors
LEFT JOIN [heart].[sf_user] AS accts ON accts.Id = ors.CreatedById
LEFT JOIN [heart].[sf_contact] AS contact ON contact.user__c = accts.id
LEFT JOIN [heart].[sf_contact] AS rpts ON rpts.id = contact.ReportsToId
WHERE ors.CreatedDate > '1/1/2021' AND accts.Title LIKE ('%Title%') AND (ors.RecordTypeId = '0125000000022zNAAQ' OR ors.RecordTypeId = '0125000000022zSAAQ') AND accts.name NOT LIKE ('%Onge')
GROUP BY ors.CreatedById, accts.Name, accts.Title, rpts.Name,contact.Status__c, CASE 
    When rpts.Name IN ('Mike Rush', 'Corey Peck') THEN 'Title Team Leaders'
    WHEN accts.Name = 'Amy Mayle' THEN 'WBCO Taskforce'
    WHEN accts.Name = 'Shalyn Powell' THEN 'Bullpen Taskforce'
    WHEN accts.Name = 'Brenda Weir' THEN 'TIL Taskforce'
    WHEN accts.Name = 'Bobbi Greene' THEN 'Payments Taskforce'
    WHEN accts.Name = 'Tyler Clifford' THEN 'TIL Taskforce'
    WHEN accts.Name = 'Ryan Wagley' THEN 'Requests Taskforce'
    WHEN accts.Name = 'Abigail Marusic' THEN 'Requests Taskforce'
    WHEN rpts.Name = 'Ross Oberdick' THEN 'Requests Taskforce'
    WHEN rpts.Name = 'Amy Mayle' THEN 'WBCO Taskforce'
    WHEN rpts.Name = 'Shalyn Powell' THEN 'Bullpen Taskforce'
    WHEN rpts.Name = 'Brenda Weir' THEN 'TIL Taskforce'
    WHEN rpts.Name = 'Bobbi Greene' THEN 'Payments Taskforce'
    WHEN rpts.Name = 'Ross Oberdick' THEN 'Requests Taskforce'
    ELSE 'Oops'
    END
HAVING CASE 
    When rpts.Name IN ('Mike Rush', 'Corey Peck') THEN 'Title Team Leaders'
    WHEN accts.Name = 'Amy Mayle' THEN 'WBCO Taskforce'
    WHEN accts.Name = 'Shalyn Martell' THEN 'Bullpen Taskforce'
    WHEN accts.Name = 'Brenda Weir' THEN 'TIL Taskforce'
    WHEN accts.Name = 'Bobbi Greene' THEN 'Payments Taskforce'
    WHEN accts.Name = 'Tyler Clifford' THEN 'TIL Taskforce'
    WHEN accts.Name = 'Ryan Wagley' THEN 'Requests Taskforce'
    WHEN accts.Name = 'Abigail Marusic' THEN 'Requests Taskforce'
    WHEN accts.Name = 'Ross Oberdick' THEN 'Requests Taskforce'
    WHEN rpts.Name = 'Amy Mayle' THEN 'WBCO Taskforce'
    WHEN rpts.Name = 'Shalyn Martell' THEN 'Bullpen Taskforce'
    WHEN rpts.Name = 'Brenda Weir' THEN 'TIL Taskforce'
    WHEN rpts.Name = 'Bobbi Greene' THEN 'Payments Taskforce'
    WHEN rpts.Name = 'Ross Oberdick' THEN 'Requests Taskforce'
    WHEN rpts.Name = 'Zita Lammay' THEN 'Title Admin Taskforce'
    ELSE 'Oops'
    END <> 'Oops'