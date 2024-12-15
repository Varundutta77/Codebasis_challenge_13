-- Business Report -1 
-- City_level Fare & Trip Summary Report

WITH Overall_trips AS
(
	SELECT
			COUNT(trip_id) as total_trips
	FROM
			Transportation..fact_trips
)
SELECT
		city_name,
		COUNT(ft.trip_id) as Total_trips,
		SUM(fare_amount)/SUM(distance_travelled_km) as Avg_fare_per_km,
		SUM(fare_amount)/COUNT(ft.trip_id) as Avg_fare_per_trip,
		CONCAT(ROUND(CAST(COUNT(ft.trip_id) AS FLOAT)/ot.total_trips*100,2),' %') as percent_contribution
FROM
		Transportation..fact_trips ft
JOIN
		Transportation..dim_city dc ON dc.city_id = ft.city_id
CROSS JOIN 
		Overall_trips ot 
GROUP BY
		city_name,
		total_trips
ORDER BY
		ROUND(CAST(COUNT(ft.trip_id) AS FLOAT)/ot.total_trips*100,2) DESC;

-- Business Report -2 
-- Monthy city-level trips target performance report
WITH target_performance AS
(
	SELECT
		city_id,
		MONTH(month) as month_num,
		DATENAME(month,month) AS month_name,
		SUM(total_target_trips) as target_trip
	FROM
		Transportation..monthly_target_trips
	GROUP BY
		city_id,
		DATENAME(month,month),
		MONTH(month)
)
SELECT
		city_name,
		tp.month_name,
		COUNT(trip_id) as actual_trip,
		tp.target_trip as target_trip,
		CASE
			WHEN ROUND(CAST(COUNT(trip_id) AS FLOAT)/tp.target_trip *100,2) >100 THEN 'Above Target'
			WHEN ROUND(CAST(COUNT(trip_id) AS FLOAT)/tp.target_trip *100,2) <= 100 THEN 'Below Target'
		END AS performace_status,
		COUNT(trip_id)-tp.target_trip AS performance_gap,
		CONCAT(ROUND(CAST(COUNT(trip_id) AS FLOAT)/tp.target_trip *100,2),'%') as '%_difference'
FROM
		Transportation..fact_trips ft
JOIN
		Transportation..dim_city dc ON dc.city_id = ft.city_id
JOIN 
		target_performance tp ON tp.city_id = ft.city_id

WHERE
		MONTH(ft.date) = tp.month_num
GROUP BY
		city_name,
		target_trip,
		tp.month_name;

-- Business Report -3
-- City_level Repeat Passanger Trip Frequency Report

SELECT
		city_name,
		CONCAT(CAST(SUM(CASE WHEN trip_count ='2-Trips' THEN repeat_passenger_count END) AS FLOAT)/SUM(repeat_passenger_count)*100,'%') as '2-trip',
		CONCAT(CAST(SUM(CASE WHEN trip_count ='3-Trips' THEN repeat_passenger_count END) AS FLOAT)/SUM(repeat_passenger_count)*100,'%') as '3-trip',
		CONCAT(CAST(SUM(CASE WHEN trip_count ='4-Trips' THEN repeat_passenger_count END) AS FLOAT)/SUM(repeat_passenger_count)*100,'%') as '4-trip',
		CONCAT(CAST(SUM(CASE WHEN trip_count ='5-Trips' THEN repeat_passenger_count END) AS FLOAT)/SUM(repeat_passenger_count)*100,'%') as '5-trip',
		CONCAT(CAST(SUM(CASE WHEN trip_count ='6-Trips' THEN repeat_passenger_count END) AS FLOAT)/SUM(repeat_passenger_count)*100,'%') as '6-trip',
		CONCAT(CAST(SUM(CASE WHEN trip_count ='7-Trips' THEN repeat_passenger_count END) AS FLOAT)/SUM(repeat_passenger_count)*100,'%') as '7-trip',
		CONCAT(CAST(SUM(CASE WHEN trip_count ='8-Trips' THEN repeat_passenger_count END) AS FLOAT)/SUM(repeat_passenger_count)*100,'%') as '8-trip',
		CONCAT(CAST(SUM(CASE WHEN trip_count ='9-Trips' THEN repeat_passenger_count END) AS FLOAT)/SUM(repeat_passenger_count)*100,'%') as '9-trip',
		CONCAT(CAST(SUM(CASE WHEN trip_count ='10-Trips' THEN repeat_passenger_count END) AS FLOAT)/SUM(repeat_passenger_count)*100,'%') as '10-trip'

