-- Время активности объявлений, результат запроса отвечает на следующие вопросы:
-- 1. Какие сегменты рынка недвижимости Санкт-Петербурга и городов Ленинградской области 
--    имеют наиболее короткие или длинные сроки активности объявлений?
-- 2. Какие характеристики недвижимости, включая площадь недвижимости, среднюю стоимость квадратного метра, 
--    количество комнат и балконов и другие параметры, влияют на время активности объявлений? 
--    Как эти зависимости варьируют между регионами?
-- 3. Есть ли различия между недвижимостью Санкт-Петербурга и Ленинградской области по полученным результатам?

-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
            AND type_id = 'F8EM' -- можно присоединить таблицу, но я разово посмотрела идентификатор города
),  
-- Найдем стоимость квадратного метра
get_price_metr AS (
 SELECT 
  f.id AS id, 
   a.last_price / f.total_area AS price
  FROM real_estate.advertisement AS a 
  JOIN real_estate.flats AS f ON a.id = f.id
  WHERE f.id IN (SELECT * FROM filtered_id)
)
-- Выведем объявления без выбросов:
SELECT 
 CASE 
  WHEN f.city_id = '6X8I' THEN 'Питер'
  ELSE 'Область'
 END AS region, 
 CASE 
  WHEN a.days_exposition <= 30 THEN 'до месяца'
  WHEN a.days_exposition BETWEEN 31 AND 90 THEN 'до 3-х месяцев'
  WHEN a.days_exposition BETWEEN 91 AND 180 THEN 'до полугода'
  WHEN a.days_exposition > 180 THEN 'больше полугода'
  ELSE 'активные' 
 END AS times_case, 
 ROUND(AVG(gpm.price)::NUMERIC, 2) AS средняя_ст_метра, 
 ROUND(AVG(f.total_area)::NUMERIC, 2) AS средняя_площадь, 
 PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY rooms) AS медиана_комнат, 
 PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY balcony) AS медиана_балконов, 
 PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY floor) AS медиана_этажности, 
 count(*)
FROM real_estate.flats AS f 
JOIN real_estate.advertisement AS a ON f.id = a.id
JOIN get_price_metr AS gpm ON f.id = gpm.id
WHERE f.id IN (SELECT * FROM filtered_id)
GROUP BY region, times_case
ORDER BY region;


-- Сезонность объявлений, результат запроса отвечает на следующие вопросы:
-- 1. В какие месяцы наблюдается наибольшая активность в публикации объявлений о продаже недвижимости? 
--    А в какие — по снятию? Это показывает динамику активности покупателей.
-- 2. Совпадают ли периоды активной публикации объявлений и периоды, 
--    когда происходит повышенная продажа недвижимости (по месяцам снятия объявлений)?
-- 3. Как сезонные колебания влияют на среднюю стоимость квадратного метра и среднюю площадь квартир? 
--    Что можно сказать о зависимости этих параметров от месяца?

-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL) 
            AND type_id = 'F8EM'
),  
-- Найдем стоимость квадратного метра
get_price_metr AS (
	SELECT 
		f.id AS id, 
	 	a.last_price / f.total_area AS price
	 FROM real_estate.advertisement AS a 
	 JOIN real_estate.flats AS f ON a.id = f.id
	 WHERE f.id IN (SELECT * FROM filtered_id)
), 
get_monthes_public AS (
	SELECT 
		f.id,
		a.first_day_exposition, 
		EXTRACT(MONTH FROM a.first_day_exposition) AS number_month,
		CASE EXTRACT(MONTH FROM a.first_day_exposition)
	        WHEN 1 THEN 'Январь'
	        WHEN 2 THEN 'Февраль'
	        WHEN 3 THEN 'Март'
	        WHEN 4 THEN 'Апрель'
	        WHEN 5 THEN 'Май'
	        WHEN 6 THEN 'Июнь'
	        WHEN 7 THEN 'Июль'
	        WHEN 8 THEN 'Август'
	        WHEN 9 THEN 'Сентябрь'
	        WHEN 10 THEN 'Октябрь'
	        WHEN 11 THEN 'Ноябрь'
	        WHEN 12 THEN 'Декабрь'
	        ELSE 'Еще опубликовано'
	    END AS public_month
	FROM real_estate.flats AS f 
	JOIN real_estate.advertisement AS a ON f.id = a.id
	WHERE f.id IN (SELECT * FROM filtered_id) AND EXTRACT(YEAR FROM a.first_day_exposition) BETWEEN 2015 AND 2018
)
-- Выведем объявления:
SELECT 
	gmp.number_month, 
	gmp.public_month, 
	COUNT(gmp.id) AS count_publish,
	round(avg(m.price)::NUMERIC, 2) AS avg_price, 
	ROUND(AVG(f.total_area)::NUMERIC, 2) AS avg_area, 
	ROUND(COUNT(gmp.id)::NUMERIC / (SELECT count(*) FROM filtered_id) * 100, 2) AS part
