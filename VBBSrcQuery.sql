USE [BI_FEED]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

SET NOCOUNT ON

DECLARE @NewVBBProgramCodesStart DATE
SET @NewVBBProgramCodesStart = '2013-02-04'

DECLARE @LoadEffectiveDate DATE
SELECT @LoadEffectiveDate = CAST(MAX(ll.LoadEffectiveDate) AS DATE)  -- was CAST(MAX(ll.LoadEffectiveBeginDateTime) AS DATE)
FROM EDW_SSIS_METADATA.SSIS.LoadLog ll
--WHERE LoadPackageName = 'EDW-MasterLoad'  - 04/04/2013 - Scott McQuiston - Remove filter on load of @LoadEffectiveDate

Declare @ReportStartDate SmallDatetime
Set @ReportStartDate = DATEADD(Day, -0, @LoadEffectiveDate) --> Report previous day's Information(-1), Today's after DW Load completes (-0) 

----Validation Only
			--Select @LoadEffectiveDate , @NewVBBProgramCodesStart
----Validation Only

/* CREATE TEMP TABLE TO HOLD ALL POSSIBLE MEMBERS FOR VBB PROGRAM */
IF OBJECT_ID('tempdb..#VBB_Members') is not null
DROP TABLE #VBB_Members	
CREATE TABLE #VBB_Members (
 sourcePersonId			int NULL
,SourceClientName		varchar (100) NULL
,SourceClientID			varchar (100) NULL
,Group_No				varchar (50) NULL
,BKEmpNumber			varchar (9) NULL
,Member_Suffix			varchar (2) NULL
,MemberLastName			varchar (100) NULL
,MemberFirstName		varchar (100) NULL
,AccountKey				varchar  (20) NULL
) 


--Get BCBST ProviderSubscriberID & EmployeeID instead of using EDW_Staging.dbo.GRP44_ParticipantID_Xref loaded from Flatfile - 5/16/2013 - Scott
--Get BCBST ProviderSubscriberID & EmployeeID instead of using EDW_Staging.dbo.GRP44_ParticipantID_Xref loaded from Flatfile - 5/16/2013 - Scott
if object_id('tempdb..#cteCCD') is not null 
	DROP TABLE #cteCCD
CREATE TABLE #cteCCD (
	[ClientCustomDataName] [varchar](100) NULL,
	[SourcePersonID] [int] NULL,
	[SourceClientID] [varchar](100) NULL,
	[ClientCustomDataValue] [varchar](100) NULL
)

Insert Into #cteCCD (
	  ClientCustomDataName
	, SourcePersonID
	, SourceClientID
	, ClientCustomDataValue
)
SELECT  t.ClientCustomDataName ,
        d.SourcePersonID ,
        d.SourceClientID ,
        d.ClientCustomDataValue
FROM     ODS.dbo.ClientCustomDataType t ( NOLOCK )
        JOIN ODS.dbo.ClientCustomData d ( NOLOCK ) ON d.ClientCustomDataTypeID = t.ClientCustomDataTypeID
                                      AND d.SourceClientID = t.SourceClientID
WHERE   t.ClientCustomDataName = 'BCBSTMemberID'
	and d.SourcePersonID not in ('1069442','1069443','1069444','1069445','1069446','1069447','1069448','1069449','1069450','1069451') -- Board Members
	and d.SourcePersonIsTest = 0   --ConsumerIsTestUser  
            
------- Validation Queries
			--Select * from  #cteCCD
------- Validation Queries


if object_id('tempdb..#EmployeeID_ProviderSubscriberID') is not null 
            drop table #EmployeeID_ProviderSubscriberID
CREATE TABLE #EmployeeID_ProviderSubscriberID (
	[SourcePersonClientXRefID] [bigint] NOT NULL,
	[SourceSystemID] [int] NOT NULL,
	[SourceClientID] [varchar](50) NULL,
	[SourcePersonID] [int] NOT NULL,
	[SourcePersonIsTest] [bit] NULL,
	[FromDate] [datetime] NULL,
	[ToDate] [datetime] NULL,
	[InsertDate] [datetime] NULL,
	EmployeeID 	[varchar](50) NULL,
	ProviderSubscriberID [varchar](50) NULL
)

