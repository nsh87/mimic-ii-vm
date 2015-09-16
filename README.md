# MIMIC-II VM

This repo creates a virtual machine running PostgreSQL and loads the MIMIC-II
data into a database. The MIMIC-II data will be accessible from your host 
machine by querying the PostgreSQL server on the VM.
 
## Requirements
You will need to have Vagrant and VirtualBox installed. Ansible is used to
provision the Vagrant VM, and since Windows machines cannot currently be Ansible
controllers this will not work on Windows.

## VM Provisioning (a.k.a. Installation)
Clone the repo and create a virtualenv using the supplied `requirements.txt`. 
If using virtualenvwrapper:
 
```bash
mkvirtualenv mimic-ii-vm -a `pwd` -r requirements.txt
```

Then run `vagrant up` to boot the VM and run the Ansible provisioner. You will
be prompted for your PhysioNet username and password so the database files can
be downloaded to the VM as part of provisioning (this will take a long time). 
You will also be asked how many records you would like to load into the
database. You can type `all` or a number of records (e.g. `100`). There is an
issue with non-private prompts for the Ansible provisioner on Vagrant, so all
prompts are private and will conceal what you type.

## Connecting to the Database

### GUI
A good GUI is pgAdmin3. It’s included in the Windows PostgreSQL installer, but
might not be included for Mac or Linux installers. It is available on Mac,
Windows, and Linux. You can find non-bundled pgAdmin3 installers for Windows and
OS X after selecting a release version
[here](http://www.postgresql.org/ftp/pgadmin3/release/).

### PostgreSQL (command line)
The Postgres client is accessed through the command line with `psql`. The
command line bin is included with the OS-specific installers, but has probably
not been added to your `PATH`. If it works after running the installer, you’re
fine, otherwise:

  * OS X: Add the bin to your path, or instead you can install Postgres via
    Homebrew and download pgAdmin3 separately using the link above
(recommended).

    ```bash
    brew install postgres
    initdb /usr/local/var/postgres -E utf8
    ```

  * Windows: Either move `psql.exe` to your current path or specify the full
    path to it which is something like

    ```bash
    "%PROGRAMFILES%\Postgresql\9.2\bin\psql.exe"
    ```

### Psycopg2 (Python client)
One way to connect to the DB is through Psycopg2, a popular PostgreSQL client
for Python. It is included in `requirements.txt` for this repo.

## Making the Connection
Local port 2345 is forwarded to the guest VM port 5432 (Postgres server's 
default listening port).

### pgAdmin3
With the SSH tunnel created, you can open pgAdmin3 and connect to the DB through
the tunnel using the following settings:

  * Host: localhost
  * Port: 2345
  * Maintenance DB: MIMIC2
  * Username (postgres): `mimic` for read-only access (or `vagrant` if you need 
    write access)
  * Password: (need to insert - see the playbook)

You will find the data tables under the `mimic2v26` schema.

### Postgres Client (psql)
Set up a tunnel following the instructions above. With the tunnel created, in a
separate Terminal window connect to the database using:

```bash
psql -h localhost -p 2345 MIMIC2 mimic 
# the last two arguments are <database> and <postgres user>
```

#### List the tables
You can list the tables, which are within the `mimic2v26` schema with

```psql
\dt mimic2v26.*
```

#### Describe the table `admissions`, including its size on disk

```psql
\dt+ mimic2v26.admissions
```

#### Show its columns and some basic info about them 

```psql
\d+ mimic2v26.admissions
```

#### Show the first 10 rows

```psql
SELECT * FROM mimic2v26.admissions LIMIT 10;
```

Above, `*` can also be replaced with a single column name.

**-- DANGER COMMANDS --**

You can "reset" your database to load the data again if needed:

```bash
# ssh in and and start psql with MIMIC2 database, then:
drop schema mimic2v26 cascade;  # drop all tables in the schema
```

Then run `vagrant provision` to run the Ansible playbook again.

### Psycopg2
You can read this
[quick guide](https://wiki.postgresql.org/wiki/Psycopg2_Tutorial) for the client
and access the [documentation](http://initd.org/psycopg/docs/) for more
information.

To make a connection through the SSH tunnel you created above, in Python run:

```python
import psycopg2
conn=psycopg2.connect(
    dbname='MIMIC2',
    user='mimic',
    host='localhost',
    port=2345,
    password='oNuemmLeix9Yex7W'
)
```

Then, to execute queries:

```python
# open a cursor to perform operations
cur = conn.cursor() 

# query the 'admissions' table
cur.execute("SELECT * FROM mimic2v26.admissions LIMIT 10;")
colnames = [desc[0] for desc in cur.description]
print colnames
# put results in a list var to print the subject_id
row = cur.fetchall() 
for row in rows:
  print "    ", row[1]

# Warning Never, never, NEVER use Python string concatenation (+) or
# string parameters interpolation (%) to pass variables to a SQL
# query string. Not even at gunpoint.
```

