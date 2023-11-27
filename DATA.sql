
USE md_water_services;

DROP TABLE IF EXISTS `auditor_report`;
CREATE TABLE `auditor_report` (
`location_id` VARCHAR(32),
`type_of_water_source` VARCHAR(64),
`true_water_source_score` int DEFAULT NULL,
`statements` VARCHAR(255)
);

USE md_water_services;
SELECT *
FROM auditor_report
LIMIT 10;

#joining visits and report table
SELECT 
	ar.location_id location_id,
    v.record_id,
    true_water_source_score auditor_score,
    subjective_quality_score employee_score
FROM visits v
JOIN auditor_report ar
ON v.location_id = ar.location_id
JOIN water_quality wq
ON wq.record_id = v.record_id;

#checking if audit and employees report match 
SELECT 
	ar.location_id location_id,
    v.record_id,
    true_water_source_score auditor_score,
    subjective_quality_score employee_score
FROM visits v
JOIN auditor_report ar
ON v.location_id = ar.location_id
JOIN water_quality wq
ON wq.record_id = v.record_id
WHERE true_water_source_score = subjective_quality_score AND v.visit_count = 1;

#checking the missmatches 
SELECT 
	ar.location_id location_id,
    v.record_id,
    true_water_source_score auditor_score,
    subjective_quality_score employee_score
FROM visits v
JOIN auditor_report ar
ON v.location_id = ar.location_id
JOIN water_quality wq
ON wq.record_id = v.record_id
WHERE true_water_source_score != subjective_quality_score AND v.visit_count = 1;

#checking the source of the missmatches
SELECT*
FROM visits
LIMIT 1;

SELECT 
	ar.location_id location_id,
    ar.type_of_water_source auditor_source,
    ws.type_of_water_source survey_source,
    v.record_id,
    true_water_source_score auditor_score,
    subjective_quality_score employee_score
FROM visits v
JOIN auditor_report ar
ON v.location_id = ar.location_id
JOIN water_quality wq
ON wq.record_id = v.record_id
JOIN water_source ws
ON ws.source_id = v.source_id
WHERE true_water_source_score != subjective_quality_score AND v.visit_count = 1;

#checking the employee with the error and creating a view 
CREATE VIEW Incorrect_records AS (
SELECT 
	ar.location_id location_id,
    v.record_id,
    employee_name,
    true_water_source_score auditor_score,
    subjective_quality_score employee_score
FROM visits v
JOIN auditor_report ar
ON v.location_id = ar.location_id
JOIN water_quality wq
ON wq.record_id = v.record_id
JOIN employee ee
ON v.assigned_employee_id = ee.assigned_employee_id
WHERE true_water_source_score != subjective_quality_score AND v.visit_count = 1);

#checking the distinct number of employees
SELECT COUNT(DISTINCT(employee_name)) employees_count
FROM Incorrect_records;

#checking the number of mistakes made by the employees
SELECT employee_name, COUNT(employee_name) mistakes
FROM Incorrect_records
GROUP BY employee_name;



#avverage no of mistakes and employeess who are above the average
WITH error_count AS (
				SELECT employee_name, COUNT(employee_name) mistakes
				FROM Incorrect_records
				GROUP BY employee_name)
	SELECT *
    FROM error_count
    WHERE mistakes > (SELECT AVG(mistakes)
					FROM error_count)
;

# creating a suspect list 
CREATE VIEW corupt_list AS (
WITH error_count AS (
				SELECT employee_name, COUNT(employee_name) mistakes
				FROM Incorrect_records
				GROUP BY employee_name)
	SELECT *
    FROM error_count
    WHERE mistakes > (SELECT AVG(mistakes)
					FROM error_count))
;

SELECT *
FROM corupt_list





#joins tables ro comeup with the desired table.
SELECT  province_name, town_name, type_of_water_source, location_type,  number_of_people_served, time_in_queue
FROM location l
JOIN visits v
ON v.location_id = l.location_id
JOIN water_source ws
ON ws.source_id = v.source_id
WHERE v.visit_count = 1
;

# This table assembles data from different tables into one to simplify analysis and creates a view
CREATE VIEW combined_analysis_table AS
SELECT
water_source.type_of_water_source,
location.town_name,
location.province_name,
location.location_type,
water_source.number_of_people_served,
visits.time_in_queue,
well_pollution.results
FROM
visits
LEFT JOIN
well_pollution
ON well_pollution.source_id = visits.source_id
INNER JOIN
location
ON location.location_id = visits.location_id
INNER JOIN
water_source
ON water_source.source_id = visits.source_id
WHERE
visits.visit_count = 1;

SELECT *
FROM combined_analysis_table
LIMIT 10;