Insert INTO  #EmployeeID_ProviderSubscriberID (
	  SourcePersonClientXRefID
	, SourceSystemID
	, SourceClientID
	, SourcePersonID
	, SourcePersonIsTest
	, FromDate
	, ToDate
	, InsertDate
	, EmployeeID
	, ProviderSubscriberID
)
SELECT  spcx.SourcePersonClientXRefID
	  , spcx.SourceSystemID
	  , spcx.SourceClientID
	  , spcx.SourcePersonID
	  , spcx.SourcePersonIsTest
	  , spcx.FromDate
	  , spcx.ToDate
	  , spcx.InsertDate --, spcx.* ,
      , EmployeeID = CASE eg.GroupID
                       WHEN 31 THEN eg.ExternalUniqueID
                       WHEN 33 THEN eg.ExternalUniqueID
                     END 
      , ProviderSubscriberID = CASE eg.GroupID                    -- Scott 1/18/2013 - update for ASO per ALAN
                                 WHEN 69 THEN eg.ExternalUniqueID	 -- 	BCBST Fully Insured
                                 WHEN 78 THEN eg.ExternalUniqueID	 -- 	BCBST ASO Comprehensive Coaching
                                 WHEN 79 THEN eg.ExternalUniqueID	 -- 	BCBST ASO Opt Out SATC
                                 WHEN 80 THEN eg.ExternalUniqueID	 -- 	BCBST ASO Self Directed Only
                                 WHEN 81 THEN eg.ExternalUniqueID	 -- 	BCBST ASO Stand Alone Physical Activity
                                 WHEN 82 THEN eg.ExternalUniqueID	 -- 	BCBST ASO Weight Management
                                 WHEN 84 THEN eg.ExternalUniqueID	 -- 	BCBST ASO 3-Call
                                 WHEN 86 THEN eg.ExternalUniqueID	 -- 	BCBST ASO Opt In SATC
                                 ELSE d.ClientCustomDataValue
                               END
FROM    ODs.dbo.SourcePersonClientXRef spcx
        JOIN EDW_Staging.OnlifeEntity.tbl_EntityGroup eg ON eg.ActorID = spcx.SourcePersonID
                                                  AND eg.GroupID = spcx.SourceClientID
                                                  AND spcx.SourceSystemID = 2
                                                  AND spcx.SourceClientID in ('31','33','69','78','79','80','81','82','84','86')    -- Scott 1/18/2013 - update for ASO per ALAN -- was AND spcx.SourceClientID in (31,33,69)
												  AND spcx.SourcePersonID not in ('1069442','1069443','1069444','1069445','1069446','1069447','1069448','1069449','1069450','1069451') -- Board Members
        LEFT JOIN #cteCCD d ON d.SourceClientID = CAST(eg.GroupID AS VARCHAR(100))
                              AND d.SourcePersonID = eg.ActorID
	and spcx.SourcePersonIsTest = 0   --ConsumerIsTestUser  
Where spcx.SourcePersonIsTest = 0   --ConsumerIsTestUser  
--Where spcx.SourceClientID in (31,33,69)                              
                              
----Validation Only
			--Select * from #EmployeeID_ProviderSubscriberID
----Validation Only

--Get BCBST ProviderSubscriberID & EmployeeID instead of using EDW_Staging.dbo.GRP44_ParticipantID_Xref loaded from Flatfile - 5/16/2013 - Scott
--Get BCBST ProviderSubscriberID & EmployeeID instead of using EDW_Staging.dbo.GRP44_ParticipantID_Xref loaded from Flatfile - 5/16/2013 - Scott


/*INSERT ALL POSSIBLE VBB PROGRAM MEMBERS INTO TEMP TABLE FOR USE IN LATER ACTIVITY QUERIES*/
INSERT INTO #VBB_Members (
  sourcePersonId
