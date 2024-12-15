-- Q1 Top and Bottom Performing Cities

WITH Top_Cities As
(
	SELECT
			city_name,
			COUNT(ft.trip_id) AS Trips,
			'Top' AS position
	FROM	
			Transportation..fact_trips ft
	JOIN
			Transportation..dim_city dc ON dc.city_id = ft.city_id
	GROUP BY
			city_name
	ORDER BY
			Trips DESC OFFSET 0 ROWS FETCH NEXT 3 ROWS ONLY
),
Bottom_Cities As
(
	SELECT
			city_name,
			COUNT(ft.trip_id) AS Trips,
			'Bottom' AS position
	FROM	
			Transportation..fact_trips ft
	JOIN
			Transportation..dim_city dc ON dc.city_id = ft.city_id
	GROUP BY
			city_name
	ORDER BY
			Trips ASC OFFSET 0 ROWS FETCH NEXT 3 ROWS ONLY
)

SELECT * FROM Top_Cities
UNION ALL 
SELECT * FROM Bottom_Cities

-- Q2 Average Fare Per Trip By City

WITH average_fare As
(
	SELECT 
			dc.city_name,
			SUM(fare_amount)/COUNT(trip_id) AS fare_per_trip
	FROM
			Transportation..fact_trips ft
	JOIN
			Transportation..dim_city dc ON dc.city_id = ft.city_id
	GROUP BY
			dc.city_name
),
city_distance AS
(
	SELECT 
			dc.city_name,
			AVG(ft.distance_travelled_km) as avg_distance
	FROM		
			Transportation..fact_trips ft
	JOIN
			Transportation..dim_city dc ON dc.city_id = ft.city_id
	GROUP BY
			dc.city_name
)
SELECT
		af.city_name,
		fare_per_trip,
		cd.avg_distance
FROM	
		average_fare af
JOIN
    city_distance cd ON af.city_name = cd.city_name
ORDER BY
		af.fare_per_trip DESC

-- Q3 Average Rating By city & Passenger Type

WITH Ranked_cities AS (
    SELECT
			dc.city_name,
			ROUND(AVG(ft.passenger_rating), 2) AS Avg_passenger_rating,
			ROUND(AVG(ft.driver_rating), 2) AS Avg_driver_rating,
			ft.passenger_type,
			ROW_NUMBER() OVER (PARTITION BY ft.passenger_type ORDER BY AVG(ft.passenger_rating) DESC, AVG(ft.driver_rating) DESC) AS top_rank,
			ROW_NUMBER() OVER (PARTITION BY ft.passenger_type ORDER BY AVG(ft.passenger_rating) ASC, AVG(ft.driver_rating) ASC) AS bottom_rank
    FROM
			Transportation..fact_trips ft
    JOIN
			Transportation..dim_city dc ON dc.city_id = ft.city_id
    WHERE
			ft.passenger_type IN ('New', 'Repeated')
    GROUP BY
			dc.city_name, ft.passenger_type
)
SELECT 
		city_name, 
		Avg_passenger_rating, 
		Avg_driver_rating, 
		passenger_type, 
CASE WHEN top_rank = 1 THEN 'top' ELSE 'bottom' END AS position
FROM 
		Ranked_cities
WHERE 
		top_rank = 1 OR bottom_rank = 1;


-- Q4 Peak & Low Demand Months by city

SELECT
    city_name,
    total_trip,
    month_name,
    'High' as demand
FROM
    (
        SELECT
            city_name,
            COUNT(trip_id) AS total_trip,
            ROW_NUMBER() OVER (PARTITION BY city_name ORDER BY COUNT(trip_id) DESC) AS high_demand,
            DATENAME(month, ft.date) AS month_name
        FROM
            Transportation..fact_trips ft
        JOIN
            Transportation..dim_city dc ON dc.city_id = ft.city_id
        GROUP BY
            city_name, DATENAME(month, ft.date)
    ) AS trip_counts
WHERE high_demand = 1

UNION ALL

SELECT
    city_name,
    total_trip,
    month_name,
    'Low' AS demand
FROM
    (
        SELECT
            city_name,
            COUNT(trip_id) AS total_trip,
            ROW_NUMBER() OVER (PARTITION BY city_name ORDER BY COUNT(trip_id) ASC) AS low_demand,
            DATENAME(month, ft.date) AS month_name
        FROM
            Transportation..fact_trips ft
        JOIN
            Transportation..dim_city dc ON dc.city_id = ft.city_id
        GROUP BY
            city_name, DATENAME(month, ft.date)
    ) AS trip_counts
