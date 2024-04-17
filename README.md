# Apache Fuseki Service

Starting a Fuseki instance isn't complicated, but then dataset endpoints aren't protected and traffic to Fuseki runs over plain HTTP.

Ths repository provides instructions and files that serve as a starting point for a Fuseki deployment that can be used in a production environment.

## Install Fuseki as a system service

Fuseki is installed as a system service. These are the instructions for RedHat-bases Linux distributions.

```
yum -y install java-21-openjdk

export FUSEKI_VERSION=4.10.0
export FUSEKI_INSTALL_DIR=/opt
wget https://archive.apache.org/dist/jena/binaries/apache-jena-fuseki-${FUSEKI_VERSION}.tar.gz
mkdir $FUSEKI_HOME
tar xzf apache-jena-fuseki-4.10.0.tar.gz -C $FUSEKI_INSTALL_DIR
mv ${FUSEKI_INSTALL_DIR}/apache-jena-fuseki-${FUSEKI_VERSION} ${FUSEKI_INSTALL_DIR}/fuseki

# Install Fuseki's service file
cp ${FUSEKI_INSTALL_DIR}/fuseki/fuseki.service /etc/systemd/system/
```

Fuseki should be a service now:

```
$ systemctl status fuseki
● fuseki.service - Fuseki
   Loaded: loaded (/etc/systemd/system/fuseki.service; disabled; vendor preset: disabled)
   Active: inactive (dead)
```

## Create Fuseki user

The service will be run as user `fuseki`.
Create that user and change permissions of installed files accordingly.

```
useradd --system fuseki
chown -R fuseki:fuseki ${FUSEKI_INSTALL_DIR}/fuseki
```

## Install configuration template files

This repository provides templates for the configuration files.
We will copy them to the correct location.

```
mkdir /etc/fuseki
cp shiro.ini config.ttl fuseki-jetty-https.xml /etc/fuseki
chown -R fuseki:fuseki /etc/fuseki
```

## Firewall

You have to open ports in your firewall if Fuseki should be accessible via network.
Per default Fuseki uses Port `3030` for HTTP. Later, we will also use `8443` for HTTPS.

```
firewall-cmd --permanent --zone=public --add-port=3030/tcp
firewall-cmd --permanent --zone=public --add-port=8443/tcp
systemctl restart firewalld
```

## Add your SSL certificate

If you don't have an SSL certiciate you can start with a self-signed certificate for testing purposes.
If you don't have a domain, set your servers's IP adress at `-ext san=ip:<your ip>`.

```
# Create a self-signed certicifate if you don't have an SSL certificate at hand
keytool \
    -genkeypair \
    -alias mykey \
    -validity 3650 \
    -keyalg RSA \
    -keysize 2048 \
    -keystore /etc/fuseki/keystore.p12  \
    -storetype pkcs12 \
    -dname "CN=127.0.0.1, OU=Unit, O=Company, L=City, S=State, C=Country" \
    -ext san=ip:127.0.0.1 \
    -v 
```
If you already have an SSL certificate, add it to a Java keystore:

```
keytool -importcert -alias fuseki_cert -file <your certificate> -keystore /etc/fuseki/keystore.p12
chown fuseki:fuseki /etc/fuseki/keystore.p12
```

## Configure Fuseki

### `config.ttl`

This file configures the datataset and their endpoints. The template defines one dataset called `ds` with the endpoints:

* `sparql`: for Queries
* `get`: graph store protocol read endpoint
* `data`: graph store protocol read-write endpoint

The file also configures where the database is located on the file system (default: `databases/DB2`)

### `shiro.ini`

Fuseki uses Apache Shiro for authentication and authorization. The template configures two users (`admin`, `user1`) with very unsecure password.

**You have to change the passwords!**

```
[users]
# Implicitly adds "iniRealm =  org.apache.shiro.realm.text.IniRealm"
admin=pw
user1=pw
```

Most of the control functions are limited to the admin user:

```
## Control functions open to anyone
/$/status  = anon
/$/server  = anon
/$/ping    = anon
/$/metrics = anon

## and the rest are restricted to localhost.
/$/** = localhostFilter,authcBasic,user[admin]"
```

Access to the endpoints defined in `config.ttl` is only allowed for `user1`:

```
/**/sparql = authcBasic,user[user1]
/**/data = authcBasic,user[user1]
/**/get = authcBasic,user[user1]
```