, SourceClientName
, SourceClientID
, Group_No
, BKEmpNumber
, Member_Suffix
, MemberLastName
, MemberFirstName
, AccountKey
)
SELECT   
spx.sourcepersonid
,scx.SourceClientName
,scx.SourceClientID
,COALESCE(dpsLPS.[BCBST Group Number],'NULL')
,Left(eg.ExternalUniqueID, 9) AS BKEmpNumber
,right(eg.ExternalUniqueID, 2) AS Member_Suffix
, dp.LastName AS MemberLastName
, dp.FirstName AS MemberFirstName
,dc.ClientID AS AccountKey
FROM ods.dbo.SourcePersonXref spx 
INNER JOIN EDW_Staging.OnlifeEntity.tbl_EntityGroup eg 
	ON eg.ActorID = spx.SourcePersonID
INNER JOIN ODS.dbo.SourceClientXRef scx 
	ON Cast(scx.SourceClientID as VArChar) = Cast(eg.GroupID as VarChar)
    AND scx.DataSource = 'LPS' 
    AND isPrimaryRecord = 1 
    AND scx.IsDeleted = 0 
    AND isTest = 0 
INNER JOIN ODS.dbo.PersonLPS dp 
	ON dp.ActorID = spx.SourcePersonID
    AND dp.IsCurrentRecord = 1
INNER JOIN ODS.dbo.Client  dc 
	ON dc.ClientID = scx.ClientID 
    AND dc.IsDeleted = 0 
    AND dc.isTest = 0 
INNER JOIN ODS.dbo.PopSegLPS dpsLPS 
	ON  dpsLPS.ActorID	=  spx.SourcePersonID
	and dpsLPS.GroupID  =  eg.GroupID
	AND dpsLPS.PopSegToDate = '12/31/2999'
LEFT OUTER JOIN ODS.dbo.ClientLPS gn 
	ON gn.GroupID = eg.GroupID 
    AND gn.IsCurrentRecord = 1 
    AND gn.isTestGroup = 0 
LEFT OUTER JOIN #EmployeeID_ProviderSubscriberID x     -- Use Temp Table derived form EDW/ODS data
	ON x.SourcePersonID =  spx.SourcePersonID
--LEFT OUTER JOIN EDW_Staging.dbo.GRP44_ParticipantID_Xref x 
--	ON x.SBR_EMP_NO = eg.ExternalUniqueID 
WHERE 
	spx.DataSource = 'LPS' 
	AND spx.SourcePersonIsTest = 0 
	AND spx.RecordIsDeleted = 0
	AND dp.isTestUser = 0 
	AND dp.isDeleted = 0
	AND eg.GroupID IN (69, 78, 79, 80, 81, 82, 84, 86) -- No BCBST Group 44 (33) or BCBST OLH (31) data as requested by BCBST


----Validation Only
					--Select SourceClientName, SourceClientID
					--,  Count(Distinct SourcePersonID) as DISTINCT_ACTORID
					--,  Count(1) as ROW_CNT 
					--from #VBB_Members
					--Group by  SourceClientName, SourceClientID
					--Order by  SourceClientName, SourceClientID

					--Select Count(1)  from #VBB_Members
					--Select top 100 'top 100',  * from #VBB_Members
					--Select * from #VBB_Members where BKEmpNUmber like 'VOID%'
					--Select * from #VBB_Members where BKEmpNUmber is null
					--Select * from #VBB_Members where BKEmpNUmber = ''
					--Select * from #VBB_Members where Left(BKEmpNUmber,1) <> '9' order by BKEmpNUmber
					--Select * from #VBB_Members where Len(BKEmpNUmber) > 9 or Left(BKEmpNUmber,1) <> '9' or BKEmpNUmber is null order by BKEmpNUmber
					--Select * from #VBB_Members where sourcePersonId /*ActorID*/ in ('1069442','1069443','1069444','1069445','1069446','1069447','1069448','1069449','1069450','1069451') -- Board MeEmbers

					--SELECT * FROM #VBB_Members WHERE sourcePersonId = 4177783