WHERE low_demand = 1;


-- Q5 Weekend Vs. Weekday Trip Demand by City

SELECT
		city_name,
		COUNT(CASE WHEN DATENAME(weekday, ft.date) NOT IN ('Saturday', 'Sunday') THEN trip_id END) AS weekday_trip,
		COUNT(CASE WHEN DATENAME(weekday, ft.date) IN ('Saturday', 'Sunday') THEN trip_id END) AS weekend_trip
FROM
		Transportation..fact_trips ft
JOIN
		Transportation..dim_city dc ON dc.city_id = ft.city_id
WHERE 
		ft.date >= DATEADD(MONTH, -6, ft.date)
GROUP BY
		city_name

-- Q6 Repeat Passenger Frequency and City Contribution Analysis

WITH CityTripTotals AS (
    SELECT
        rtd.city_id,
        dc.city_name,
        SUM(rtd.repeat_passenger_count) AS city_total_repeat_passengers
    FROM
        Transportation..dim_repeat_trip_distribution rtd
    JOIN
        Transportation..dim_city dc ON dc.city_id = rtd.city_id
    GROUP BY
        rtd.city_id, dc.city_name
)
SELECT
    dc.city_name,
    rtd.trip_count,
    SUM(rtd.repeat_passenger_count) AS total_repeat_passengers,
    CONCAT(CAST(ROUND(SUM(rtd.repeat_passenger_count) * 100.0 / ctt.city_total_repeat_passengers, 2)AS DECIMAL(5,2)),'%') AS percentage_of_city
FROM
    Transportation..dim_repeat_trip_distribution rtd
JOIN
    Transportation..dim_city dc ON dc.city_id = rtd.city_id
JOIN
    CityTripTotals ctt ON ctt.city_id = rtd.city_id
GROUP BY
    dc.city_name,
    rtd.trip_count,
    ctt.city_total_repeat_passengers
ORDER BY
     CAST(ROUND(SUM(rtd.repeat_passenger_count) * 100.0 / ctt.city_total_repeat_passengers, 2)AS DECIMAL(5,2)) DESC;
			


-- Q7 Monthy Target Achievement Analysis

-- A) target achievement trip
WITH target_achievement AS
(
    SELECT
        city_id,
        MONTH(month) AS month_number,
        DATENAME(month, month) AS month_name, 
        SUM(total_target_trips) AS target_trip
    FROM
        Transportation..monthly_target_trips
    GROUP BY
        city_id,
        MONTH(month), 
        DATENAME(month, month) 
)

SELECT
    ft.city_id,
    ta.month_name,
    CONCAT(ROUND(CAST(COUNT(ft.trip_id) AS FLOAT) / ta.target_trip*100,2),'%') AS trip_achievement_percentage,
	CASE 
		WHEN ROUND(CAST(COUNT(ft.trip_id) AS FLOAT) / ta.target_trip*100,2)>=100 THEN 'Exceeded'
		WHEN ROUND(CAST(COUNT(ft.trip_id) AS FLOAT) / ta.target_trip*100,2)=100 THEN 'met'
		ELSE 'missed'
	END AS trip_target_status
FROM
    Transportation..fact_trips ft
JOIN
    target_achievement ta ON ta.city_id = ft.city_id
WHERE
    MONTH(ft.date) = ta.month_number
GROUP BY
    ft.city_id,
    ta.target_trip,
    ta.month_name;
-- B) target achievement passanger
WITH passanger_achievement AS
(
    SELECT
        city_id,
        MONTH(month) AS month_number,
        DATENAME(month, month) AS month_name, 
        SUM(repeat_passenger_count) AS target_passenger
    FROM
        Transportation..dim_repeat_trip_distribution
    GROUP BY
        city_id,
        MONTH(month), 
        DATENAME(month, month) 
)

