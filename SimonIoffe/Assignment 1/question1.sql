/****** Script for SelectTopNRows command from SSMS  ******/
SELECT distinct
	   b.yearID
	  ,c.nameFirst
	  ,c.nameLast 
	  ,cast(cast(b.H as float)/cast(b.AB as float) as numeric (10,2)) as BA
	  ,b.[G]
      ,b.[G_batting]
      ,b.[AB]
      ,b.[R]
      ,b.[H]
      ,b.[2B]
      ,b.[3B]
      ,b.[HR]
      ,b.[RBI]
      ,b.[SB]
      ,b.[CS]
      ,b.[BB]
      ,b.[SO]
      ,b.[IBB]
      ,b.[HBP]
      ,b.[SH]
      ,b.[SF]
      ,b.[GIDP]
      ,b.[G_old]
	--  ,awardID
  FROM [baseball].[dbo].[awardsplayers] a
  left join [baseball].[dbo].[batting] b
  on a.playerID=b.playerID
  and a.yearID=b.yearID
  left join [baseball].[dbo].[master] c
  on c.playerID=a.playerID
  where awardID='Triple Crown'
  order by cast(cast(b.H as float)/cast(b.AB as float) as numeric (10,2)) desc, RBI desc, HR desc