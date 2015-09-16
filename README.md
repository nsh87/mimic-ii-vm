## VM Provisioning
First, create a virtualenv using `requirements.txt`. If using virtualenvwrapper:
 
```bash
mkvirtualenv mimic-ii-vm -a `pwd` -r requirements.txt
```

Then run `vagrant up` to boot the VM and run the Ansible provisioner. You will
be prompted for your PhysioNet username and password so the database files can
be downloaded to the VM as part of provisioning (this will take a long time). 
You will also be asked how many records you would like to load into the
database. You can type `all` or a number of records (e.g. `100`). There is an
issue with non-private prompts for the Ansible provisioner on Vagrant, so all
prompts will conceal what you type.

### A Note on Passwords
Passwords variables in some Ansible modules are stored as hashes, sometimes
using different algorithms. For passwords in the `postgresql_user` module, the
[documentation](http://docs.ansible.com/postgresql_user_module.html) says 
encrypted passwords need to be created with:

```bash
echo "md5`echo -n "verysecretpasswordJOE" | md5`"
```

Nikhil has the corresponding actual (non-hashed) passwords that can be used to
login once the server is ready.

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
not been added to your  `PATH`. If it works after running the installer, you’re
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
While the port 5432 on the server is open and available for direct connection,
connecting through there directly will **not** create an encrypted connection.
We are using healthcare data and need to tunnel our queries through SSH in order
to encrypt our queries and the data returned.

On your local computer, create an SSH tunnel with an arbitrary unused endpoint
port and a remote end to the open port on the server.

```bash
ssh -L 63333:localhost:5432 globalmrn@gmrn-mimic.cloudapp.net
```

This creates a tunnel from your local port `63333` to the remote port `5432` on
the server. It also sets the user to connect to the server as `globalmrn`, the
owner of the `MIMIC2` database.

These ports have been used following the default PostgeSQL port (5432) and
[SSH Tunnel Instructions](http://www.postgresql.org/docs/9.1/static/ssh-tunnels.html).

### pgAdmin3
With the SSH tunnel created, you can open pgAdmin3 and connect to the DB through
the tunnel using the following settings:

  * Host: localhost
  * Port: 63333
  * Maintenance DB: MIMIC2
  * Username (postgres): `globalmrn` or `chris`
  * Password: use the appropriate password

You will find the data tables under the `mimic2v26` schema.

### Postgres Client (psql)
Set up a tunnel following the instructions above. With the tunnel created, in a
separate Terminal window connect to the database using:

```bash
psql -h localhost -p 63333 MIMIC2 globalmrn 
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

**-- DANGER COMMANDS | DO NOT RUN --**

```bash
# ssh in and and start psql with MIMIC2 database, then:
drop schema mimic2v26 cascade;  # drop all tables in the schema
```

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
    user='chris',
    host='localhost',
    port=63333,
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

