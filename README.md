# MIMIC-II VM

This repo creates a virtual machine running PostgreSQL and loads the
MIMIC-II data into a database on the VM. The MIMIC-II data will be
accessible from your host machine by querying the PostgreSQL server on
the VM. Hosting the MIMIC-II data in a VM can be desirable because this
prevents collisions with data on your own computer, and the VM can easily be
destroyed to reclaim disk space once experimentation with the data is complete.
 
## Requirements
You will need to have [Vagrant](https://vagrantup.com/downloads.html) and
[VirtualBox](https://www.virtualbox.org/wiki/Downloads) installed.
Ansible is used to provision the Vagrant VM, and since Windows machines
cannot currently be Ansible controllers this will not work on Windows.

## VM Provisioning (a.k.a. Installation)
Clone the repo and create a virtualenv using the supplied `requirements.txt`. 
If using virtualenvwrapper, while in the repository's directory you can simply
execute:
 
```bash
mkvirtualenv mimic-ii-vm -a `pwd` -r requirements.txt
```

Then run `vagrant up` to boot the VM and run the Ansible provisioner. You
will be prompted for your PhysioNet username and password so the database
files can be downloaded to the VM as part of provisioning (this could
take a while, depending on your internet connection). You will also be
asked how many records you would like to load into the database. You can
type `all` or a number of records (e.g. `100`). A couple things to note:

1. There is an issue with non-private prompts for the Ansible provisioner
on Vagrant, so all prompts are private and will conceal what you type.
2. Loading thousands of records can take several hours, and loading the
entire data set will likely run overnight.

You can easily delete the VM and reclaim your disk space with `vagrant halt`
(to stop the VM) and then `vagrant destroy` (to remove it).

## Connecting to the Database
While the VM is booted, local port 2345 is forwarded to the guest VM port
5432 (Postgres server's default listening port). Therefore, generally
speaking you can connect using the host _localhost_ and port 2345.

There are two user accounts that have access to the database:

1. User `vagrant` with password `igMDi9RVEqaGMoi2` has read _and_ write access
2. User `mimic` with password `oNuemmLeix9Yex7W` has read-only access

You can change these passwords by editing the file _provisioning/mimic.yml_
prior to installation.

### GUI
A good GUI is pgAdmin3. It’s included in the Windows PostgreSQL installer, but
might not be included for Mac or Linux installers. It is available on Mac,
Windows, and Linux. You can find non-bundled pgAdmin3 installers for Windows
and OS X after selecting a release version
[here](http://www.postgresql.org/ftp/pgadmin3/release/).

Once installed, the settings for connecting to the database are:

  * Host: localhost
  * Port: 2345
  * Maintenance DB: MIMIC2
  * Username: `mimic` for read-only access (or `vagrant` if you
    need write access)
  * Password: `igMDi9RVEqaGMoi2` for user `vagrant`, or `oNuemmLeix9Yex7W` for
    user `mimic`

You will find the data tables under the `mimic2v26` schema.

### psql (command line)
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

You can then connect with `psql -h localhost -p 2345 MIMIC2 mimic`. You will be
prompted to enter the password for user `mimic` (see above for password).

Below are some commands you can run in the *psql* client:

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

#### -- DANGER COMMANDS --

You can "reset" your database to load the data again if needed:

```bash
drop schema mimic2v26 cascade;  # drop all tables in the schema
# you will need to have read/write access. you might need to ssh into the VM
# and activate psql as user 'vagrant'.
```

If you just deleted your data and want to reload it, execute `vagrant provision`
to run the Ansible playbook again.

### Psycopg2 (Python client)
One way to connect to the DB is through Psycopg2, a popular PostgreSQL client
for Python. It is included in `requirements.txt` for this repo.

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
```

You can read this
[quick guide](https://wiki.postgresql.org/wiki/Psycopg2_Tutorial) for the client
and access the [documentation](http://initd.org/psycopg/docs/) for more
information.

## A Word on Remote Connections
PostgreSQL connections are *not encrypted*. If you are going to run this on a
remote server, or connect to your VM over a network, you should encrypt your
connection when accessing the database. One way of doing this is by creating an
SSH tunnel to the VM:

```bash
ssh -L 63333:localhost:5432 vagrant@192.168.34.43
# this will open an SSH connection in your terminal which you should leave open.
# if you're prompted for a password, try 'vagrant'.
```

Here, `192.168.34.43` is the IP address of your VM. Once the SSH tunnel is
created, use local port `63333` to connect to the DB - this port is now
forwarded to the remote port 5432 over SSH. For example, with pgAdmin3
connecting over the SSH tunnel would use settings:

  * Host: localhost
  * Port: 63333
  * Maintenance DB: MIMIC2
  * Username: `mimic` for read-only access (or `vagrant` if you
    need write access)
  * Password: `igMDi9RVEqaGMoi2` for user `vagrant`, or `oNuemmLeix9Yex7W` for
    user `mimic`

Or, with psql:

```bash
psql -h localhost -p 63333 MIMIC2 mimic 
```

## Shutting Down and Rebooting the VM
You can shut down the VM with `vagrant halt`. To boot it up again, `cd` into the
repository's directory and execute `vagrant up`. The data will remain in the VM
and once the VM is finished booting you can make connections to the DB as
before.
