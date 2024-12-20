-- Metrics

-- Q1 Total Trips

SELECT
		COUNT(*) As Total_Trips
FROM
		Transportation..fact_trips

-- Q2 Total Fare (Revenue)

SELECT
		SUM(fare_amount) as Total_Fare
FROM
		Transportation..fact_trips

-- Q3 Total Distance Travelled

SELECT
		SUM(distance_travelled_km) as Total_Distance_travelled
FROM
		Transportation..fact_trips

-- Q4 Average Rating (Passenger and Driver)

SELECT 
		ROUND(AVG(passenger_rating),2) as Avg_Passenger_rating,
		ROUND(AVG(driver_rating),2) as Avg_driver_rating
FROM
		Transportation..fact_trips

-- Q5 Average Fare per Trip

SELECT 
		ROUND(SUM(fare_amount)/COUNT(trip_id),2) as Average_fare_per_trip
FROM
		Transportation..fact_trips

-- Q6 Average Fare Per km

SELECT 
		ROUND(SUM(fare_amount)/SUM(distance_travelled_km),2) as Average_fare_per_km
FROM
		Transportation..fact_trips

-- Q7 Average Trip Distance

SELECT 
		ROUND(SUM(distance_travelled_km)/COUNT(trip_id),2) as Averag_trip_distance
FROM
		Transportation..fact_trips

-- Q8 Trip Distance (Max,Min)

SELECT
		MAX(distance_travelled_km) as max_distance,
		MIN(distance_travelled_km) as min_distance
FROM
		Transportation..fact_trips

-- Q9 Trip Type (New Trip & Repeated Trip)

SELECT 
		COUNT(CASE WHEN passenger_type ='repeated' THEN 1 END) as repeated_trip,
		COUNT(CASE WHEN passenger_type= 'new' THEN 1 END) as new_trip
FROM
		Transportation..fact_trips

-- Q10 Total Passangers

SELECT 
		SUM(total_passengers) as total_passangers
FROM
		Transportation..fact_passenger_summary

-- Q11 New Passangers

SELECT
		SUM(new_passengers) as new_passangers
FROM
		Transportation..fact_passenger_summary

-- Q12 Repeated Passangers

SELECT
		SUM(repeat_passengers) as new_passangers
FROM
		Transportation..fact_passenger_summary

-- Q13 New Vs Repeated passangers trips ratio

SELECT
		FORMAT(ROUND(COUNT(CASE WHEN passenger_type = 'new' THEN 1 END)*1.0/COUNT(passenger_type)*100,2),'N2') as new_passengers_trip_ratio,
		FORMAT(ROUND(COUNT(CASE WHEN passenger_type = 'repeated' THEN 1 END)*1.0/COUNT(passenger_type)*100,2),'N2') as repeated_passengers_trip_ratio
FROM
		Transportation..fact_trips


-- Q14 Repeat Passanger Rate (%)

SELECT 
		ROUND(SUM(repeat_passengers)/SUM(total_passengers)*100,2) as repeat_passangers_ratio
FROM 
		Transportation..fact_passenger_summary

-- Q15  Revenue Growth Rate(Monthly)
WITH Month_sales AS
(	
	SELECT 
			DATENAME(month, date) AS Month_name,
			DATEPART(month,date) AS month_num,
			YEAR(date) AS Year_name,
			SUM(fare_amount) AS revenue
	FROM
			Transportation..fact_trips
	GROUP BY 
			DATENAME(month, date),
			DATEPART(month,date),
			YEAR(date)
),
Prev_month as
(
SELECT 
		month_name,
		revenue,
		lag(revenue,1,0)OVER(ORDER BY month_num) as prev_sale

FROM 
		Month_sales
)

SELECT
		*,
		FORMAT(ROUND((revenue - prev_sale) * 1.0 / NULLIF(prev_sale, 0) * 100, 2), '0.##') AS MOM_Growth
FROM
		Prev_month

-- Target Achievement Rate
-- a) Trip Target

WITH total_trip AS
(
	SELECT
			city_id,
			COUNT(trip_id) AS trip
	FROM	
			Transportation..fact_trips
	GROUP BY
			city_id
)
SELECT
		mt.city_id,
		CONCAT(FORMAT(ROUND(CAST(total_trip.trip AS FLOAT) /CAST(SUM(total_target_trips)AS FLOAT)*100,2),'0.##'),'%') AS target_trip
FROM
		Transportation..monthly_target_trips mt
JOIN
		total_trip ON total_trip.city_id = mt.city_id
GROUP BY
		mt.city_id,
		trip

-- b) New Passangers Target

WITH total_passanger AS
(
	SELECT
			city_id,
			COUNT(passenger_type) AS passanger
	FROM	
			Transportation..fact_trips
	WHERE
			passenger_type ='New'
	GROUP BY
			city_id
)
SELECT
		mp.city_id,
		CONCAT(FORMAT(ROUND(CAST(total_passanger.passanger AS FLOAT) /CAST(SUM(target_new_passengers)AS FLOAT)*100,2),'0.##'),'%') AS achivement_passanger
FROM
		Transportation..monthly_target_new_passengers mp
JOIN
		total_passanger ON total_passanger.city_id = mp.city_id
GROUP BY
		mp.city_id,
		passanger

-- c) Average Passangers Rating Target

WITH Avg_rating AS
(
	SELECT
			city_id,
			AVG(passenger_rating) AS rating
	FROM	
			Transportation..fact_trips
	GROUP BY
			city_id
)
SELECT
		tp.city_id,
		CONCAT(FORMAT(ROUND(CAST(Avg_rating.rating AS FLOAT) /CAST(AVG(target_avg_passenger_rating)AS FLOAT)*100,2),'0.##'),'%') AS avg_achivement_rating
FROM
		Transportation..city_target_passenger_rating tp
JOIN
		Avg_rating ON Avg_rating.city_id = tp.city_id
GROUP BY
		tp.city_id,
		rating