
SET search_path TO atl_restaurants_db;

CREATE SCHEMA atlanta_restaurants_schema;

SET search_path TO atlanta_restaurants_schema;

SHOW search_path;

-- create table for reviews

DROP TABLE IF EXISTS atlanta_restaurants_reviews;

CREATE TABLE atlanta_restaurants_reviews(
   title           VARCHAR(255) NOT NULL
  ,categoryName   VARCHAR(255) 
  ,reviewsCount   INTEGER 
  ,stars          INTEGER  
  ,text           TEXT
  ,website        TEXT
  ,map_url TEXT NOT NULL
);


-- Note the original dataset from kaggle is in 5 parts, I have already appended
-- the tables, done some data transformation and preprocessing using Excel, 
-- and also scrapped some data using Python to get the restaurants address

-- In total, we have about approximately 127,415 rows of data in the appended reviews table

SELECT * FROM atlanta_restaurants_reviews;


-- Data cleaning, transformations and normalization

-- create table for restaurants_info

DROP TABLE IF EXISTS atlanta_restaurants_info;

CREATE TABLE atlanta_restaurants_info(
	name VARCHAR(255), 
	categoryName VARCHAR(255),
	address VARCHAR(255),
	website TEXT,
	map_url TEXT
);

-- import data for atlanta restaurant info using the 
-- pgadmin import tool

SELECT * 
FROM atlanta_restaurants_info;



-- Data normalization

-- Before the analysis, I need to normalize both tables
-- for best practices in database design and data management.
-- Also, normalizing the tables will keep them streamlined and efficient.

-- Start with the atlanta_restaurants_info table

DROP TABLE IF EXISTS restaurant_info;

CREATE TABLE restaurant_info(
	name VARCHAR(255), 
	category_name VARCHAR(255),
	address VARCHAR(255),
	website TEXT NULL,
	map_url TEXT NOT NULL
);


-- Insert the data

INSERT INTO restaurant_info (name, category_name, address, website, map_url)
SELECT name,
	   categoryname AS category_name,
	   address,
	   website,
	   map_url
FROM atlanta_restaurants_info;


-- check if there are duplicates

WITH duplicate_cte AS
(
SELECT *, ROW_NUMBER() OVER(PARTITION BY name, category_name, address, website, map_url) AS row_num
FROM restaurant_info
)
SELECT *
FROM duplicate_cte
WHERE row_num > 1;


-- returns no row, so there are no duplicates


-- add a primary key to the table

ALTER TABLE restaurant_info ADD COLUMN id SERIAL PRIMARY KEY;

SELECT * FROM restaurant_info;


-- reordering the columns

CREATE TABLE restaurant_info_new AS 
SELECT id, name, category_name, address, website, map_url
FROM restaurant_info;


-- drop the old restaurant_info table

DROP TABLE restaurant_info;


-- rename the new table to the restaurant_info table we want

ALTER TABLE restaurant_info_new RENAME TO restaurant_info;

SELECT * 
FROM restaurant_info;


-- add a primary key constraint

ALTER TABLE restaurant_info ADD CONSTRAINT restaurant_info_pk PRIMARY KEY (id);


SELECT *
FROM restaurant_info;



-- for the atlanta_restaurants_reviews table

SELECT * FROM atlanta_restaurants_reviews;



DROP TABLE IF EXISTS reviews;

CREATE TABLE reviews (
	review_id SERIAL PRIMARY KEY,
	restaurant_id INTEGER REFERENCES restaurant_info(id),
	name VARCHAR(255) NOT NULL,
    rating INTEGER CHECK (rating BETWEEN 1 AND 5),
	review_text TEXT,
    reviews_count INTEGER
);




-- Insert the relevant data into reviews table

INSERT INTO reviews (name, rating, review_text, reviews_count)
SELECT title AS name,
	   stars AS rating,
	   text AS review_text,
	   reviewscount AS reviews_count
FROM atlanta_restaurants_reviews;



-- Update the restaurant_reviews table to link the 
-- restaurant_id based on the restaurant_name

UPDATE reviews AS rr
SET restaurant_id = ri.id
FROM restaurant_info AS ri
WHERE rr.name = ri.name;



-- Inspecting our restaurant reviews table

SELECT * FROM reviews;


