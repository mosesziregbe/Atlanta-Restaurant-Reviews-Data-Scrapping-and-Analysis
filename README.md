# Atlanta Restaurant Reviews Data Scrapping and Analysis

## Project Overview
This project involves the analysis of restaurant reviews in Atlanta. We're working with a dataset scraped from Google Maps, containing information of 580 restaurants in the Atlanta area. In additional, I needed to scrap more information about each restaurant such as the restaurant address, and website url using python's BeautifulSoup.

The goal is to perform data analysis to derive insights about the local restaurant scene, including popular cuisines, highly-rated establishments, and trends in customer reviews.

## Tools Used
- PostgreSQL: For database management and SQL queries
- Python: For data scraping, cleaning, and analysis
- BeautifulSoup: For web scraping 
- Pandas: For data manipulation and analysis
- Matplotlib/Seaborn: For data visualization

## Dataset Description
The dataset consists of restaurant reviews from Google Maps for establishments in the Atlanta area. It includes the following information:

- Restaurant name
- Category/Cuisine type
- Google Maps URL
- Number of reviews
- Average star rating
- Review text 


The project utilizes two main tables:

- restaurant_info: Contains detailed information about each restaurant

Columns: id, name, category_name, address, website, map_url

- reviews: Stores individual reviews for restaurants

Columns: review_id, restaurant_id, rating, review_text

## Project Structure
atlanta_restaurant_reviews/


## Data Collection and Preprocessing
(Brief description of how the data was collected, cleaned, and prepared for analysis)

## Analysis Performed
(Overview of the types of analysis performed, such as:
- Distribution of restaurant ratings
- Popular cuisine types
- Correlation between number of reviews and ratings
- Sentiment analysis of review text
- Geographic distribution of highly-rated restaurants)

## Key Findings
(Placeholder for key insights derived from the analysis)

## Future Work
(Ideas for extending the project or additional analyses to perform)

## Contributors
(List of people who contributed to the project)

## License
(Information about the project's license)
