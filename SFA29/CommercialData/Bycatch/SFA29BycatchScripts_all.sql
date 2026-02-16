/* SELECT Inshore Scallop Trips in fishing year defined below */
/* J.Sameoto Jan 2018 */
/*Modified Sept 2018 J.Sameoto */
/*Modified Jan 2019 J.Raper*/
/*Modified Dec 2020 J.Raper*/
/*NOTES: need to check that you get the same number of records back for pnt_cd = 2 and if you used pnt_cd=3, if not, pnt_cd errors in data need to be reported and fixed*/
/*ensure that you cross reference the list of trips in SFA 29W with that provided by Greg Croft*/
/*not observer requirements in BoF but there are now some trips due to MSC, these need to be teased out*/
/*Must always validate positional information DO NOT TRUST COMAREA_ID */
/*From list of your trips, check unique pntcd data should only be 2 or 3s*/

--SCRIPT 1-- /*determine which trips were observed in the current year - Specify year in the script below. Save results as csv. and note TRIP #s (J-numbers) in scripts after this one*/
SELECT vessel_name, trip, comarea_id, count(*)
FROM ( 
SELECT g.cfv,
  g.vessel_name,
  g.license_no,
  b.num_hook_haul,
  b.source,
  b.set_no,
  y.board_date,
  y.landing_date,
  y.trip, 
  y.trip_id,
  x.speccd_id,
  d.common,
  x.est_num_caught,
  x.est_kept_wt,
  x.est_discard_wt,
  f.latitude,
  f.longitude,
  f.depth, 
  f.pntcd_id,
  f.setdate,
  f.settime,
  b.comarea_id 
   FROM istrips y,
  isfishsets b,
  iscatches x,
  isspeciescodes d,
  issetprofile f,
  isvessels g
  WHERE y.trip_id = b.trip_id
AND g.vess_id = y.vess_id
AND b.fishset_id = x.fishset_id
AND x.speccd_id = d.speccd_id
AND b.fishset_id = f.fishset_id
AND x.fishset_id = f.fishset_id
AND y.tripcd_id = 4320
AND f.pntcd_id = 2  /*can set to 2 or 3*/
AND y.board_date BETWEEN '2024-10-01' AND '2025-09-30'
AND g.cfv  NOT IN ('108626','152320', '106881', '105736','105912','105457','106604','106605','4062','102056','1579','102056','4055','101965','4031','1516','1518','1548','4050') /*list of offshore scallop vrns that have been observed trips*/
order by trip, set_no
) 
GROUP BY vessel_name, trip, comarea_id

--SCRIPT 2--/*check on unique pntcd_ids returns only 2 and 3 for the observered trips*/
select unique pntcd_id 
from (
SELECT g.cfv,
  g.vessel_name,
  g.license_no,
  b.num_hook_haul,
  b.source,
  b.set_no,
  y.board_date,
  y.landing_date,
  y.trip, 
  y.trip_id,
  x.speccd_id,
  d.common,
  x.est_num_caught,
  x.est_kept_wt,
  x.est_discard_wt,
  f.latitude,
  f.longitude,
  f.depth, 
  f.pntcd_id,
  f.setdate,
  f.settime,
  b.comarea_id 
   FROM istrips y,
  isfishsets b,
  iscatches x,
  isspeciescodes d,
  issetprofile f,
  isvessels g
  WHERE y.trip_id = b.trip_id
AND g.vess_id = y.vess_id
AND b.fishset_id = x.fishset_id
AND x.speccd_id = d.speccd_id
AND b.fishset_id = f.fishset_id
AND x.fishset_id = f.fishset_id
AND y.tripcd_id = 4320
AND y.trip IN ('J24-0083', 'J24-0091', 'J24-0092', 'J24-0098', 'J24-0106', 'J24-0107', 'J24-0133', 'J24-0172')
)

--SCRIPT 3--/*select observer trip data you want based on list of TRIP #s from above; CFV/VR_NUMBER, BOARD_DATE, LANDING_DATE*/
SELECT g.cfv,
  g.vessel_name,
  g.license_no,
  b.num_hook_haul,
  b.source,
  y.board_date,
  y.landing_date,
  y.trip, 
  y.trip_id,
  b.set_no,
  x.speccd_id,
  d.common,
  x.est_num_caught,
  x.est_kept_wt,
  x.est_discard_wt,
  f.latitude,
  f.longitude,
  f.depth, 
  f.pntcd_id,
  f.setdate,
  f.settime,
  b.comarea_id 
   FROM istrips y,
  isfishsets b,
  iscatches x,
  isspeciescodes d,
  issetprofile f,
  isvessels g
  WHERE y.trip_id = b.trip_id
