-- COMP3311 21T3 Assignment 1
-- by Samuel Thorley (z5257239)
--
-- Fill in the gaps ("...") below with your code
-- You can add any auxiliary views/function that you like
-- The code in this file MUST load into a database in one pass
-- It will be tested as follows:
-- createdb test; psql test -f ass1.dump; psql test -f ass1.sql
-- Make sure it can load without errorunder these conditions


-- Q1: oldest brewery

create or replace view Q1(brewery)
as
SELECT b.name
FROM breweries b
WHERE b.founded = (SELECT min(b.founded) FROM breweries b)
;

-- Q2: collaboration beers

create or replace view Q2(beer)
as
SELECT b1.name
FROM beers b1
JOIN (SELECT b3.beer
    FROM brewed_by b3
    GROUP BY b3.beer
    HAVING count(b3.beer) > 1) b2 ON (b2.beer = b1.id)
;

-- Q3: worst beer

create or replace view Q3(worst)
as
SELECT b.name
FROM beers b
WHERE b.rating = (SELECT min(b.rating) from beers b)
;

-- Q4: too strong beer

create or replace view Q4(beer,abv,style,max_abv)
as
SELECT b.name AS beer, b.abv, s.name AS style, s.max_abv
FROM beers b JOIN styles s ON (b.style = s.id)
WHERE b.abv > s.max_abv
;

-- Q5: most common style

create or replace view style_counts(style,count)
as
SELECT s.name, count(b.style)
FROM beers b JOIN styles s ON (b.style = s.id)
GROUP BY s.name
ORDER BY count(b.style) DESC
;

create or replace view Q5(style)
as
SELECT c.style
FROM style_counts c
WHERE c.count = (SELECT max(c.count) FROM style_counts c)
;

-- Q6: duplicated style names

create or replace view Q6(style1,style2)
as
SELECT s1.name as style1, s2.name as style2
FROM Styles s1, Styles s2
WHERE s1.name < s2.name AND upper(s1.name) = upper(s2.name)
;

-- Q7: breweries that make no beers

create or replace view Q7(brewery)
as
SELECT b1.name
FROM breweries b1
WHERE b1.id IN (
    (SELECT id FROM breweries)
    EXCEPT
    (SELECT DISTINCT brewery FROM brewed_by)
);

-- Q8: city with the most breweries

create or replace view city_counts(city, country, count)
as
SELECT l.metro, l.country, count(b.located_in)
FROM breweries b JOIN locations l ON (b.located_in = l.id)
WHERE l.metro <> ''
GROUP BY l.metro, l.country
ORDER BY count(b.located_in) DESC
;

create or replace view Q8(city,country)
as
SELECT c.city, c.country
FROM city_counts c
WHERE c.count = (SELECT max(c.count) FROM city_counts c)
;

-- Q9: breweries that make more than 5 styles

create or replace view brewery_styles(brewery, style)
as
SELECT DISTINCT  b2.brewery, b1.style
FROM beers b1 JOIN brewed_by b2 ON (b1.id = b2.beer)
ORDER BY b2.brewery
;

create or replace view Q9(brewery,nstyles)
as
SELECT b1.name, count(b2.brewery)
FROM brewery_styles b2 JOIN breweries b1 ON (b1.id = b2.brewery)
GROUP BY b1.name
HAVING count(b2.brewery) > 5
ORDER BY b1.name
;

-- Q10: beers of a certain style

create type BeerInfo as (beer text, brewery text, style text, year yearvalue, abv abvvalue);

create or replace function
	q10(_style text) returns setof BeerInfo
as $$
declare
    beer record;
    info BeerInfo;
    beer_id integer;
    -- Variable used to create breweries string:
    brewers text;
begin
    for beer in
        select b.name, b.id as beer_id, b.brewed, b.abv, s.name as style
        from beers b join styles s on (b.style = s.id)
        where s.name = _style
    loop
        info.beer := beer.name;
        info.year := beer.brewed;
        info.abv := beer.abv;
        info.style := beer.style;

        -- Create string of breweries and store in info.brewery
        select
            string_agg(b2.name, ' + ' order by b2.name) AS brewers into info.brewery
        from brewed_by b1 join breweries b2 on (b1.brewery = b2.id)
        where b1.beer = beer.beer_id;

        return next info;
    end loop;
end
$$
language plpgsql;

-- Q11: beers with names matching a pattern

create or replace function
	Q11(partial_name text) returns setof text
as $$
declare
    beer record;
    info text;
    brewers text; -- Variable used to create breweries sub-string
begin
    for beer in
        select b.name, b.id as beer_id, b.abv, s.name as style
        from beers b join styles s on (b.style = s.id)
        where lower(b.name) ~ partial_name
        order by b.name
    loop
        -- Create string of breweries
        select
            string_agg(b2.name, ' + ' order by b2.name) into brewers
        from brewed_by b1 join breweries b2 on (b1.brewery = b2.id)
        where b1.beer = beer.beer_id;

        -- Create return string
        info := '"' || beer.name || '", ' || brewers || ', '
            || beer.style || ', ' || beer.abv || '% ABV';

        return next info;
    end loop;
end
$$
language plpgsql;

-- Q12: breweries and the beers they make

create or replace function
	Q12(partial_name text) returns setof text
as $$
declare
    brewery record;
    beer record;
    brewery_info text;
    brewery_location text;
    beer_info text;
    -- Variables used for location string
    country text;
    region text;
    metro text;
    town text;
begin
    for brewery in
        select b1.name, b1.id as brewer_id, b1.founded, b1.located_in
        from breweries b1
        where lower(b1.name) ~ partial_name
        order by b1.name
    loop
        -- Print name and founded year
        brewery_info := brewery.name || ', founded ' || brewery.founded;
        return next brewery_info;

        -- Print location
        brewery_location := 'located in ';

        select l.country, l.region, l.metro, l.town into country, region, metro, town
        from locations l
        where l.id = brewery.located_in;

        if town is not null then
            brewery_location := brewery_location || town;
        elsif metro is not null then
            brewery_location := brewery_location || metro;
        end if;
        if region is not null then
            brewery_location := brewery_location || ', ' || region;
        end if;
        brewery_location := brewery_location || ', ' || country;

        return next brewery_location;

        -- Print beers
        for beer in
            select b2.name, s.name as style, b2.brewed, b2.abv
            from brewed_by b3 join beers b2 on (b3.beer = b2.id) join styles s on (b2.style = s.id)
            where b3.brewery = brewery.brewer_id
            order by b2.brewed, b2.name
        loop
            beer_info := '  "' || beer.name || '", ' || beer.style 
                || ', ' || beer.brewed || ', ' || beer.abv || '% ABV';
            return next beer_info;
        end loop;
    end loop;
end
$$
language plpgsql;
