- Assignment was completed individually in T3 2021 for COMP3311: Database Systems.
- Task was to write a range of queries for a provided database of beers.
- This project had a focus on writting SQL queries and PLpgSQL functions.
- Project Spec can be found in spec.html.
- To run application:
    - PostgreSQL must be installed
    - To load files:
      ```
      $ createdb beers
      $ psql beers -f ass1.dump > log 2>&1
      $ psql beers -f ass1.sql
      $ psql beers
      ```
    - Run queries in postgres by the view names