FROM get_monthes_public AS gmp
JOIN get_price_metr AS m ON m.id = gmp.id
JOIN real_estate.flats AS f ON f.id = gmp.id
GROUP BY public_month, number_month
ORDER BY avg_area DESC;  



-- Анализ рынка недвижимости Ленобласти, результат запроса отвечает на следующие вопросы вопросы:
-- 1. В каких населённые пунктах Ленинградской области наиболее активно публикуют объявления о продаже недвижимости?
-- 2. В каких населённых пунктах Ленинградской области — самая высокая доля снятых с публикации объявлений? 
--    Это может указывать на высокую долю продажи недвижимости.
-- 3. Какова средняя стоимость одного квадратного метра и средняя площадь продаваемых квартир в различных населённых пунктах? 
--    Есть ли вариация значений по этим метрикам?
-- 4. Среди выделенных населённых пунктов какие пункты выделяются по продолжительности публикации объявлений? 
--    То есть где недвижимость продаётся быстрее, а где — медленнее.

-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы и принадлежат области:
filtered_id AS(
    SELECT f.id
	FROM real_estate.flats AS f
	WHERE total_area < (SELECT total_area_limit FROM limits)
	    AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL )
	    AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL) 
	    AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits) 
	    AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
	    AND city_id != '6X8I'
),  
-- Найдем стоимость квадратного метра
get_price_metr AS (
	SELECT 
		f.id AS id, 
	 	a.last_price / f.total_area AS price
	 FROM real_estate.advertisement AS a 
	 JOIN real_estate.flats AS f ON a.id = f.id
	 WHERE f.id IN (SELECT * FROM filtered_id)
), 
get_stop_publish AS (
	SELECT 
		c.city_id,
	    count(a.days_exposition) AS count_publish
	FROM real_estate.flats AS f
	LEFT JOIN real_estate.advertisement AS a USING(id)
	LEFT JOIN real_estate.city AS c USING(city_id)
	WHERE f.id IN (SELECT * FROM filtered_id)
	GROUP BY c.city_id
)
-- Выведем объявления:
SELECT 
	c.city, 
	--t.type,
	gs.count_publish as count_stop,
	count(*) AS count_publish,
	ROUND(gs.count_publish::numeric / count(*), 2) AS part_stop_publish,
	ROUND(AVG(a.days_exposition)::NUMERIC, 2) AS avg_count_days,
	ROUND(AVG(gpm.price)::NUMERIC, 2) AS средняя_ст_метра, 
 	ROUND(AVG(f.total_area)::NUMERIC, 2) AS средняя_площадь
FROM real_estate.flats AS f 
JOIN real_estate.advertisement AS a ON f.id = a.id
JOIN real_estate.city AS c ON c.city_id = f.city_id
JOIN get_price_metr AS gpm ON f.id = gpm.id
JOIN get_stop_publish AS gs ON gs.city_id = c.city_id
JOIN real_estate.TYPE AS t ON t.type_id = f.type_id
WHERE f.id IN (SELECT * FROM filtered_id)
GROUP BY c.city, gs.count_publish
ORDER BY count_publish DESC
LIMIT 15; 

-- В зависимости от вопроса сортировала нужные мне столбцы, чтобы проще анализировать данные