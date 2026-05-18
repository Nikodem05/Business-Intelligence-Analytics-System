# Business-Intelligence-Analytics-System

Portfolio project in SQL Server focused on data warehousing, analytical reporting, and advanced T-SQL development.

SalesBI is a sample business intelligence environment designed around a Star Schema architecture.
The project simulates transactional sales data for both B2B and B2C scenarios and demonstrates how a SQL Server data warehouse can support analytical reporting and KPI tracking.

Implemented Features

Feature	
1. Window Functions - ranking, YoY comparisons, rolling metrics
2. Multi-level CTEs -	analytical transformations
3. PIVOT -	quarterly revenue reporting
4. Rolling Aggregations	- moving averages and trends
5. RFM Analysis -	customer segmentation
6. ABC Classification -	Pareto-based product grouping
7. Persisted Computed Columns	- centralised KPI calculations
8. Covering Indexes -	analytical query optimisation
9. Parameterised Procedures -	reusable reporting layer

Sample Data Generation Logic

One of the most important parts of this project is a lightweight data seeding mechanism used to generate realistic transactional sales records for the fact table. Randomised values are created using NEWID() combined with CHECKSUM() in order to simulate:
1. transaction dates
2. customer/product assignments
3. salesperson activity
4. order quantities
5. discount variability

Project Goal

The main purpose of this project is to present practical SQL Server and BI engineering skills in a portfolio-friendly format, including:
1. warehouse modelling
2. analytical query development
3. performance-oriented database design
4. reporting-oriented stored procedure implementation
