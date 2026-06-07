import os
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.chrome.service import Service
from webdriver_manager.chrome import ChromeDriverManager
import time

def convert_html_to_formats(html_files):
    # Setup Chrome options
    chrome_options = Options()
    chrome_options.add_argument('--headless')
    chrome_options.add_argument('--no-sandbox')
    chrome_options.add_argument('--window-size=800,600')
    
    # Initialize webdriver with ChromeDriverManager
    driver = webdriver.Chrome(service=Service(ChromeDriverManager().install()), options=chrome_options)
    
    for html_file in html_files:
        base_name = os.path.splitext(html_file)[0]
        file_path = f"file://{os.path.abspath(html_file)}"
        
        # Load the HTML file
        driver.get(file_path)
        time.sleep(2)  # Wait for rendering
        
        # Save as PNG
        driver.save_screenshot(f"{base_name}.png")
        
        # Save as PDF
        pdf_options = {
            'printBackground': True,
            'paperWidth': 8,
            'paperHeight': 6
        }
        pdf_data = driver.execute_cdp_cmd('Page.printToPDF', pdf_options)
        with open(f"{base_name}.pdf", 'wb') as f:
            f.write(bytes(pdf_data['data'], 'base64'))
        
    driver.quit()

if __name__ == "__main__":
    html_files = ["surface1.html", "surface2.html"]
    convert_html_to_formats(html_files)