----Validation Only


/* CREATE TEMP TABLE FOR STORAGE OF ALL ACHIEVEMENTS */
IF OBJECT_ID('tempdb..#tempAchievementList') is not null
DROP TABLE #tempAchievementList		    
CREATE TABLE #tempAchievementList	(
SelectOrder			  int
,Group_no             varchar (50) NULL
,BKEmpNumber          varchar (30) NULL
,Member_Suffix        varchar  (2) NULL
,MemberLastName       varchar (50) NULL
,MemberFirstName      varchar (50) NULL
,DateAchievementEarned varchar  (8) NULL  -- PHADate or BIO Date
,Vendor_Name          varchar  (8) NULL  
,Vendor_Program_ID    varchar  (8) NULL  -- PHA or BIO
,MemberKey			  varchar  (20) NULL  -- PHA or BIO
,AccountKey			  varchar  (20) NULL  -- PHA or BIO
,SourceClientName		varchar (100) NULL
,SourceClientID			varchar (100) NULL
,SourceActivity			varchar (100) NULL
,SourceInsertDate       DateTime  NULL
) 


--/* CREATE TEMP TABLE TO HOLD ACHIEVEMENT DATA IN A SINGLE FIELD FOR DATA TRANSMISSION AS ~ DELIMITED FILE */
--IF OBJECT_ID('tempdb..#tempAchievementList_FlatFile') is not null
--DROP TABLE #tempAchievementList_FlatFile		
--Create table #tempAchievementList_FlatFile	(
-- All_Columns_Delimited varchar (213) NULL
--)

/*COMPLETED HEALTH ASSESSMENTS*/
INSERT INTO  #tempAchievementList (
  SelectOrder
, Group_no           
, BKEmpNumber        
, Member_Suffix      
, MemberLastName     
, MemberFirstName    
, DateAchievementEarned 
, Vendor_Name          
, Vendor_Program_ID
, MemberKey	
, AccountKey	
, SourceClientName
, SourceClientID
, SourceActivity
, SourceInsertDate
  )
SELECT DISTINCT  
  2
, v.Group_No
, v.BKempNumber
, v.Member_Suffix
, v.MemberLastName
, v.MemberFirstName
, Right('0' + Cast(Month(CAST(wfa.ActivityCompletedDate as Date)) As varchar(2)), 2)
	+ Right('0' + Cast(Day(CAST(wfa.ActivityCompletedDate as Date)) As varchar(2)), 2) 
	+ Right('0' + Cast(Year(CAST(wfa.ActivityCompletedDate as Date)) As varchar(4)), 4) as DateAchievementEarned
,'OnLife' as Vendor_Name
,'PHA' as Vendor_Program_ID
, v.sourcePersonId
, v.AccountKey
, v.SourceClientName
, v.SourceClientID
, SourceActionRequiredID as SourceActivity
,aas.InsertDate  SourceInsertDate
FROM ODS.dbo.Activity wfa
INNER JOIN  EDW_Staging.Onlife.[tbl_ActorActionStatus] aas 
    ON aas.ActorActionStatusID = wfa.SourceID 
INNER JOIN #VBB_Members v
	ON wfa.SourcePersonID = v.sourcePersonId
WHERE SourceActivityID = '1' -- Complete only
  AND wfa.SourceSystemID = 2 -- LPS
  AND
       (
              (SourceActionRequiredID in (834, 2803, 3004)  -- (Take Health Assessment, Manually Entered Paper HA, Processed Paper HA Questionnaire)
               AND CAST(wfa.ActivityCompletedDate as Date) >= @NewVBBProgramCodesStart
              )  
                     or 
              (SourceActionRequiredID in (3023)              -- ('Completed Onsite Trale Health Assessment')
               and CAST(aas.InsertDate as Date) >= @NewVBBProgramCodesStart 
               and Cast(wfa.ActivityCompletedDate as Date) >= '2012-05-15'   -- 8/6/2012 Per Alan - only completed 5/15/2012 or later
              )  
       )
  AND aas.isDeleted = 0 