FROM
		Transportation..dim_repeat_trip_distribution rtd
JOIN
		Transportation..dim_city dc ON dc.city_id = rtd.city_id
GROUP BY
		city_name

-- Business Report -4
-- Identify cities with highest & Lowest Total New passengers

SELECT 
		city_name,
		new_passenger,
		city_category
FROM (
	SELECT 
			dc.city_name,
			SUM(new_passengers) as new_passenger,
			RANK() OVER (ORDER BY SUM(new_passengers)DESC) AS ranking,
			'Top' as city_category
	FROM
		Transportation..fact_passenger_summary ps
	JOIN
			Transportation..dim_city dc ON dc.city_id = ps.city_id
	GROUP BY
			dc.city_name

	ORDER BY SUM(ps.new_passengers) DESC
		OFFSET 0 ROWS FETCH FIRST 3 ROWS ONLY
) AS top_cities

UNION ALL

SELECT 
		city_name,
		new_passenger,
		city_category
FROM (
	SELECT 
			dc.city_name,
			SUM(new_passengers) as new_passenger,
			RANK() OVER (ORDER BY SUM(new_passengers)ASC) AS ranking,
			'Bottom' as city_category
	FROM
		Transportation..fact_passenger_summary ps
	JOIN
			Transportation..dim_city dc ON dc.city_id = ps.city_id
	GROUP BY
			dc.city_name
	ORDER BY SUM(ps.new_passengers) ASC
		OFFSET 0 ROWS FETCH FIRST 3 ROWS ONLY
) AS bottom_cities

-- Business Report -5
-- Identify month with highest revenue for each city

WITH MonthlyRevenue AS (
    SELECT 
        dc.city_name,
        DATENAME(month, ft.date) AS month_name,
        SUM(ft.fare_amount) AS monthly_revenue,
        SUM(SUM(ft.fare_amount)) OVER (PARTITION BY dc.city_name) AS total_revenue,
        ROW_NUMBER() OVER (PARTITION BY dc.city_name ORDER BY SUM(ft.fare_amount) DESC) AS ranking
    FROM 
        Transportation..fact_trips ft
    JOIN 
        Transportation..dim_city dc ON dc.city_id = ft.city_id
    GROUP BY 
        dc.city_name, DATENAME(month, ft.date)
)
SELECT 
    city_name,
    month_name,
    monthly_revenue AS revenue,
    CONCAT(ROUND(CAST(monthly_revenue * 100.0 AS FLOAT)/ total_revenue,2),'%') AS percentage_contribution
FROM 
    MonthlyRevenue
WHERE 
    ranking = 1
ORDER BY 
	ROUND(CAST(monthly_revenue * 100.0 AS FLOAT)/ total_revenue,2) DESC;

-- Business Report -5
-- Repeat Passenger Rate Analysis

WITH CityAggregates AS (
    SELECT
        dc.city_id,
		dc.city_name,
        SUM(ps.repeat_passengers) AS city_repeat_passengers,
        SUM(ps.total_passengers) AS city_total_passengers
    FROM 
        Transportation..fact_passenger_summary ps
    JOIN 
        Transportation..dim_city dc ON ps.city_id = dc.city_id
    GROUP BY 
        dc.city_id,
		dc.city_name
),
MonthlyData AS (
    SELECT
        dc.city_name,
        DATENAME(month, ps.month) AS month_name,
        SUM(ps.total_passengers) AS total_passengers,
        SUM(ps.repeat_passengers) AS repeat_passengers,
        CONCAT(ROUND(CAST((SUM(ps.repeat_passengers) * 100.0) AS FLOAT)/ SUM(ps.total_passengers),2),'%') AS monthly_repeated_passenger_rate
    FROM 
        Transportation..fact_passenger_summary ps
    JOIN 
        Transportation..dim_city dc ON ps.city_id = dc.city_id
    GROUP BY 
        dc.city_name, DATENAME(month, ps.month)
)
SELECT
    m.city_name,
    m.month_name,
    m.total_passengers,
    m.repeat_passengers,
    m.monthly_repeated_passenger_rate,
    CONCAT(ROUND(CAST((c.city_repeat_passengers * 100.0) AS FLOAT) / c.city_total_passengers,2),'%')AS city_repeated_passenger_rate
FROM
    MonthlyData m
JOIN
    CityAggregates c ON m.city_name = c.city_name
ORDER BY
		ROUND(CAST((c.city_repeat_passengers * 100.0) AS FLOAT) / c.city_total_passengers,2) DESC