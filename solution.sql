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
		 person_name TEXT NOT NULL,       --Тип TEXT подходит для хранения произвольного текста любой длины. NOT NULL означает, что имя обязательно должно быть указано.
		 phone TEXT NOT NULL,             -- Тип TEXT потому что телефонный номер может содержать любые символыю NOT NULL означает, что данные должны быть обязательно указаны.
		 discount integer DEFAULT 0,   -- Тип integer применяется для целочисленных значений, размер скидки у покупателя в процентах. DEFAULT 0 означает, что если скидка не указана, она считается равной нулю.
		 brand_origin TEXT              -- Тип TEXT подходит для хранения произвольного текста любой длины
);	

INSERT INTO car_shop.customers (person_name, phone, discount, brand_origin)
SELECT DISTINCT person_name, phone, discount, brand_origin
FROM raw_data.sales;


CREATE TABLE car_shop.colors(
        id SERIAL PRIMARY KEY,
		color_car TEXT NOT NULL    --Тип TEXT подходит для хранения произвольного текста любой длины. NOT NULL означает, что данные должны быть обязательно указаны.
);

INSERT INTO car_shop.colors(color_car)
SELECT 	DISTINCT SPLIT_PART(auto, ',', -1)
FROM raw_data.sales	
		
CREATE TABLE car_shop.brands(
        id SERIAL PRIMARY KEY,
        brand_name TEXT NOT NULL);    --Тип TEXT подходит для хранения произвольного текста любой длины. NOT NULL означает, что данные должны быть обязательно указаны.

INSERT INTO	car_shop.brands (brand_name)
SELECT 	DISTINCT SPLIT_PART(auto, ' ', 1)
FROM raw_data.sales		
		
CREATE TABLE car_shop.models(
        id SERIAL PRIMARY KEY,
        model_name TEXT NOT NULL,
		gasoline_consumption numeric(4,2)  --Тип numeric позволяет точно хранить дробные значения.
		) ;	
INSERT INTO	car_shop.models (model_name, gasoline_consumption)	
SELECT DISTINCT	SPLIT_PART(SPLIT_PART(auto, ',', -2), ' ',2), coalesce(gasoline_consumption, 0) 	
FROM raw_data.sales;

			
CREATE TABLE car_shop.purchases(
         id SERIAL PRIMARY KEY,		
		 brand_name INTEGER NOT NULL REFERENCES car_shop.brands (id),  --Внешний ключ на таблицу брендов.Тип INTEGER, потому что это ссылка на числовой id из таблицы брендов.
		 
		 model_name INTEGER NOT NULL REFERENCES car_shop.models (id),  --По аналогии с brand_name
		 color_car INTEGER NOT NULL REFERENCES car_shop.colors (id),    --По аналогии с brand_name
		 customer_id INTEGER NOT NULL REFERENCES car_shop.customers (id), -- По аналогии с brand_name
		 price  numeric(15,2) NOT NULL,    
		 date DATE NOT NULL);
		 
		 
INSERT INTO car_shop.purchases (
    brand_name, model_name, color_car, customer_id, price, date
)
select DISTINCT
    b.id,
    m.id,
    c.id,
    cu.id,
    s.price,
    s.date
FROM raw_data.sales s
left JOIN car_shop.brands b 
    ON b.brand_name = SPLIT_PART(s.auto, ' ', 1)
left JOIN car_shop.models m 
    ON m.model_name = SPLIT_PART(SPLIT_PART(s.auto, ',', -2), ' ', 2)
   AND m.gasoline_consumption = COALESCE(s.gasoline_consumption, 0)
left JOIN car_shop.colors c 
    ON c.color_car = SPLIT_PART(s.auto, ',', -1)
left JOIN car_shop.customers cu 
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
FROM car_shop.purchases AS p  LEFT JOIN car_shop.brands AS b ON p.brand_name = b.id
GROUP BY b.brand_name,  EXTRACT(YEAR FROM p.date)
order BY b.brand_name,  EXTRACT(YEAR FROM p.date);


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
                        	 LEFT JOIN car_shop.brands AS b ON p.brand_name = b.id
							             LEFT JOIN car_shop.models AS m ON p.model_name = m.id
GROUP BY c.person_name
ORDER BY c.person_name;	

---- Задание 5. Напишите запрос, который покажет количество всех пользователей из США.

SELECT COUNT(person_name) 
FROM car_shop.customers
where brand_origin = 'USA';

----Задание 6. Напишите запрос, который вернёт самую большую и самую маленькую цену продажи автомобиля с разбивкой по стране без учёта скидки.

SELECT 
     c.brand_origin AS brand_origin,
    ROUND(MAX(p.price / (1 - c.discount / 100.0)), 2) AS price_max,
    ROUND(MIN(p.price / (1 - c.discount / 100.0)), 2) AS price_min
FROM car_shop.customers AS c LEFT JOIN car_shop.purchases AS p ON c.id = p.customer_id	 
GROUP BY c.brand_origin;