### `fuseki-jetty-https.xml`

This file configures (among others) the keystore for the SSL certificate and the ports used for HTTP and HTTPS.

Set the path to the keystore and the password here:

```
<New id="sslContextFactory" class="org.eclipse.jetty.util.ssl.SslContextFactory$Server">
    <Set name="KeyStorePath">/etc/fuseki/keystore.p12</Set> 
    <Set name="KeyStorePassword">your password</Set>
    <Set name="TrustStorePath">/etc/fuseki/keystore.p12</Set>
    <Set name="TrustStorePassword">your password</Set>
    [...]
```

You can also change the ports used for HTTP and HTTPs:

```
<New id="httpConfig" class="org.eclipse.jetty.server.HttpConfiguration">
    <Set name="secureScheme">https</Set>
    <Set name="securePort">8443</Set>    <------ HTTPS port -->
```
```
<Set name="host"/>
<Set name="port">3030</Set>    <------ HTTP port -->
```

### `webapp/WEB-INF/web.xml`

If you use HTTPS and want to forward HTTP to HTTPS, do the following:

```
cp web.xml /opt/fuseki/webapp/WEB-INF/
```

The `web.xml` from this repository adds a security contstraint.
Together with `fuseki-jetty-https.xml` this will forward HTTP requests to HTTPS.

```
<security-constraint>
  <web-resource-collection>
    <web-resource-name>Everything</web-resource-name>
    <url-pattern>/*</url-pattern>
  </web-resource-collection>
  <user-data-constraint>
    <transport-guarantee>CONFIDENTIAL</transport-guarantee>
  </user-data-constraint>
</security-constraint>
```

## Start the service

```
systemctl enable fuseki
systemctl start fuseki
```

## Test if Fuseki works

### Fuseki UI in browser

The Fuseki UI should be available at `http://<ip/domain>:3030/` and `https://<ip/domain>:8443`. The HTTP request should be automatically forwarded to HTTPS.

The example data `data.ttl` can be uploaded via the user interface button `add data`. Enter the admin credentials and select `data.ttl` file on your disk and click `upload now`.

The default Query in the tab `query` should return the five uploade triples.

### Interact via HTTP POST and GET requests

Remove `--insecure` if you don't use a self-signed SSL certificate.

```
# Retrieve data from the default graph
curl --insecure -X GET --user user1:pw https://127.0.0.1:8443/ds/data

# Add data to the default graph
curl --insecure -X POST --user user1:pw  -H "Content-Type: text/turtle" -d @data.ttl https://127.0.0.1:8443/ds/data --data-urlencode graph=http://example/scheduler
```

##  Troubleshooting

Check journalctl:

```
journalctl -u fuseki.service
```

The latest service start should look like this:

```
Apr 17 11:36:47 localhost.localdomain systemd[1]: Started Fuseki.
Apr 17 11:36:48 localhost.localdomain fuseki-server[9932]: 11:36:48 INFO  Server          :: Apache Jena Fuseki 4.10.0
Apr 17 11:36:49 localhost.localdomain fuseki-server[9932]: 11:36:49 INFO  Config          :: FUSEKI_HOME=/opt/fuseki
Apr 17 11:36:49 localhost.localdomain fuseki-server[9932]: 11:36:49 INFO  Config          :: FUSEKI_BASE=/etc/fuseki
Apr 17 11:36:49 localhost.localdomain fuseki-server[9932]: 11:36:49 INFO  Config          :: Shiro file: file:///etc/fuseki/shiro.ini
Apr 17 11:36:49 localhost.localdomain fuseki-server[9932]: 11:36:49 INFO  Server          ::   Memory: 4.0 GiB
Apr 17 11:36:49 localhost.localdomain fuseki-server[9932]: 11:36:49 INFO  Server          ::   Java:   11.0.22
Apr 17 11:36:49 localhost.localdomain fuseki-server[9932]: 11:36:49 INFO  Server          ::   OS:     Linux 3.10.0-1160.53.1.el7.x86_64 amd64
Apr 17 11:36:49 localhost.localdomain fuseki-server[9932]: 11:36:49 INFO  Server          ::   PID:    9932
Apr 17 11:36:49 localhost.localdomain fuseki-server[9932]: 11:36:49 INFO  Server          :: Started 2024/04/17 11:36:49 CEST on port 3030
```