----Validation Only
				--Select 'After Health A', Cast(Right(DateAchievementEarned, 4) + '-' + Left(DateAchievementEarned, 2) + '-' + Right(Left(DateAchievementEarned, 4),2) as Date) as ActivityDate, * 
				--from #tempAchievementList Where Vendor_Program_ID = 'PHA' 
				--Order by SourceClientName, SourceClientID 
				--, Cast(Right(DateAchievementEarned, 4) + '-' + Left(DateAchievementEarned, 2) + '-' + Right(Left(DateAchievementEarned, 4),2) as Date) desc 
				--, Group_no, BKEmpNumber
				--, MemberKey, AccountKey 

				--Select 'After Health A', Cast(Right(DateAchievementEarned, 4) + '-' + Left(DateAchievementEarned, 2) + '-' + Right(Left(DateAchievementEarned, 4),2) as Date) as ActivityDate, * 
				--from #tempAchievementList Where Vendor_Program_ID = 'PHA' 
				--and  DateAchievementEarned not in ('02132013','02142013')
				--Order by SourceClientName, SourceClientID 
				--, Cast(Right(DateAchievementEarned, 4) + '-' + Left(DateAchievementEarned, 2) + '-' + Right(Left(DateAchievementEarned, 4),2) as Date) desc 
				--, Group_no, BKEmpNumber
				--, MemberKey, AccountKey 

				--Select 'After Health A' as QRY_TP, Cast(Right(DateAchievementEarned, 4) + '-' + Left(DateAchievementEarned, 2) + '-' + Right(Left(DateAchievementEarned, 4),2) as Date) as ActivityDate
				--,MemberKey, AccountKey, SourceClientName, SourceClientID, SourceActivity, DateAchievementEarned
				--,Count(1) as Row_CNT, MAX(SourceInsertDate)  as MAX_SourceInsertDate, MIN(SourceInsertDate)  as MIN_SourceInsertDate
				--Into #Dup_tempAchievementList 
				--from #tempAchievementList tl Where Vendor_Program_ID = 'PHA' 
				--Group by  SourceClientName, SourceClientID
				--		, Cast(Right(DateAchievementEarned, 4) + '-' + Left(DateAchievementEarned, 2) + '-' + Right(Left(DateAchievementEarned, 4),2) as Date)
				--		, MemberKey, AccountKey,  SourceActivity, DateAchievementEarned
				--Having Count(1) > 1
				--Order by  SourceClientName, SourceClientID
				--		, Cast(Right(DateAchievementEarned, 4) + '-' + Left(DateAchievementEarned, 2) + '-' + Right(Left(DateAchievementEarned, 4),2) as Date)
				--		, MemberKey, AccountKey,  SourceActivity, DateAchievementEarned

				--Select tl.*
				--from #tempAchievementList tl
				--JOin #Dup_tempAchievementList dtl on dtl.DateAchievementEarned = tl.DateAchievementEarned and dtl.MemberKey = tl.MemberKey and dtl.AccountKey = tl.AccountKey--, SourceClientName, SourceClientID, SourceActivity, AccountKey, SourceClientName, SourceClientID, SourceActivity dtl. 
				--Where Vendor_Program_ID = 'PHA' 
				--Order by  ActivityDate desc
				--		, MemberKey, AccountKey, SourceClientName, SourceClientID, tl.SourceActivity, DateAchievementEarned
 
				--Select 'After Health A', * from #tempAchievementList Where Vendor_Program_ID = 'PHA'-- Order by ActivityCompletedDate, v.SourceClientName
----Validation Only


/* ADD MEMBERS WHO HAVE COMPLETED A TOBACCO, WEIGHT MANAGEMENT, PHYSICAL ACTIVITY, STRESS, OR NUTRITION SELF-DIRECTED COURSE */
INSERT INTO  #tempAchievementList (
  SelectOrder
