
SELECT
 POS
,cast(AVG(BA) as numeric(10,2)) as BA
,AVG(HR) as HR
,AVG(RBI) as RBI
FROM (
	SELECT distinct
		   a.POS
		  ,cast(b.H as float)/cast(b.AB as float) as BA
		  ,b.[HR]
		  ,b.[RBI]
	  FROM  [baseball].[dbo].[batting] b
	  left join [baseball].[dbo].[master] c
	  on c.playerID=b.playerID
	  left join [baseball].[dbo].[fielding] a
	  on b.playerID=a.playerID
	  where AB>=300
	  ) a
GROUP BY POS
order by POS
