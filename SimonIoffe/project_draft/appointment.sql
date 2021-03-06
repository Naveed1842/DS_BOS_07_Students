﻿
/*
select top 100
 appt_reason
,avg(case when appt_kept_ind in ('Y','1') then 1.000 else 0.000 end) avg_kept
,count(*) from QDWSQLPROD03.WAREHOUSE_PRD.[dbo].[t_appointment] 

group by appt_reason order by count(*) desc
*/


declare @sdate datetime
set @sdate='2013-12-31'  





      
--get top 25 appt_reasons	
	   		  IF OBJECT_ID('tempdb..##appt_reas') IS NOT NULL 
       DROP TABLE ##appt_reas;

	select appt_reason, row_number() over(order by countN desc) as rownum  into ##appt_reas from(
	 select top 25
	 appt_reason
	,count(*) as countN from QDWSQLPROD03.WAREHOUSE_PRD.[dbo].[t_appointment] 
		where appt_reason is not null
		and [appt_delete_ind]='N'

  	group by appt_reason order by count(*) desc
	) a

	  IF OBJECT_ID('tempdb..#pivot') IS NOT NULL 
       DROP TABLE #pivot;

	select a.appt_reason, appt_id 
	into #pivot
	from QDWSQLPROD03.WAREHOUSE_PRD.[dbo].[t_appointment]  a
	join #appt_reas b
	on a.appt_reason=b.appt_reason
	where appt_delete_ind='N'
	 and [appt_date] > @sdate--'2012-11-30'
  and [appt_date] < dateadd(month,-1,getdate())



  
 DECLARE @i int
 DECLARE @y varchar(max)
 DECLARE @y2 varchar(max)
 DECLARE @columns varchar(max)
 DECLARE @columns2 varchar(max)
 SET @i = 1 
 SET @columns=''
 SET @columns2=''

 --create columns for pivot
 WHILE (@i <=(SELECT max(rownum) from #appt_reas ))
  BEGIN
    IF @i=1 
    BEGIN
	set @y=(select appt_reason from #appt_reas where rownum=@i)
	--set @y2=(select replace(name,',','') from #appt_reas where rownum=@i)
	   set @columns=@columns +'coalesce([' +cast(@y as varchar(max))+'],0) as ['+@y+']'
	  set @columns2=@columns2 +'[' +cast(@y as varchar(max))+']'
    END
    ELSE
	BEGIN
	set @y=(select appt_reason from #appt_reas where rownum=@i)
	set @y2=(select replace(appt_reason,',','') from #appt_reas where rownum=@i)
      SET @columns=@columns +',coalesce([' +cast(@y as varchar(max))+'],0) as ['+@y+']'
     set @columns2=@columns2 +',[' +cast(@y as varchar(max))+']'
    END
 --PRINT @columns
  set @i=@i+1;
  END


	  IF OBJECT_ID('tempdb.. ##appt_reason_pivot') IS NOT NULL 
       DROP TABLE  ##appt_reason_pivot;
 
--pivot top 25 reasons for appoitnment as columns for each appoitnment
DECLARE @DynamicPivotQuery AS NVARCHAR(MAX)

SET @DynamicPivotQuery = 
  N'
   SELECT appt_id , ' + @columns + '
    into ##appt_reason_pivot
	FROM (SELECT appt_reason, appt_id 
	   FROM #pivot) AS SourceTable
    PIVOT(count([appt_reason])
          FOR [appt_reason] IN (' + @columns2 + ')) AS PVTTable '


EXEC sp_executesql @DynamicPivotQuery


IF OBJECT_ID('tempdb..#apps ') IS NOT NULL DROP TABLE #apps ;
/*

*/

--select base appoitnment
SELECT distinct 
      [appt_patient_id] as pat_id
      ,cast([appt_date] as date) as appt_date
      ,coalesce(datepart(hour,[appt_date]),[appt_begintime]) as appt_begintime
	  ,DATENAME ( dw, cast([appt_date] as date) ) weekday
  ,case when appt_kept_ind in ('Y','1') then 'K' 
  when appt_rescheduled_ind='Y' then 'R'
  when [appt_cancel_ind]='Y' then 'C' 
  end as appt_status
--,lm.location_name
,case when appt_create_timestamp <= appt_date then datediff(day, appt_create_timestamp, appt_date) else '0' end as days_made_in_advance
,ROW_NUMBER() over (partition by appt_patient_id order by appt_date desc) rownum
,appt_id
into #apps --select top 10 *
  FROM QDWSQLPROD03.WAREHOUSE_PRD.[dbo].[t_appointment] a

where [appt_delete_ind]='N'
 and [appt_date] > @sdate--'2012-11-30'
  and [appt_date] < dateadd(month,-1,getdate())




--convert appointment status to binary indicators
IF OBJECT_ID('tempdb..#appStats ') IS NOT NULL DROP TABLE #appStats ;
 select pat_id
 ,[appt_date] 
 ,case when appt_status='K' then 1 else 0 end as kept_perc
 ,case when appt_status='C' then 1 else 0 end as can_perc
 ,case when appt_status='R' then 1 else 0 end as resch_perc

 into #appStats
  from #apps

--calculate prior % appoitnment kept, looking at all appoitnment before that appointment date
  IF OBJECT_ID('tempdb..#appPerc ') IS NOT NULL DROP TABLE #appPerc ;

select 
  a.pat_id
 ,a.[appt_date] 
 ,count(*)-1 as n, avg(cast(b.kept_perc as numeric)) as kept_perc,avg(cast(b.can_perc as numeric)) as can_perc,avg(cast(b.resch_perc as numeric)) as resch_perc
  into #appPerc
  from #appStats a
  left join #appStats b
  on a.pat_id=b.pat_id
  and a.[appt_date]>b.[appt_date]
group by a.pat_id,a.[appt_date] 
order by a.pat_id,a.[appt_date] 


--bring in above calculated prior stats
  IF OBJECT_ID('tempdb..#appList ') IS NOT NULL DROP TABLE #appList ;

 select
  a.*
  ,b.appt_status as last_appt_status
  ,n
  ,kept_perc
  ,can_perc
  ,resch_perc
  into #appList
 from  #apps a
 left join #apps b
 on a.pat_id=b.pat_id
 and a.rownum=b.rownum-1
 left join  #appPerc p
 on p.pat_id=a.pat_id
 and p.appt_date=a.appt_date
 where a.appt_status is not null
 and a.appt_date>dateadd(year,1, @sdate) --only look at appoitnment a year from start date, but obtain history starting with previous year




--obtain and cleanup additional features
  IF OBJECT_ID('tempdb..#output1 ') IS NOT NULL DROP TABLE #output1 ;


 SELECT distinct 
 a.pat_id,
  datepart(month,appt_date) as app_month
 ,appt_begintime
 ,CASE weekday
                    WHEN 'Sunday' THEN 1
                    WHEN 'Monday' THEN 2
                    WHEN 'Tuesday' THEN 3
                    WHEN 'Wednesday' THEN 4
                    WHEN 'Thursday' THEN 5
                    WHEN 'Friday' THEN 6
                    WHEN 'Saturday' THEN 7
        END as weekday
,days_made_in_advance
 ,case when appt_status='K' then 1 else 0 end as kept
 ,case when appt_status='R' then 1 else 0 end as rescheduled
  ,case when appt_status='C' then 1 else 0 end as cancelled
   ,case when last_appt_status='K' then 1 when last_appt_status is null then null else 0 end as last_kept
 ,case when last_appt_status='R' then 1 when last_appt_status is null then null else 0 end as last_rescheduled
  ,case when last_appt_status='C' then 1 when last_appt_status is null then null else 0 end as last_cancelled
    ,kept_perc
  ,can_perc
  ,resch_perc
		,datediff(year,pat_date_of_birth,appt_date) as age
      ,case when [pat_ethnicity] ='Not Hispanic or Latino' or [pat_ethnicity] ='Not Hispanic/Latino' then 1 else 0 end as [eth_not_hispanic]
	  ,case when [pat_ethnicity] ='Refused to Report'  or [pat_ethnicity] ='Unreported/Refused to Report' then 1 else 0 end as [eth_refused]
	  ,case when [pat_ethnicity] ='Hispanic or Latino' or [pat_ethnicity]='Hispanic/Latino' or [pat_race]='Hispanic or Latino' then 1 else 0 end as [eth_hispanic]
	  ,case when [pat_race] ='Black or African American' or [pat_race]='Black/African American' then 1 else 0 end as [race_african_american]
	  ,case when [pat_race] ='White'  then 1 else 0 end as [race_white]
	  ,case when [pat_race] ='Asian' then 1 else 0 end as [race_asian]
	  ,case when [pat_race] ='Refused To Report' then 1 else 0 end as [race_refused]
	  ,case when [pat_race] ='Other Race' or [pat_race] ='Other' then 1 else 0 end as [race_other]
      ,case when [pat_language]='English' then 1 else 0 end as [lang_Eng]
    ,case when [pat_language]='Chinese' then 1 else 0 end as [lang_Chi]
	,case when [pat_language]='Spanish' or  [pat_language]='Spanish; Castilian' then 1 else 0 end [lang_Spa]
	,case when [pat_language]='Other' or  ([pat_language] not like '%Spanish%' and  [pat_language] not like '%English%' and  [pat_language] not like '%Chinese%' and pat_language<>'Needs Update') then 1 else 0 end as [lang_Other]

      --,case when[pat_city]='Needs Update' then NULL else [pat_city] end as city
      --,case when[pat_county]='Needs Update' then NULL else  [pat_county] end as county
      --,case when[pat_state]='Needs Update' then NULL else [pat_state]end as state
      --,case when[pat_zip]='Needs Update' then NULL else [pat_zip] end as zip
      ,case when[pat_sex] ='M' then 1 else 0 end as male
	  ,case when[pat_sex] ='F' then 1 else 0 end as female
	  ,income
	  ,appt_id
 --select distinct pat_language, count(*) as a from QDWSQLPROD03.WAREHOUSE_PRD.[dbo].t_patient group by pat_language order by a desc
 --select distinct pat_race, count(*) as a from QDWSQLPROD03.WAREHOUSE_PRD.[dbo].t_patient group by pat_race order by a desc
 --select distinct [pat_ethnicity] , count(*) as a from QDWSQLPROD03.WAREHOUSE_PRD.[dbo].t_patient group by [pat_ethnicity] order by a desc
 into #output1
 FROM #appList a
 JOIN QDWSQLPROD03.WAREHOUSE_PRD.[dbo].t_patient p
  ON a.pat_id=p.pat_id
  left join [AnalyticsMonitoring].[dbo].[wrk_zip_cost] z
  on z.zip=left(p.pat_zip,5)
  where
   --appt_date>'2014-11-13'
 -- and
   last_appt_status is not null
   and kept_perc is not null
   and can_perc is not null
   and resch_perc is not null
   and datediff(year,pat_date_of_birth,appt_date)  is not null
   and datepart(month,appt_date) is not null
   and appt_begintime is not null
  -- ) a group by appt_begintime order by appt_begintime
  and income is not null
and (ABS(CAST(
  (BINARY_CHECKSUM(*) *
  RAND()) as int)) % 100) < 40


  --get diagnosis and join to appoitnment reason pivot for final output
  select distinct
  app_month
  ,appt_begintime
  ,[weekday]
  ,days_made_in_advance
  ,kept
  ,rescheduled
  ,cancelled
  ,last_kept
  ,last_rescheduled
  ,last_cancelled
  ,kept_perc
  ,can_perc
  ,resch_perc
  ,age
  ,eth_not_hispanic
  ,eth_refused
  ,eth_hispanic
  ,lang_Eng
  ,lang_Chi
  ,lang_Spa
  ,lang_Other
  ,male
  ,female
  ,income
  ,case when p.patient_id is null then 0 else 1 end as depression
  ,ar.*
 -- into #final_output
  from #output1 a
  left join  (
	  select patient_id,max(depression) as depression, max(preg) as preg from (
			select distinct patient_id, case when icd9_code like '296%' or icd9_code like '311%' then 1 else 0 end as depression, case when icd9_code like 'v22%' or icd9_code like '650%' then 1 else 0 end as preg
			from
			QDWSQLPROD03.WAREHOUSE_PRD.[dbo].t_problem  p
			where icd9_code like '296%'
			or icd9_code like 'v22%'
			or icd9_code like '311%'
			or icd9_code like '650%'
			union
			select distinct patient_id, case when icd9_code like '296%' or icd9_code like '311%' then 1 else 0 end as depression, case when icd9_code like 'v22%' or icd9_code like '650%' then 1 else 0 end as preg
			from
			QDWSQLPROD03.WAREHOUSE_PRD.[dbo].t_assessment ta
			where icd9_code like '296%'
			or icd9_code like 'v22%'
			or icd9_code like '311%'
			or icd9_code like '650%'
			union
			  select distinct a.pat_id as patient_id
  , case when diagnosis_code like '296%' or diagnosis_code like '311%' then 1 else 0 end as depression
  , case when diagnosis_code  like 'v22%' or diagnosis_code like '650%' then 1 else 0 end as preg
   from #apps a
join QDWSQLPROD03.WAREHOUSE_PRD.mpi.person_patient pp
on pp.pat_id=a.pat_id
and pp.active_ind='Y'
join QDWSQLPROD03.WAREHOUSE_PRD.mpi.person_member pm
on pm.person_id=pp.person_id
and pm.active_ind='Y'
join QDWSQLPROD03.WAREHOUSE_PRD.dbo.plan_claim_header pch
on pch.member_id=pm.member_id
and pch.delete_ind='N'
join QDWSQLPROD03.WAREHOUSE_PRD.dbo.plan_claim_diagnosis pcd
on pcd.claim_header_id=pch.claim_header_id
and pcd.delete_ind='N'
where pcd.diagnosis_code_type='ICD9'
and (diagnosis_code like '296%'
			or diagnosis_code like 'v22%'
			or diagnosis_code like '311%')
	  ) a group by patient_id
  ) p
  on p.patient_id=a.pat_id
  left join ##appt_reason_pivot ar
  on ar.appt_id=a.appt_id


