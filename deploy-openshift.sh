echo ---- Start deploy Demo Application

echo ---- Weather APP JBoss EAP

### Create Project ###
oc new-project redhat-osd-demo --display-name="Red Hat Open Source Day Demo"

### Import image related to Postgresql Database ###
oc import-image rhscl/postgresql-10-rhel7 --from=registry.access.redhat.com/rhscl/postgresql-10-rhel7 --confirm

### Create the Postgresql Database Application ###
oc new-app -e POSTGRESQL_USER=mauro -ePOSTGRESQL_PASSWORD=secret -ePOSTGRESQL_DATABASE=weather postgresql-10-rhel7 --name=weather-postgresql

### Import image related to JBoss EAP 7.2 - Openjdk 8 ###
oc import-image jboss-eap-7/eap72-openshift --from=registry.access.redhat.com/jboss-eap-7/eap72-openshift --confirm

### Create the build related to the weather app that will be deployed on JBoss EAP ###
oc new-build eap72-openshift --binary=true --name=weather-app-eap

### Move the project directory ###
cd weather-app-eap

### Run the Maven build ###
mvn clean package

### Start the build of the application on Openshift ###
oc start-build weather-app-eap --from-file=target/ROOT.war --wait

### Create the weather application for JBoss EAP and configure it ###
oc new-app weather-app-eap -e DB_SERVICE_PREFIX_MAPPING=weatherds-postgresql=DB \
  -e DB_JNDI=java:jboss/datasources/WeatherDS \
  -e DB_DATABASE=weather \
  -e DB_USERNAME=mauro \
  -e DB_PASSWORD=secret \
  -e DB_DRIVER=postgresql \
  -e DB_NONXA=true \
  -e DB_URL='jdbc:postgresql://$(WEATHER_POSTGRESQL_SERVICE_HOST):$(WEATHER_POSTGRESQL_SERVICE_PORT)/weather'

### Expose the route in order to make the application available outside of Openshift  ###
oc expose svc weather-app-eap

echo ---- Weather APP Quarkus

### Create the build related to the weather app that will be deployed as fat jar with Quarkus ###
oc new-build --binary=true --name=weather-app-quarkus -l app=weather-app-quarkus

### Patch the build config in order to set the Docker strategy ###
oc patch bc/weather-app-quarkus -p "{\"spec\":{\"strategy\":{\"dockerStrategy\":{\"dockerfilePath\":\"src/main/docker/Dockerfile.jvm\"}}}}"
 
### Move the project directory ###
cd ../weather-app-quarkus/

### Run the Maven build ###
mvn package -Dquarkus.profile=dev-postgresql-db

### Start the build of the application on Openshift ###
oc start-build weather-app-quarkus --from-dir=. --follow

### Create the weather application for Quarkus and configure it ###
oc new-app --image-stream=weather-app-quarkus:latest -e quarkus.datasource.url='jdbc:postgresql://weather-postgresql:5432/weather'

### Expose the route in order to make the application available outside of Openshift  ###
oc expose service weather-app-quarkus