, Group_no           
, BKEmpNumber        
, Member_Suffix      
, MemberLastName     
, MemberFirstName    
, DateAchievementEarned 
, Vendor_Name          
, Vendor_Program_ID
, MemberKey	
, AccountKey	
,SourceClientName
,SourceClientID
,SourceActivity
,SourceInsertDate
  )
SELECT DISTINCT   2, v.Group_No
, v.BKempNumber
, v.Member_Suffix
, v.MemberLastName
, v.MemberFirstName
, Right('0' + Cast(Month(CAST(com.ActivityDate as Date)) As varchar(2)), 2)
	+ Right('0' + Cast(Day(CAST(com.ActivityDate as Date)) As varchar(2)), 2) 
	+ Right('0' + Cast(Year(CAST(com.ActivityDate as Date)) As varchar(4)), 4) as DateAchievementEarned
,'OnLife' as Vendor_Name
,CASE
	WHEN ac.ActivityAction = 'Complete Tobacco Course' THEN 'SDT'
	WHEN ac.ActivityAction = 'Complete Weight Course' THEN 'SDW'
	WHEN ac.ActivityAction = 'Complete Nutrition Course' THEN 'SDN'
	WHEN ac.ActivityAction = 'Complete Stress Course' THEN 'SDS'
	WHEN ac.ActivityAction = 'Complete Physical Activity Course' THEN 'SDP'
  END AS Vendor_Program_ID
, v.sourcePersonId
, v.AccountKey
, v.SourceClientName
, v.SourceClientID
, ac.CourseName + ' - ' + ac.ActivityAction  SourceActivity
,'2999-01-01'  SourceInsertDate    --Select * 
FROM ods.dbo.ActivityCourse ac
INNER JOIN ods.dbo.ActivityCombined com
	ON ac.ActivityID = com.ActivityID 
INNER JOIN #VBB_Members v
	ON com.SourcePersonID = v.sourcePersonId
WHERE 
	(com.ActivityDate >= @NewVBBProgramCodesStart)
AND (ac.ActivityAction in ('Complete Tobacco Course', 'Complete Weight Course', 'Complete Nutrition Course', 'Complete Stress Course', 'Complete Physical Activity Course'))


----Validation Only
				--Select 'After Tobacco', * from #tempAchievementList  Where Vendor_Program_ID in ('SDT','SDW','SDN','SDS','SDP')
----Validation Only


/*BIOMETRIC SCREENINGS */
INSERT INTO  #tempAchievementList (
  SelectOrder
, Group_no           
, BKEmpNumber        
, Member_Suffix      
, MemberLastName     
, MemberFirstName    
, DateAchievementEarned 
, Vendor_Name          
, Vendor_Program_ID
, MemberKey	
, AccountKey
, SourceClientName
, SourceClientID
, SourceActivity
, SourceInsertDate
  )
SELECT DISTINCT 2, v.Group_No
, v.BKempNumber
, v.Member_Suffix
, v.MemberLastName
, v.MemberFirstName
, lab.LabTestDate
,'OnLife' as Vendor_Name
,'BMS' AS Vendor_Program_ID
, v.sourcePersonId
, v.AccountKey
, v.SourceClientName
, v.SourceClientID
, 'Biometric Lab'  SourceActivity
,lab.LabImportDate  SourceInsertDate	--Select * 
FROM ods.dbo.LabData lab
INNER JOIN #VBB_Members v
	ON lab.ActorID = v.sourcePersonId
WHERE 
	CONVERT(datetime,RIGHT(lab.LabTestDate,4)+LEFT(lab.LabTestDate,2)+SUBSTRING(lab.LabTestDate,3,2)) >= @NewVBBProgramCodesStart


----Validation Only
				--Select 'After BIO', * from #tempAchievementList Where Vendor_Program_ID in ('BMS')
----Validation Only


/* HEALTH COACHING ENGAGEMENT */
INSERT INTO  #tempAchievementList (
  SelectOrder
