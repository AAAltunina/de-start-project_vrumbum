-- Этап 1. Создание и заполнение БД

CREATE SCHEMA raw_data;

CREATE TABLE raw_data.sales(
        id integer,
		auto TEXT,
		gasoline_consumption numeric(4,2),
		price  numeric(15,2),
		date DATE,
		person_name TEXT,
		phone TEXT,
		discount integer,
		brand_origin TEXT
);		
		
		

	\copy raw_data.sales FROM 'C:/Temp/cars.csv' WITH (FORMAT csv, HEADER, DELIMITER ',', NULL 'null');
		
	


CREATE SCHEMA car_shop;

CREATE TABLE car_shop.customers(
         id SERIAL PRIMARY KEY,           --Тип SERIAL — это автоинкремент
		 person_name TEXT NOT NULL UNIQUE,       --Тип TEXT подходит для хранения произвольного текста любой длины. NOT NULL означает, что имя обязательно должно быть указано.
		 phone TEXT NOT null             -- Тип TEXT потому что телефонный номер может содержать любые символыю NOT NULL означает, что данные должны быть обязательно указаны.
);		

INSERT INTO car_shop.customers (person_name, phone)
SELECT DISTINCT person_name, phone
FROM raw_data.sales;


CREATE TABLE car_shop.colors(
        id SERIAL PRIMARY KEY,
		color_car TEXT NOT NULL  UNIQUE  --Тип TEXT подходит для хранения произвольного текста любой длины. NOT NULL означает, что данные должны быть обязательно указаны.
);

INSERT INTO car_shop.colors(color_car)
SELECT 	DISTINCT SPLIT_PART(auto, ',', -1)
FROM raw_data.sales;	

		
CREATE TABLE car_shop.countries (
    id SERIAL PRIMARY KEY,
    country_name TEXT NOT null UNIQUE
);


INSERT INTO car_shop.countries (country_name)
SELECT DISTINCT brand_origin
FROM raw_data.sales
WHERE brand_origin IS NOT NULL;


CREATE TABLE car_shop.brands (
    id SERIAL PRIMARY KEY,
    brand_name TEXT NOT NULL UNIQUE ,       --Тип TEXT подходит для хранения произвольного текста любой длины. NOT NULL означает, что данные должны быть обязательно указаны.
    country_id INTEGER REFERENCES car_shop.countries(id)
);


INSERT INTO car_shop.brands (brand_name, country_id)
SELECT DISTINCT 
    SPLIT_PART(s.auto, ' ', 1), c.id
FROM raw_data.sales AS s
LEFT JOIN car_shop.countries AS c 
    ON s.brand_origin = c.country_name;


CREATE TABLE car_shop.models(
        id SERIAL PRIMARY KEY,
        model_name TEXT NOT NULL UNIQUE,
        brand_id INTEGER REFERENCES car_shop.brands(id),
        gasoline_consumption numeric(4,2)
		) ;	


INSERT INTO	car_shop.models (model_name,brand_id, gasoline_consumption)	
SELECT 	DISTINCT TRIM(REPLACE(SPLIT_PART(auto, ',', 1), SPLIT_PART(auto, ' ', 1), '')), b.id, coalesce(s.gasoline_consumption, 0) 	
FROM raw_data.sales as s left join car_shop.brands as b on SPLIT_PART(s.auto, ' ', 1) =   b.brand_name
;

			
CREATE TABLE car_shop.purchases(
         id SERIAL PRIMARY KEY,		
		 model_id INTEGER NOT NULL REFERENCES car_shop.models (id),  --По аналогии с brand_name
		 color_car INTEGER NOT NULL REFERENCES car_shop.colors (id),    --По аналогии с brand_name
		 customer_id INTEGER NOT NULL REFERENCES car_shop.customers (id), -- По аналогии с brand_name,
		 discount integer DEFAULT 0,                                      -- Тип integer применяется для целочисленных значений, размер скидки у покупателя в процентах. DEFAULT 0 означает, что если скидка не указана, она считается равной нулю.   
		 price  numeric(15,2) NOT NULL,    
		 date DATE NOT NULL);
		 
		 