AND g.vess_id = y.vess_id
AND b.fishset_id = x.fishset_id
AND x.speccd_id = d.speccd_id
AND b.fishset_id = f.fishset_id
AND x.fishset_id = f.fishset_id
AND y.tripcd_id = 4320
AND f.pntcd_id = 2  /*can set to 2 or 3*/
AND y.board_date BETWEEN '2023-10-01' AND '2024-09-30'
AND g.cfv  NOT IN ('152320', '106881', '105736','105912','105457','106604','106605','4062','102056','1579','102056','4055','101965','4031','1516','1518','1548','4050') /*list of offshore scallop vrns that have been observed trips*/
AND y.trip IN ('J24-0083', 'J24-0084', 'J24-0091', 'J24-0092', 'J24-0098', 'J24-0106', 'J24-0107', 'J24-0133', 'J24-0172')

--SCRIPT 4--/*DAYS_OBS for each trip (equal to number of records pulled)*/
SELECT DISTINCT TRIP, VESSEL_NAME, CFV, LICENSE_NO, SETDATE
from (
SELECT g.cfv,
  g.vessel_name,
  g.license_no,
  b.num_hook_haul,
  b.source,
  y.board_date,
  y.landing_date,
  y.trip, 
  y.trip_id,
  b.set_no,
  x.speccd_id,
  d.common,
  x.est_num_caught,
  x.est_kept_wt,
  x.est_discard_wt,
  f.latitude,
  f.longitude,
  f.depth, 
  f.pntcd_id,
  f.setdate,
  f.settime,
  b.comarea_id 
   FROM istrips y,
  isfishsets b,
  iscatches x,
  isspeciescodes d,
  issetprofile f,
  isvessels g
  WHERE y.trip_id = b.trip_id
AND g.vess_id = y.vess_id
AND b.fishset_id = x.fishset_id
AND x.speccd_id = d.speccd_id
AND b.fishset_id = f.fishset_id
AND x.fishset_id = f.fishset_id
AND y.tripcd_id = 4320
AND y.trip IN ('J24-0083', 'J24-0084', 'J24-0091', 'J24-0092', 'J24-0098', 'J24-0106', 'J24-0107', 'J24-0133', 'J24-0172')
)
Order By TRIP, SETDATE

--SCRIPT 5--/*use date range BOARD_DATE-1 and LANDING_DATE+1 to get apropriate TRIP_ID*/
SELECT * 
FROM scallop.scallop_log_marfis
WHERE vr_number = 108465
AND date_fished BETWEEN '2024-08-05' AND '2024-08-09'

--SCRIPT 6--/*total hooks (i.e. total tows observed) and OBS_TOWS*/
SELECT SUM(NUM_HOOK_HAUL) FROM (
SELECT DISTINCT TRIP, SET_NO, SOURCE, NUM_HOOK_HAUL--, comarea_id
FROM (
SELECT g.cfv,
  g.vessel_name,
  g.license_no,
  b.num_hook_haul,
  b.source, /*source indicates if set was observed or unobserved*/
  y.board_date,
  y.landing_date,
  y.trip,
  y.trip_id,
  b.set_no,
  x.speccd_id,
  d.common,
  x.est_num_caught,
  x.est_kept_wt,
  x.est_discard_wt,
  f.latitude,
  f.longitude,
  f.depth, 
  f.pntcd_id,
  f.setdate,
  f.settime,
  b.comarea_id 
   FROM istrips y,
  isfishsets b,
  iscatches x,
  isspeciescodes d,
  issetprofile f,
  isvessels g
  WHERE y.trip_id = b.trip_id
AND g.vess_id = y.vess_id
AND b.fishset_id = x.fishset_id
AND x.speccd_id = d.speccd_id
AND b.fishset_id = f.fishset_id
AND x.fishset_id = f.fishset_id
AND f.pntcd_id = 2
AND y.tripcd_id = 4320
AND y.trip in ('J24-0084')
--AND comarea_id = 'SF29B' /*include only for split trips*/
order by y.trip, b.set_no)
);

