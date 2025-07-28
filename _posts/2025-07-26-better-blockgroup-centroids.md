---
title: "Better Block Group Centroids"
date:  2025-07-26
categories: [analytics]
tags: [census_cartography, postgis]
---

### Summary

Cartographic shapes provided by the US Census Bureau are foundational for US-based geospatial analytics professionals. Here I share a quick tip for enchancing cartographic shapes with weighted centroids that are usually better suited for analysis than traditional centroids. Although I will use block groups as the example in this post, this methodology can be adapted for other cartographies such as ZIP codes and census tracts.

## Prerequisites
If you would like to follow along, you will need the following setup. I am using a local instance of Postgres 17.5 + PostGIS on Ubuntu.

`sudo apt-get install postgresql postgis`

### Getting block group cartography into postgres

Tiger shape files can be found in this [FTP archive](https://www2.census.gov/geo/tiger/TIGER2024/). Block group cartography is found in the `BG` directory and is split by state. I will limit the scope of this post to California (FIPs code 06). [Download the cartography here.](https://www2.census.gov/geo/tiger/TIGER2024/BG/tl_2024_06_bg.zip) 

Once the shapefiles are extracted, convert them to valid SQL. We use the `-I` flag to automatically create the powerful GiST indexes. We are specifying 4326 since this cartography is mainland US lat/lon.

`shp2pgsql -I -s 4326 tl_2024_06_bg public.block_groups_ca > block_groups_ca.sql`

Import into database

`psql -d <your_database> -U <your_user> -f block_groups_ca.sql`

You can then get an overview of the imported table in psql with

`\d public.block_groups_ca`

### Something to visualize the cartography with

Geographic data in a database is great but is totally worthless if you cannot easily visualize it. Since this is a lightweight project, I will simply be using a Jupyter notebook with a connection to postgres. The data will be pulled into a GeoPandas dataframe which can be visualized using a the KeplerGl library.

Here is the full list of dependencies if you would like to follow along. I recommend using [poetry](https://python-poetry.org/) to handle your python venvs. It is an extremely useful tool that simplifies handling python libraries.

```
requires-python = ">=3.12"
dependencies = [
    "geopandas (>=1.1.1,<2.0.0)",
    "psycopg2-binary (>=2.9.10,<3.0.0)",
    "sqlalchemy (>=2.0.41,<3.0.0)",
    "dotenv (>=0.9.9,<0.10.0)",
    "keplergl (>=0.3.7,<0.4.0)",
]
```

Pull data into a GeoDataFrame
```python
import geopandas as gpd

gdf = gpd.read_postgis("SELECT geoid, geom FROM public.block_groups_ca", engine, geom_col='geom')
```

Create a map and add the block group cartography layers to it. This may take a minute.

```python
from keplergl import KeplerGl

m = KeplerGl()
m.add_data(data=gdf[['geom']].to_json(), name="BG Geometries")
m
```

Now we have geographic data in a database and a super simple mapping environment to access it with.

## Motivation 

With the pre-requisites out of the way, let's talk about the motivation behind centroids. Often times we may want to cluster block groups together using some sort of algorithm, but performing the clustering on the full block group polygons can get expensive. To simplify things, we can think of these clustering algorithms as graph coloring problems where each block group is a node and the connections represent spatially adjacent block groups. This distance between the nodes can correspond to the distance between representative points chosen for each block group. The choice of representative points can help tune your algorithms to specific applications.

## Centroids

Two simple methods of chosing a representative point for each block group are [`ST_PointOnSurface`](https://postgis.net/docs/ST_PointOnSurface.html) and [`ST_Centroid`](https://postgis.net/docs/ST_Centroid.html). Let's add centroids to our block group cartography. In psql:

```sql
ALTER TABLE public.block_groups_ca ADD COLUMN centroid_4326 GEOMETRY(POINT, 4326);
UPDATE public.block_groups_ca SET centroid_4326 = ST_Centroid(geom);
CREATE INDEX ON public.block_groups_ca USING GIST (centroid_4326);
```

Now back in our notebook:

```python
gdf = gpd.read_postgis("SELECT geoid, geom FROM public.block_groups_ca", engine, geom_col='geom')
gdf2 = gpd.read_postgis("SELECT geoid, centroid_4326 FROM public.block_groups_ca", engine, geom_col='centroid_4326')

m = KeplerGl()
m.add_data(data=gdf2[['centroid_4326']].to_json(), name="BG Centroids")
m.add_data(data=gdf[['geom']].to_json(), name="BG Geometries")

m
```

![alt text](assets/posts/better-bgs/BGs%20with%20Centroids.png)

Here I have zoomed in on Fremont/Union City, CA. We can see that the centroids (the brown dots) are nestled nicely in the centers of each block group. However, looking at the block groups on the edges of Fremont in the hills towards Pleasanton we see some centroids that may not be very useful for all applications.

![alt text](assets/posts/better-bgs/centroids%20gmaps.png)

Above I have navigated to these block groups on Google maps. I marked the approximate locations of the centroids with X's but notice that the actual residential neighborhoods lie on the fringes of the block groups. It would appear that using centroids as representative points for these block groups may not be the best way to go if our specific application involves targeting residential neighborhoods.

### Weighting your centroids

PostGIS offers a goldmine of nifty functions that help make sptial modeling easier. One of these is [`ST_GeometricMedian`](https://postgis.net/docs/ST_GeometricMedian.html), which allows for computing the median of sets of inputted points. If only we could have sample points within the block groups that followed the distribution of households within it.

Luckily, we do have such a thing! All block groups are further subdivided into blocks which are created in an attempt to balance the populations within them. The California blocks can also be downloaded in the [Census FTP archive](https://www2.census.gov/geo/tiger/TIGER2020/TABBLOCK20/tl_2020_06_tabblock20.zip). Let's load it into the database the same way we did so with the block groups.

For ease of use I am going to add a centroid column and a column that links each block to its parent block group.

```sql
ALTER TABLE public.blocks_ca ADD COLUMN centroid_4326 GEOMETRY(POINT, 4326);
UPDATE public.blocks_ca SET centroid_4326 = ST_Centroid(geom);
CREATE INDEX ON public.blocks_ca USING GIST (centroid_4326);

ALTER TABLE public.blocks_ca ADD COLUMN bgid20 TEXT;
UPDATE public.blocks_ca SET bgid20 = LEFT(geoid20, 12);
CREATE INDEX ON public.blocks_ca USING BTREE (geoid20);
```
Yes, we are using centroids as representative points for these blocks, which we saw above is not the greatest for block groups. However, blocks are about as granular as you can get in terms of cartographic data without resorting to the parcel or ZIP+4 level. Their granularity helps to minimize the risk of using their centroids.

Now let's create the weighted centroids.
```sql
ALTER TABLE public.block_groups_ca ADD COLUMN bweighted_centroid_4326 GEOMETRY(POINT, 4326);

WITH t AS (
    SELECT
        bg.geoid,
        ST_GeometricMedian(
            ST_Collect(b.centroid_4326)
        ) AS c
    FROM block_groups_ca bg
    JOIN blocks_ca b
        ON b.bgid20 = bg.geoid
    GROUP BY bg.geoid
)
UPDATE public.block_groups_ca bg
SET bweighted_centroid_4326 = t.c
FROM t
WHERE bg.geoid = t.geoid;
```

And we can immediately see some improvements. Notice how the block weighted centroids in the hills between Pleasanton and Fremont tighten up towards the populated areas.

![alt text](assets/posts/better-bgs/BWCs.png)

Rural block groups on the edge of towns are also tightened up. The image of northern Stanislaus county below shows noticeable improvements along the north side of Modesto and the outskirts of Ripon and Riverbank.

![alt text](assets/posts/better-bgs/NModesto.png)

### Extensions

The effects of these improvements are even more pronounced when dealing with larger cartographies such as ZIP codes. There are other improvements that can be made as well. For example, the method outlined above weights each block equally when computing the geometric median. The `public.blocks_ca` table also contains the column `pop20` which can be used to weight each block based on its estimated population. This data is a bit outdated but it works for the purposes of our demonstration.

```sql
ALTER TABLE public.block_groups_ca ADD COLUMN bpweighted_centroid_4326 GEOMETRY(POINT, 4326);

WITH t AS (
    SELECT
        bg.geoid,
        ST_GeometricMedian(ST_Collect(
            ST_PointM(
                ST_X(b.centroid_4326),
                ST_Y(b.centroid_4326),
                b.pop20+1, 4326
            )
        )) AS c
    FROM block_groups_ca bg
    JOIN blocks_ca b
        ON b.bgid20 = bg.geoid
    GROUP BY bg.geoid
)
UPDATE public.block_groups_ca bg
SET bpweighted_centroid_4326 = t.c
FROM t
WHERE bg.geoid = t.geoid;
```