INSERT INTO car_shop.purchases (
    model_id, color_car, customer_id, discount, price, date
)
select DISTINCT
    m.id,
    c.id,
    cu.id,
    s.discount,
    s.price,
    s.date
FROM raw_data.sales s
LEFT JOIN car_shop.models m 
    ON m.model_name = TRIM(REPLACE(SPLIT_PART(auto, ',', 1), SPLIT_PART(auto, ' ', 1), ''))
   AND m.gasoline_consumption = COALESCE(s.gasoline_consumption, 0)
LEFT JOIN car_shop.colors c 
    ON c.color_car = SPLIT_PART(s.auto, ',', -1)
LEFT JOIN car_shop.customers cu 
    ON cu.person_name = s.person_name
   AND cu.phone = s.phone;   

-- Этап 2. Создание выборок

---- Задание 1. Напишите запрос, который выведет процент моделей машин, у которых нет параметра `gasoline_consumption`.


SELECT COUNT(model_name) FILTER (WHERE gasoline_consumption = 0)*100.00 /COUNT(*) AS nulls_percentage_gasoline_consumption
FROM car_shop.models;	

---- Задание 2. Напишите запрос, который покажет название бренда и среднюю цену его автомобилей в разбивке по всем годам с учётом скидки.

SELECT
      b.brand_name,
      EXTRACT(YEAR FROM p.date) AS year,
      ROUND(AVG(p.price),2) AS price_avg
FROM car_shop.purchases AS p  LEFT JOIN car_shop.models AS m on p.model_id = m.id
                              LEFT JOIN car_shop.brands AS b ON m.brand_id = b.id
GROUP BY b.brand_name,  EXTRACT(YEAR FROM p.date)
ORDER BY b.brand_name,  EXTRACT(YEAR FROM p.date);


---- Задание 3. Посчитайте среднюю цену всех автомобилей с разбивкой по месяцам в 2022 году с учётом скидки.

SELECT 
     EXTRACT( MONTH FROM date) AS month,
	 EXTRACT( YEAR FROM date) AS year,
	 ROUND(AVG(price),2) AS price_avg
FROM car_shop.purchases 
WHERE EXTRACT( YEAR FROM date) = 2022
GROUP BY  EXTRACT( MONTH FROM date), EXTRACT( YEAR FROM date);

---- Задание 4. Напишите запрос, который выведет список купленных машин у каждого пользователя.

SELECT 
    c.person_name AS person,
	STRING_AGG(b.brand_name ||' '||m.model_name, ', ') AS cars
FROM car_shop.customers AS c LEFT JOIN car_shop.purchases AS p ON c.id = p.customer_id
                             LEFT JOIN car_shop.models AS m ON p.model_id = m.id
                        	 LEFT JOIN car_shop.brands AS b ON m.brand_id = b.id
							  
GROUP BY c.person_name
ORDER BY c.person_name;							 


---- Задание 5. Напишите запрос, который покажет количество всех пользователей из США.

SELECT COUNT(person_name) 
FROM car_shop.customers
where phone ilike '+1%';

----Задание 6. Напишите запрос, который вернёт самую большую и самую маленькую цену продажи автомобиля с разбивкой по стране без учёта скидки.


SELECT 
     c.country_name AS brand_origin,
    ROUND(MAX(p.price / (1 - p.discount / 100.0)), 2) AS price_max,
    ROUND(MIN(p.price / (1 - p.discount / 100.0)), 2) AS price_min
FROM car_shop.countries AS c LEFT JOIN car_shop.brands as b on c.id = b.country_id
                             LEFT JOIN car_shop.models as m on b.id = m.brand_id 
                             LEFT JOIN car_shop.purchases AS p ON m.id = p.model_id 	 
GROUP BY c.country_name;


