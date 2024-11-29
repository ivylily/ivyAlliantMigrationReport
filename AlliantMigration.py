import pymysql
import pyodbc
import pandas as pd
import logging
import pathlib
import os
from dotenv import load_dotenv

# Load environment variables from the .env file
load_dotenv()

# MariaDB connection parameters
alliant_customer_host = os.getenv('alliant_customer_host')
alliant_customer_user = os.getenv('alliant_customer_user')
alliant_customer_password = os.getenv('alliant_customer_password')
alliant_customer_database = os.getenv('alliant_customer_database')

# Northwind connection parameters
northwind_driver = os.getenv('northwind_driver')
northwind_server = os.getenv('northwind_server')
northwind_database = os.getenv('northwind_database')

def mariadb_extract_data(table_name):
    """
    Extracts all data from a given table in MariaDB.

    Parameters:
        table_name (str): The name of the table to extract data from.

    Returns:
        pd.DataFrame: Data extracted from the specified table.
    """
    try:
        query = f"SELECT * FROM {table_name};"
        data = pd.read_sql(query, mariadb_conn)
        logging.info(f"Extracted {len(data)} rows from MariaDB table {table_name}.")
        return data
    except Exception as e:
        logging.error(f"Error extracting data from MariaDB table {table_name}: {e}")
        raise

def insert_data_to_northwind(dataframe, table_name):
    """
    Inserts data from a DataFrame into a staging table in the Northwind database.

    Parameters:
        dataframe (pd.DataFrame): The data to be inserted.
        table_name (str): The name of the staging table in the Northwind database.
    """
    try:
        cursor = northwind_conn.cursor()
        IdentityINSERT_ON_sql = f"SET IDENTITY_INSERT [Migration].Stage_{table_name} ON"
        IdentityINSERT_OFF_sql = f"SET IDENTITY_INSERT [Migration].Stage_{table_name} OFF"
       
        cursor.execute(IdentityINSERT_ON_sql)
        for _, row in dataframe.iterrows():
            placeholders = ', '.join(['?'] * len(row))
            columns = ', '.join(row.index)
            sql = f"INSERT INTO [Migration].Stage_{table_name} ({columns}) VALUES ({placeholders})"
            cursor.execute(sql, tuple(row))
            
        cursor.execute(IdentityINSERT_OFF_sql)
        logging.info(f"Inserted {len(dataframe)} rows into Northwind table {table_name}.")
    except Exception as e:
        northwind_conn.rollback()
        logging.error(f"Error inserting data into Northwind table {table_name}: {e}")
        raise

def extract_table(table_name):
    """
    Migrates data for a specific table from MariaDB to the Northwind staging.

    Parameters:
        table_name (str): The name of the table to migrate.
    """
    try:
        data = mariadb_extract_data(table_name)
        insert_data_to_northwind(data, table_name)
        logging.info(f"Migration of {table_name} table completed successfully.")
    except Exception as e:
        logging.error(f"Error during migration of {table_name} table: {e}")
        raise
        
def execute_query_from_file_northwind(file_path):
    """
    Executes SQL queries from a given file in the Northwind database.

    Parameters:
        file_path (Path): Path to the SQL file containing the queries.
    """
    try:
        with open(file_path, 'r') as file:
            sql_query = file.read()
        
        # Split the script by 'GO' statements (case insensitive and surrounded by line breaks)
        commands = [command.strip() for command in sql_query.split('GO') if command.strip()]
        
        cursor = northwind_conn.cursor()
        for command in commands:
            cursor.execute(command)
        logging.info(f"SQL query executed successfully from file {file_path}.")
    except Exception as e:
        northwind_conn.rollback()
        logging.error(f"Could not execute SQL query from file {file_path}: {e}")
        raise

# Configure logging
logging.basicConfig(filename='migration.log', level=logging.INFO, 
                    format='%(asctime)s - %(levelname)s - %(message)s')

# Establish database connections
try:
    # MariaDB Connection
    mariadb_conn = pymysql.connect(
        host=alliant_customer_host,
        user=alliant_customer_user,
        password=alliant_customer_password,
        database=alliant_customer_database,
        autocommit=False  # Disable auto-commit for transaction control
    )
    logging.info("Successfully connected to MariaDB.")

    # Northwind Connection
    northwind_conn = pyodbc.connect(
        f'DRIVER={northwind_driver};'
        f'SERVER={northwind_server};'
        f'DATABASE={northwind_database};'
        'Trusted_Connection=yes;',
        autocommit=False  # Disable auto-commit for transaction control
    )
    logging.info("Successfully connected to Northwind.")

    #Get the current directory from which we will pull all files
    current_directory = pathlib.Path().resolve()

    # Start Migration Process
    try:
        # Create structures in Northwind
        execute_query_from_file_northwind(current_directory.joinpath('2 - Migration DDL.sql'))

        # Migrate data into staging tables
        extract_table('Locations')
        extract_table('Batches')
        extract_table('Entities')
        extract_table('Items')
        extract_table('Transactions')

        # Run validation and transformation scripts. Updates the is_valid column in the staging tables
        execute_query_from_file_northwind('2 - Validation Alliant Migration.sql')
        # Runs the data transformation for all valid rows
        execute_query_from_file_northwind('2 - Transformation Alliant.sql')

        # Commit all changes
        mariadb_conn.commit()
        northwind_conn.commit()
        logging.info("Migration completed successfully.")

    except Exception as e:
        # Rollback changes if any step fails
        mariadb_conn.rollback()
        northwind_conn.rollback()
        logging.error(f"Migration failed: {e}")
        raise

except Exception as e:
    logging.error(f"Error establishing database connections: {e}")
    raise
finally:
    # Close the connections
    try:
        mariadb_conn.close()
        northwind_conn.close()
        logging.info("Closed database connections.")
    except Exception as e:
        logging.warning(f"Error closing database connections: {e}")