-- drop name column from reviews table as we already have the restaurant_id

ALTER TABLE reviews DROP COLUMN name;



-- Add a foreign key constraint to enforce the relationship

ALTER TABLE reviews 
ADD CONSTRAINT reviews_restaurant_id_fk 
FOREIGN KEY (restaurant_id) 
REFERENCES restaurant_info(id);



-- Inspect our tables

SELECT * FROM restaurant_info;
SELECT * FROM reviews;


-- Add indexes on columns that will be frequently searched or used in joins

CREATE INDEX idx_restaurant_name ON restaurant_info(name);
CREATE INDEX idx_restaurant_category ON restaurant_info(category_name);


-- Next, I will implement search functionality
-- This allows for efficient fuzzy searching across multiple fields.

CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Create a GIN (Generalized Inverted Index) index for faster full-text search

CREATE INDEX idx_restaurant_info_fulltext ON restaurant_info
USING gin ((name || ' ' || category_name || ' ' || address) gin_trgm_ops);


-- Create a GIN index for faster full-text search on the reviews table

CREATE INDEX idx_reviews_fulltext ON reviews
USING gin (review_text gin_trgm_ops);


-- Inspecting our review table

SELECT * FROM reviews
ORDER BY review_id;


-- Now, I notice some restaurant have multiple branches or chains in 
-- different cities, we need to standardize the data to address this issue

-- Step 1: Alter the table to add new columns, chain_name and branch_name

ALTER TABLE restaurant_info
ADD COLUMN chain_name VARCHAR(255),
ADD COLUMN branch VARCHAR(255);

SELECT * FROM restaurant_info;


-- Inspecting our restaurant_info, I noticed that the branches are most likely in
-- areas or cities like Sandy Springs, Peachtree City, Atlanta, Cumming, Dunwoody

-- 1. Handle 

SELECT 
    name,
    CASE
        WHEN name ~ '.* in (Sandy Springs|Peachtree City|Atlanta|Cumming|Dunwoody)(, GA)?$' 
        THEN REGEXP_REPLACE(name, ' in (Sandy Springs|Peachtree City|Atlanta|Cumming|Dunwoody)(, GA)?$', '')
        ELSE name
    END AS chain_name,
    CASE
        WHEN name ~ '.* in (Sandy Springs|Peachtree City|Atlanta|Cumming|Dunwoody)(, GA)?$'
        THEN REGEXP_REPLACE(name, '.* in ((Sandy Springs|Peachtree City|Atlanta|Cumming|Dunwoody)(, GA)?)$', '\1')
        ELSE NULL
    END AS branch_name
FROM restaurant_info
WHERE name ~ '.* in (Sandy Springs|Peachtree City|Atlanta|Cumming|Dunwoody)(, GA)?$';


-- update the chain_name and branch_name column

UPDATE restaurant_info
SET 
    chain_name = REGEXP_REPLACE(name, ' in (Sandy Springs|Peachtree City|Atlanta|Cumming|Dunwoody)(, GA)?$', ''),
    branch = REGEXP_REPLACE(name, '.* in ((Sandy Springs|Peachtree City|Atlanta|Cumming|Dunwoody)(, GA)?)$', '\1')
WHERE name ~ '.* in (Sandy Springs|Peachtree City|Atlanta|Cumming|Dunwoody)(, GA)?$';



-- 2. Handle Names with "(Avenue)" or similar at the end:

SELECT 
    name,
    REGEXP_REPLACE(name, ' \([^)]+\)$', '') AS chain_name,
    REGEXP_REPLACE(name, '.* \(([^)]+)\)$', '\1') AS branch_name
FROM restaurant_info
WHERE name ~ '.* \([^)]+\)$' AND name NOT LIKE '% in %';


UPDATE restaurant_info
SET 
    chain_name = REGEXP_REPLACE(name, ' \([^)]+\)$', ''),
    branch = REGEXP_REPLACE(name, '.* \(([^)]+)\)$', '\1')
WHERE name ~ '.* \([^)]+\)$' AND name NOT LIKE '% in %' AND chain_name IS NULL;



-- 3. Handle Names ending with "-[City]":

