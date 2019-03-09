-- This is a set of postgis queries to create great circle lines based on source and destination point geometries, and then split any dateline crossing lines
-- This is an combo and tweak of two separate sources
-- https://gisforthought.com/great-circle-flight-lines-in-postgis/ for creating the intial lines
-- https://carto.com/blog/jets-and-datelines/ for splitting the lines

-- first create the table of lines
CREATE TABLE line_table AS
-- SELECT * FROM first_table
-- if you want a second table's points
-- SELECT * FROM second_table
-- you could also just select the geom from the first table, set that as source/destination_geom, and then do the same for the others

-- make a line_geom column
ALTER TABLE line_table ADD COLUMN line_geom geometry(LineString,4326);

-- make some great (not just ok!) circles
UPDATE line_table
SET line_geom =  
  (ST_Segmentize(
  (ST_MakeLine(source_geom, destination_geom)::geography)
  ,100000)::geometry)
;
-- you should now have a table of great circle line paths! Now, to fix the dateline ones...

-- make a new table of just the lines that cross the dateline
create table tosplit AS (SELECT * FROM connect_lines
  WHERE ST_XMax(line_geom) - ST_XMin(line_geom) > 180);
-- and make a new table of ones that don't
create table nosplit AS (
  SELECT * FROM connect_lines
  WHERE ST_XMax(line_geom) - ST_XMin(line_geom) <= 180),
-- split the lines from tosplit
create table split AS (
  SELECT
    id,
    geography, yourfield1, yourfield2,
    ST_Difference(ST_Shift_Longitude(line_geom),
                  ST_Buffer(ST_GeomFromText('LINESTRING(180 90, 180 -90)',4326),
                            0.00001)) AS line_geom
  FROM tosplit
),
-- make a brand new table that takes your split stuff, and unifies it with the "regular" lines
create table final AS (
  SELECT * FROM split
  UNION ALL
  SELECT * FROM nosplit
)

-- finally, set your new table's geometry to ye olde web mercator
update final set line_geom = ST_Transform(line_geom,4326);

-- this end result can be exported fine to mapbox/carto/leaflet as a geojson (you gotta load it in QGIS first though)