#creating provinces totals view.
CREATE VIEW province_totals AS
WITH province_totals AS (-- This CTE calculates the population of each province
SELECT
province_name,
SUM(number_of_people_served) AS total_ppl_serv
FROM
combined_analysis_table
GROUP BY
province_name
)
SELECT
ct.province_name,
-- These case statements create columns for each type of source.
-- The results are aggregated and percentages are calculated
ROUND((SUM(CASE WHEN type_of_water_source = 'river'
THEN number_of_people_served ELSE 0 END) * 100.0 / pt.total_ppl_serv), 0) AS river,
ROUND((SUM(CASE WHEN type_of_water_source = 'shared_tap'
THEN number_of_people_served ELSE 0 END) * 100.0 / pt.total_ppl_serv), 0) AS shared_tap,
ROUND((SUM(CASE WHEN type_of_water_source = 'tap_in_home'
THEN number_of_people_served ELSE 0 END) * 100.0 / pt.total_ppl_serv), 0) AS tap_in_home,
ROUND((SUM(CASE WHEN type_of_water_source = 'tap_in_home_broken'
THEN number_of_people_served ELSE 0 END) * 100.0 / pt.total_ppl_serv), 0) AS tap_in_home_broken,
ROUND((SUM(CASE WHEN type_of_water_source = 'well'
THEN number_of_people_served ELSE 0 END) * 100.0 / pt.total_ppl_serv), 0) AS well
FROM
combined_analysis_table ct
JOIN
province_totals pt ON ct.province_name = pt.province_name
GROUP BY
ct.province_name
ORDER BY
ct.province_name;

SELECT *
FROM province_totals;

#creating town totals view
CREATE TEMPORARY TABLE town_aggregated_water_access 
WITH town_totals AS ( -- This CTE calculates the population of each town
-- Since there are two Harare towns, we have to group by province_name and town_name
SELECT province_name, town_name, SUM(number_of_people_served) AS total_ppl_serv
FROM combined_analysis_table
GROUP BY province_name,town_name
)
SELECT
ct.province_name,
ct.town_name,
ROUND((SUM(CASE WHEN type_of_water_source = 'river'
THEN number_of_people_served ELSE 0 END) * 100.0 / tt.total_ppl_serv), 0) AS river,
ROUND((SUM(CASE WHEN type_of_water_source = 'shared_tap'
THEN number_of_people_served ELSE 0 END) * 100.0 / tt.total_ppl_serv), 0) AS shared_tap,
ROUND((SUM(CASE WHEN type_of_water_source = 'tap_in_home'
THEN number_of_people_served ELSE 0 END) * 100.0 / tt.total_ppl_serv), 0) AS tap_in_home,
ROUND((SUM(CASE WHEN type_of_water_source = 'tap_in_home_broken'
THEN number_of_people_served ELSE 0 END) * 100.0 / tt.total_ppl_serv), 0) AS tap_in_home_broken,
ROUND((SUM(CASE WHEN type_of_water_source = 'well' 
THEN number_of_people_served ELSE 0 END) * 100.0 / tt.total_ppl_serv), 0) AS well
FROM
combined_analysis_table ct
JOIN -- Since the town names are not unique, we have to join on a composite key
town_totals tt ON ct.province_name = tt.province_name AND ct.town_name = tt.town_name
GROUP BY -- We group by province first, then by town.
ct.province_name,
ct.town_name
ORDER BY
ct.town_name;


SELECT *
FROM town_aggregated_water_access;

-- There are still many gems hidden in this table. For example, which town has the highest ratio of people who have taps, but have no running water?
-- Running this:
SELECT
province_name,
town_name,
ROUND(tap_in_home_broken / (tap_in_home_broken + tap_in_home) *

100,0) AS Pct_broken_taps

FROM
town_aggregated_water_access
;


CREATE TABLE Project_progress (
Project_id SERIAL PRIMARY KEY,
source_id VARCHAR(20) NOT NULL REFERENCES water_source(source_id) ON DELETE CASCADE ON UPDATE CASCADE,
Address VARCHAR(50),
Town VARCHAR(30),
Province VARCHAR(30),
Source_type VARCHAR(50),
Improvement VARCHAR(50),
Source_status VARCHAR(50) DEFAULT 'Backlog' CHECK (Source_status IN ('Backlog', 'In progress', 'Complete')),
Date_of_completion DATE,
Comments TEXT
);
SELECT * FROM project_progress;
INSERT INTO project_progress ( source_id, Address, Town, Province, Source_type, Improvement)
SELECT
water_source.source_id,
location.address,
location.town_name,
location.province_name,
water_source.type_of_water_source,
CASE
    WHEN well_pollution.results LIKE '%chemic%' THEN 'Install RO filter'
    WHEN well_pollution.results LIKE '%Biologi%' THEN 'Install UV and RO filter'
    WHEN type_of_water_source = "river" THEN "Drill well"
    WHEN type_of_water_source = "shared_tap" AND time_in_queue >= 30 THEN CONCAT( "install ", FLOOR(time_in_queue/30), " taps nearby")
    WHEN type_of_water_source LIKE "%broke%" THEN "Diagnose infrastructure"
END AS improvement
FROM
water_source
LEFT JOIN
well_pollution ON water_source.source_id = well_pollution.source_id
INNER JOIN
visits ON water_source.source_id = visits.source_id
INNER JOIN
location ON location.location_id = visits.location_id
WHERE visits.visit_count = 1 AND ( results != 'Clean' OR type_of_water_source IN ('tap_in_home_broken',"river")
												OR (type_of_water_source = 'shared_tap' AND time_in_queue >=30)

);

SELECT *
FROM combined_analysis_table;




