SELECT 
    name,
    REGEXP_REPLACE(name, '-(Sandy Springs|Peachtree City|Atlanta|Cumming|Dunwoody|Marietta Square)$', '') AS chain_name,
    REGEXP_REPLACE(name, '.*-(Sandy Springs|Peachtree City|Atlanta|Cumming|Dunwoody|Marietta Square)$', '\1') AS branch_name
FROM restaurant_info
WHERE name ~ '.-(Sandy Springs|Peachtree City|Atlanta|Cumming|Dunwoody|Marietta Square)$';


UPDATE restaurant_info
SET 
    chain_name = REGEXP_REPLACE(name, '-(Sandy Springs|Peachtree City|Atlanta|Cumming|Dunwoody|Marietta Square)$', ''),
    branch = REGEXP_REPLACE(name, '.*-(Sandy Springs|Peachtree City|Atlanta|Cumming|Dunwoody|Marietta Square)$', '\1')
WHERE name ~ '.-(Sandy Springs|Peachtree City|Atlanta|Cumming|Dunwoody|Marietta Square)$' AND chain_name IS NULL;


-- Inspecting our table

SELECT name, chain_name, branch_name
FROM restaurant_info
WHERE chain_name IS NOT NULL;





-- 4. Names ending with "[City]" without a separator:

SELECT 
    name,
    REGEXP_REPLACE(name, '(Sandy Springs|Peachtree City|Atlanta|Cumming|Dunwoody|Marietta)$', '') AS chain_name,
    REGEXP_REPLACE(name, '.*(Sandy Springs|Peachtree City|Atlanta|Cumming|Dunwoody|Marietta)$', '\1') AS branch
FROM restaurant_info
WHERE name ~ '.*(Sandy Springs|Peachtree City|Atlanta|Cumming|Dunwoody|Marietta)$' AND name NOT LIKE '%-%'
AND name NOT LIKE '% in %';



UPDATE restaurant_info
SET 
    chain_name = TRIM(REGEXP_REPLACE(name, '(Sandy Springs|Peachtree City|Atlanta|Cumming|Dunwoody|Marietta)$', '')),
    branch = REGEXP_REPLACE(name, '.*(Sandy Springs|Peachtree City|Atlanta|Cumming|Dunwoody|Marietta)$', '\1')
WHERE name ~ '.*(Sandy Springs|Peachtree City|Atlanta|Cumming|Dunwoody|Marietta)$' 
AND name NOT LIKE '%-%' AND name NOT LIKE '% in %' AND chain_name IS NULL;


SELECT name, branch_name, chain_name
FROM restaurant_info;


-- Handle "[City]" at the end without separator

SELECT name, CASE WHEN name ~ '(Sandy Springs|Peachtree City|Atlanta|Cumming|Dunwoody|Marietta)$' 
				THEN REGEXP_REPLACE(name, '(Sandy Springs|Peachtree City|Atlanta|Cumming|Dunwoody|Marietta)$', '') 
				END AS chain_name,
				REGEXP_REPLACE(name, '.*(Sandy Springs|Peachtree City|Atlanta|Cumming|Dunwoody|Marietta)$', '\1') AS branch
FROM restaurant_info
WHERE name NOT LIKE '% of %' AND branch IS NOT NULL
AND name NOT LIKE '%(%' AND name NOT LIKE '% in %'
AND chain_name IS NULL;

-- Inspect the columns

SELECT name, chain_name, branch
FROM restaurant_info
WHERE chain_name IS NULL AND name ~ '(Sandy Springs|Peachtree City|Atlanta|Cumming|Dunwoody|Marietta)$';


SELECT 
    name, 
    REGEXP_REPLACE(name, ' - .*| -.*|- .*', '') AS chain_name,  -- Extracts everything before the first ' - ' or '-' without space
    REGEXP_REPLACE(name, '.*- ', '') AS branch     -- Extracts everything after the last ' - ' (with no space before)
FROM restaurant_info
WHERE 
    chain_name IS NULL 
    AND name ~ '(Sandy Springs|Peachtree City|Atlanta|Cumming|Dunwoody|Marietta)$';


UPDATE restaurant_info
SET chain_name = TRIM(REGEXP_REPLACE(name, ' - .*| -.*|- .*', '')),
	branch = TRIM(REGEXP_REPLACE(name, '.*- ', ''))