, Group_no           
, BKEmpNumber        
, Member_Suffix      
, MemberLastName     
, MemberFirstName    
, DateAchievementEarned 
, Vendor_Name          
, Vendor_Program_ID
, MemberKey	
, AccountKey	
, SourceClientName
, SourceClientID
, SourceActivity
,SourceInsertDate
  )
SELECT DISTINCT 2, v.Group_No
, v.BKempNumber
, v.Member_Suffix
, v.MemberLastName
, v.MemberFirstName
, Right('0' + Cast(Month(CAST( goal.GoalVerifiedDate as Date)) As varchar(2)), 2)
	+ Right('0' + Cast(Day(CAST( goal.GoalVerifiedDate as Date)) As varchar(2)), 2) 
	+ Right('0' + Cast(Year(CAST( goal.GoalVerifiedDate as Date)) As varchar(4)), 4) as DateAchievementEarned
,'OnLife' as Vendor_Name
,'HCE' AS Vendor_Program_ID
, v.sourcePersonId
, v.AccountKey
, v.SourceClientName
, v.SourceClientID
, SourceGoalType  SourceActivity
,'2999-01-01'  SourceInsertDate		--Select * 
FROM ods.dbo.goal
INNER JOIN #VBB_Members v
	ON goal.SourcePersonID = v.sourcePersonId
WHERE 
	goal.GoalVerifiedDate >= @NewVBBProgramCodesStart


----Validation Only
				--Select 'After COACHING', * from #tempAchievementList Where Vendor_Program_ID = 'HCE'

				--Select * from  #tempAchievementList 
				--Order by  Vendor_Program_ID, DateAchievementEarned , Vendor_Name, MemberKey	, AccountKey, SourceClientName, SourceClientID, SourceActivity,SourceInsertDate

				--Select * from  #tempAchievementList Where BKEmpNUmber not like 'VOID%'
				--Order by  Vendor_Program_ID, DateAchievementEarned , Vendor_Name, MemberKey	, AccountKey, SourceClientName, SourceClientID, SourceActivity,SourceInsertDate
----Validation Only
	

/* INSERT ANY RECORDS WHICH HAVE NOT PREVIOUSLY BEEN SENT.  
   ALL RECORDS IN THE TABLE SHOULD ALREADY BE COALESCED TO '', BUT INCLUDING IN THIS QUERY JUST TO BE SAFE */

INSERT INTO BCBST_VBB_DataSent(Group_no, BKEmpNumber, Member_Suffix, MemberFirstName, MemberLastName, DateAchievementEarned, Vendor_Program_ID, Vendor_Name)
	SELECT COALESCE(Group_no,'')			--as Group_no
	, COALESCE(BKEmpNumber,'')				--as BKEmpNumber
	, COALESCE(Member_Suffix,'')			--as Member_Suffix
	, COALESCE(MemberFirstName,'')			--as MemberFirstName
	, COALESCE(MemberLastName,'')			--as MemberLastName
	, COALESCE(DateAchievementEarned,'')	--as DateAchievementEarned
	, COALESCE(Vendor_Program_ID,'')		--as Vendor_Program_ID
	, COALESCE(Vendor_Name,'')				--as Vendor_Name				INTO #BCBST_VBB_DataSent
	FROM #tempAchievementList 

EXCEPT 

SELECT COALESCE(Group_no,'')
, COALESCE(BKEmpNumber,'')
, COALESCE(Member_Suffix,'')
, COALESCE(MemberFirstName,'')
, COALESCE(MemberLastName,'') 
, COALESCE(DateAchievementEarned,'')
, COALESCE(Vendor_Program_ID,'') 
, COALESCE(Vendor_Name,'')
FROM BCBST_VBB_DataSent
Where BKEmpNUmber not like 'VOID%'
--Order by 6,7,5,4,2,3,1


----Validation Only
				--Select * from #BCBST_VBB_DataSent
				--Order by  Vendor_Program_ID, DateAchievementEarned , Vendor_Name

				Select * FROM BCBST_VBB_DataSent Where Vendor_Program_ID = 'PHA' 
----Validation Only
