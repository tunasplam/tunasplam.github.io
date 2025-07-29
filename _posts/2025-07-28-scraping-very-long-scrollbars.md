---
title: "Scraping Very Long Scrollbars"
date:  2025-07-28
categories: [programming]
tags: [scraping]
---

### Summary

Scraping address data from brand websites is a common technique for retrieving data for analysis. Often times this data is held within a very long scroll bar. These scrollbars can range from a containing a couple dozen entries to tens of thousands. In this post, I outline a basic approach to scraping a web directory that contains a variant of this situation.

## Prerequisites

If you would like to follow along, the code can be referenced in the following [repo](https://github.com/tunasplam/brewery-scraper). Follow the README to set up your local environment. [Here](https://www.brewersassociation.org/directories/breweries/) is the page being scraped.

### Algorithm

This particular scrollbar keeps all entries "visible" no matter how far down you scroll. You will notice that as you scroll down, your scrollbar handle will continue to shrink. This lends itself to a very simple algorithm: *scroll until you reach the bottom and then scrape all of the revealed tags*. The sleeps are present to allow for pages to fully load and the print is a simple indication of progress for the user.

```python
def main():
    driver = init_selenium()
    driver.get(TARGET_URL)
    time.sleep(5)
    scroll_until_bottom(driver)
    print("Reached Bottom")
    time.sleep(5)
    save_data(scrape_content(driver))
```

### Initializing

This particular scraper uses Selenium combined with a headless Chrome browser.

```python
def init_selenium():
    chrome_options = webdriver.ChromeOptions()
    chrome_options.add_argument("--headless")
    chrome_options.add_argument("--start-maximized")
    return webdriver.Chrome(
        service=ChromeService(
            executable_path=ChromeDriverManager().install(),
        ),
        options=chrome_options
    )
```

### Scrolling to the bottom

Scrolling until the bottom is reached is done by continuing to scroll down until the action of scrolling down no longer changes your position. Scrolling down includes a brief pause to allow for new tags to fully load and printing out the new height periodically gives the user a sense of progress.

```python
def scroll_until_bottom(driver):
    old_height = 0
    new_height = 1
    while new_height != old_height:
        old_height = new_height
        new_height = scroll_down(driver)
        print(new_height)

def scroll_down(driver, pause=.5):
    # scrolls down and returns new scroll height
    for _ in range(driver.get_window_size()['height']):
        driver.find_element(By.XPATH, '//body').send_keys(Keys.DOWN)
    
    time.sleep(pause)
    return driver.execute_script("return document.body.scrollHeight")
```

### Scraping the tags

In data analysis, it is often helpful to consider your datapoints as objects within sets. We use functions to transform these objects into values that are more useful. I like to take this approach in programming as well. Here, we have a set of tags. Each tag has a set of XPATHs that are objects which we can transform into useful data. By doing so, we convert our tags into new rows for our dataset.

Extract the tags and convert each tag into a new entry in our csv file.
```python
HEADERS = ["name","addr","city","state","phone"]

def scrape_content(driver):
    # scrape visible content
    tags = driver.find_elements(By.XPATH, "//*[contains(@class, 'company-listing')]")
    return [HEADERS] + list(map(create_entry, tags))
```

Convert a tag to a csv entry by extracting the text out of each of its relevant XPATHs.

```python
ENTRY_XPATHS = [
    ".//h2[contains(@itemprop, 'name')]", # name
    ".//p[contains(@itemprop, 'streetAddress')]", # addr
    ".//span[contains(@itemprop, 'addressLocality')]", # city
    ".//span[contains(@itemprop, 'addressRegion')]", # state
    ".//span[contains(@itemprop, 'telephone')]" # phone
]

def create_entry(tag):
    return list(map(lambda x: get_property(tag, x), ENTRY_XPATHS))

def get_property(tag, xpath):
    # extracts text from propetry but returns '' if not found
    try:
        return tag.find_element(By.XPATH, xpath).text
    except NoSuchElementException:
        return ''
```

Once this code executes, we are left with a list that contains lists which represent each row of our dataset. We save the file and the program concludes.

```python
def save_data(data):
    with open('brewers_association_addresses.csv', 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerows(data)
```

## Extensions

There is more that can be scraped from this directory. For example, I ommitted categories and ZIP codes because I only plan on using this data for a future blog post and did not think the columns were necessary for what I had in mind.
