# Migration and Reporting Project – Retail Store

This is a test exam to be done as part of the recruitment processes at Alliant Systems.

The project can be used from any machine with python installed and conection to both source and destination databases.

## Installation

Use the package manager [pip](https://pip.pypa.io/en/stable/) to make sure you also have installed this packages.

```bash
pip install pymysql pandas python-dotenv
```
# Migration and Reporting Project – Retail Store

This is a test exam to be done as part of the recruitment processes at Alliant Systems.

The project can be used from any machine with python installed and conection to both source and destination databases.

## Installation

Use the package manager [pip](https://pip.pypa.io/en/stable/) to make sure you also have installed this packages.

```bash
pip install pymysql pandas python-dotenv
```

Before use fill out your .env file with the next configuration variables.



## Usage

```bash
python Alliant Migration.py
```
## Environment Variables


Create a .env file in the root of your project and insert your key/value pairs in the following format of KEY=VALUE:

```sh
ALLIANT_CUSTOMER_HOST=127.0.0.1
ALLIANT_CUSTOMER_USER=root
ALLIANT_CUSTOMER_PASSWORD=sweetcheeks
ALLIANT_CUSTOMER_DATABASE=alliantcustomer
NORTHWIND_DRIVER={ODBC Driver 17 for SQL Server}
NORTHWIND_SERVER=HPilCdlS
NORTHWIND_DATABASE=Northwind
```





## Usage

Locate your file absolute path and pass it as a parameter to the python command in your cmd.

```bash
python {path}\AlliantMigration.py
```