SELECT
    ft.city_id,
    pa.month_name,
    CONCAT(ROUND(CAST(COUNT(CASE WHEN ft.passenger_type ='New' THEN 1 ELSE NULL END)AS FLOAT) / pa.target_passenger*100,2),'%') AS trip_achievement_percentage,
	CASE 
		WHEN ROUND(CAST(COUNT(CASE WHEN ft.passenger_type ='New' THEN 1 ELSE NULL END)AS FLOAT) / pa.target_passenger*100,2/ pa.target_passenger*100,2)>=100 THEN 'Exceeded'
		WHEN ROUND(CAST(COUNT(CASE WHEN ft.passenger_type ='New' THEN 1 ELSE NULL END)AS FLOAT) / pa.target_passenger*100,2 / pa.target_passenger*100,2)=100 THEN 'met'
		ELSE 'missed'
	END AS passanger_target_status
FROM
    Transportation..fact_trips ft
JOIN
    passanger_achievement pa ON pa.city_id = ft.city_id
WHERE
    MONTH(ft.date) = pa.month_number
GROUP BY
    ft.city_id,
    pa.target_passenger,
    pa.month_name;
-- C) target achievement passanger
WITH Avg_passanger_rating AS
(
	SELECT
			city_id,
			AVG(target_avg_passenger_rating) as Avg_target_rating
	FROM
			Transportation..city_target_passenger_rating
	GROUP BY
			city_id
)
	SELECT
			ft.city_id,
			CONCAT(ROUND(AVG(passenger_rating)/Avg_target_rating *100,2),'%') as rating_performance,
			CASE
				WHEN ROUND(AVG(passenger_rating)/Avg_target_rating *100,2) >=100 THEN 'exceeded'
				WHEN ROUND(AVG(passenger_rating)/Avg_target_rating *100,2) = 100 THEN 'met'
				ELSE 'missed'
			END AS rating_target_status
	FROM	
			Transportation..fact_trips ft
	JOIN
			Avg_passanger_rating avr ON avr.city_id = ft.city_id
	GROUP BY
			ft.city_id,
			Avg_target_rating

-- Q8 Highest and Lowest Repeated Passanger Rate (RPR%) by city and month
--a) RPS % for each city across the six month period
WITH CityRPR AS	
(
	SELECT
			dc.city_name,
			CAST(SUM(repeat_passengers)AS FLOAT)/SUM(total_passengers)*100 as rpr_percentage
    FROM
        Transportation..fact_passenger_summary ps
    JOIN
        Transportation..dim_city dc ON dc.city_id = ps.city_id
	WHERE 
			ps.month >= DATEADD(MONTH, -6,ps.month)
	GROUP BY 
			dc.city_name
)
SELECT 
		city_name,
		CONCAT(rpr_percentage,'%') as 'rpr_%',
		position
FROM (
	SELECT
			city_name,
			rpr_percentage,
			'Top' as position
	FROM	
		CityRPR
	ORDER BY rpr_percentage DESC OFFSET 0 ROWS FETCH NEXT 2 ROWS ONLY

	UNION ALL

	SELECT
			city_name,
			rpr_percentage,
			'Bottom' as position
	FROM	
		CityRPR
	ORDER BY rpr_percentage ASC OFFSET 0 ROWS FETCH NEXT 2 ROWS ONLY) as result
ORDER BY rpr_percentage DESC

-- b) rpr% month across all cities

WITH CityRPR AS 
(
    SELECT
		DATENAME(month,ps.month) AS month_name,
        dc.city_name,
        CAST(SUM(repeat_passengers)AS FLOAT) / SUM(total_passengers)*100 AS rpr_percentage
    FROM
        Transportation..fact_passenger_summary ps
    JOIN
        Transportation..dim_city dc ON dc.city_id = ps.city_id
    WHERE 
        ps.month >= DATEADD(MONTH, -6, ps.month)
    GROUP BY 
        dc.city_name,
		ps.month
)

SELECT 
	month_name,
    CONCAT(rpr_percentage, '%') AS rpr_percentage,
	position
FROM (
    SELECT 
        month_name,
        rpr_percentage,
        'Highest' AS position
    FROM 
        CityRPR
    ORDER BY rpr_percentage DESC OFFSET 0 ROWS FETCH NEXT 1 ROWS ONLY

    UNION ALL

    SELECT 
        month_name,
        rpr_percentage,
        'Lowest' AS position
    FROM 
        CityRPR
    ORDER BY rpr_percentage ASC OFFSET 0 ROWS FETCH NEXT 1 ROWS ONLY
) AS MonthlyAnalysis

ORDER BY rpr_percentage ASC; 