--SCRIPT 7--/*sum NUM_HOOK_HAUL for records SOURCE=0 for observed hooks */
SELECT DISTINCT TRIP, SET_NO, SOURCE, NUM_HOOK_HAUL, comarea_id
FROM (
SELECT g.cfv,
  g.vessel_name,
  g.license_no,
  b.num_hook_haul,
  b.source, /*source indicates if set was observed or unobserved*/
  y.board_date,
  y.landing_date,
  y.trip,
  y.trip_id,
  b.set_no,
  x.speccd_id,
  d.common,
  x.est_num_caught,
  x.est_kept_wt,
  x.est_discard_wt,
  f.latitude,
  f.longitude,
  f.depth, 
  f.pntcd_id,
  f.setdate,
  f.settime,
  b.comarea_id 
   FROM istrips y,
  isfishsets b,
  iscatches x,
  isspeciescodes d,
  issetprofile f,
  isvessels g
  WHERE y.trip_id = b.trip_id
AND g.vess_id = y.vess_id
AND b.fishset_id = x.fishset_id
AND x.speccd_id = d.speccd_id
AND b.fishset_id = f.fishset_id
AND x.fishset_id = f.fishset_id
AND f.pntcd_id = 2
AND y.tripcd_id = 4320
AND b.source = 0
AND y.trip in ('J24-0084'))
ORDER BY TRIP, COMAREA_ID, SET_NO

--SCRIPT 8--/*pulls the observed trip from MARFIS; MON_DOC_ID, SUM_SLIP_WT, DATE_LANDED_MARFIS*/
SELECT MON_DOC_ID, VR_NUMBER, TRIP_ID, VESSEL_NAME, DATE_LANDED, ASSIGNED_AREA, SUM_SLIP_WEIGHT_LBS
FROM scallop.scallop_log_marfis
WHERE vr_number = 106654
AND trip_id = 508523

--SCRIPT 9--/*pulls TOT_TOWS for the trip from MARFIS data*/
SELECT SUM(NUM_OF_TOWS)
FROM scallop.scallop_log_marfis
WHERE trip_id = 615933
--AND assigned_area = '29B' /*include only for split trips*/


--SCRIPT 10--/*to get bycatch discard sums - save as csv.*/
SELECT trip, common, comarea_id, source, sum(est_discard_wt), sum(est_kept_wt)
FROM (
SELECT g.cfv,
  g.vessel_name,
  g.license_no,
  b.num_hook_haul,
  b.source, /*source indicates if set was observed or unobserved*/
  y.board_date,
  y.landing_date,
  y.trip,
  y.trip_id,
  b.set_no,
  x.speccd_id,
  d.common,
  x.est_num_caught,
  x.est_kept_wt,
  x.est_discard_wt,
  f.latitude,
  f.longitude,
  f.depth, 
  f.pntcd_id,
  f.setdate,
  f.settime,
  b.comarea_id 
   FROM istrips y,
  isfishsets b,
  iscatches x,
  isspeciescodes d,
  issetprofile f,
  isvessels g
  WHERE y.trip_id = b.trip_id
AND g.vess_id = y.vess_id
AND b.fishset_id = x.fishset_id
AND x.speccd_id = d.speccd_id
AND b.fishset_id = f.fishset_id
AND x.fishset_id = f.fishset_id
AND f.pntcd_id = 2
AND y.tripcd_id = 4320
AND y.trip in ('J24-0083', 'J24-0091', 'J24-0092', 'J24-0098', 'J24-0133', 'J24-0172')
order by y.trip, b.set_no)
group by trip, common, comarea_id, source


--SCRIPT 11--/*BONUS!!! Gives you the full raw discards data. Every species by set for the specified trips.*/
SELECT g.cfv,
  g.vessel_name,
  g.license_no,
  b.num_hook_haul,
  b.source,
  y.board_date,
  y.landing_date,
  y.trip, 
  y.trip_id,
  b.set_no,
  x.speccd_id,
  d.common,
  x.est_num_caught,
  x.est_kept_wt,
  x.est_discard_wt,
  f.latitude,
  f.longitude,
  f.depth, 
  f.pntcd_id,
  f.setdate,
  f.settime,
  b.comarea_id 
   FROM istrips y,
  isfishsets b,
  iscatches x,
  isspeciescodes d,
  issetprofile f,
  isvessels g
  WHERE y.trip_id = b.trip_id
AND g.vess_id = y.vess_id
AND b.fishset_id = x.fishset_id
AND x.speccd_id = d.speccd_id
AND b.fishset_id = f.fishset_id
AND x.fishset_id = f.fishset_id
/*AND y.tripcd_id = 4320*/
/*AND f.pntcd_id = 2  /*can set to 2 or 3*/
/*AND y.board_date BETWEEN '2016-10-01' AND '2017-09-30'
AND g.cfv  NOT IN ('152320', '106881', '105736','105912','105457','106604','106605','4062','102056','1579','102056','4055','101965','4031','1516','1518','1548','4050') /*list of offshore scallop vrns that have been observed trips*/
AND y.trip IN ('J21-0144', 'J21-0119', 'J21-0133', 'J21-0118', 'J21-0131')