WHERE chain_name IS NULL 
    AND name ~ '(Sandy Springs|Peachtree City|Atlanta|Cumming|Dunwoody|Marietta)$';			
			 
			 

-- Inspect the columns

-- try to extract other forms of the chain_name and branch_name

SELECT name, chain_name, branch
FROM restaurant_info
WHERE chain_name IS NULL AND name ~ '(Sandy Springs, GA|Peachtree City, GA|Atlanta, GA|Cumming, GA|Dunwoody, GA|Marietta, GA)'



SELECT 
    name, 
	REGEXP_REPLACE(name, ' - .*', '') AS chain_name,
    REGEXP_REPLACE(name, '.* - (.*), GA', '\1') AS branch
FROM restaurant_info
WHERE 
    chain_name IS NULL 
    AND name ~ '(Sandy Springs, GA|Peachtree City, GA|Atlanta, GA|Cumming, GA|Dunwoody, GA|Marietta, GA)';
	
	
UPDATE restaurant_info
SET chain_name = REGEXP_REPLACE(name, ' - .*', ''),
	branch = REGEXP_REPLACE(name, '.* - (.*), GA', '\1')
WHERE 
    chain_name IS NULL 
    AND name ~ '(Sandy Springs, GA|Peachtree City, GA|Atlanta, GA|Cumming, GA|Dunwoody, GA|Marietta, GA)';



-- Inspect the columns

SELECT name, chain_name, branch
FROM restaurant_info;



-- There are 2 restaurants with mutiple branches we have not handled because of their names
-- Firehouse Subs, Partners II Pizza

-- for Firehouse Subs Restaurant

SELECT 
    name,
    TRIM(SPLIT_PART(name, ' ', 1)) || ' ' || TRIM(SPLIT_PART(name, ' ', 2)) AS chain_name,
    TRIM(SPLIT_PART(name, ' ', 3)) || ' ' || TRIM(SPLIT_PART(name, ' ', 4)) AS branch
FROM restaurant_info
WHERE name LIKE 'Firehouse Subs%';


UPDATE restaurant_info
SET chain_name = TRIM(SPLIT_PART(name, ' ', 1)) || ' ' || TRIM(SPLIT_PART(name, ' ', 2)),
	branch = TRIM(SPLIT_PART(name, ' ', 3)) || ' ' || TRIM(SPLIT_PART(name, ' ', 4))
WHERE name LIKE 'Firehouse Subs%';

-- For Partners II Pizza

SELECT 
    name,
    SUBSTRING(name FROM 1 FOR 17) AS chain_name  -- Length of "Partners II Pizza" is 17
FROM restaurant_info
WHERE name LIKE 'Partners II Pizza%';


UPDATE restaurant_info
SET chain_name = SUBSTRING(name FROM 1 FOR 17)  -- Length of "Partners II Pizza" is 17
WHERE name LIKE 'Partners II Pizza%';


-- checking the rows, both branches are located in Peachtree City
-- so I will name the branches Peachtree City 1 and Peachtree City 2

UPDATE restaurant_info
SET branch = 'Peachtree City 1'
WHERE name = 'Partners II Pizza';

UPDATE restaurant_info
SET branch = 'Peachtree City 2'
WHERE name = 'Partners II Pizza Braelinn';

SELECT *
FROM restaurant_info
WHERE name LIKE 'Partners II%';


-- Inspect the table again

SELECT name, chain_name, branch
FROM restaurant_info;

-- There's a restaurant having 'at' towards the end of the chain_name

SELECT name, TRIM(REPLACE(chain_name, 'at', '')) AS chain_name
FROM restaurant_info
WHERE chain_name LIKE '%at';

UPDATE restaurant_info
SET chain_name = TRIM(REPLACE(chain_name, 'at', ''))
WHERE chain_name LIKE '%at';



-- 6. Default case for any remaining unhandled names

SELECT 
    name,
    name AS chain_name,
    NULL AS branch
FROM restaurant_info
WHERE chain_name IS NULL;


UPDATE restaurant_info
SET 
    chain_name = name,
    branch = NULL
WHERE chain_name IS NULL;


-- Verify our changes

SELECT name, chain_name, branch
FROM restaurant_info
ORDER BY chain_name, branch;



