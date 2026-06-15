# syntax=docker/dockerfile:1

### Dev Stage
FROM openmrs/openmrs-core:2.8.x-dev-amazoncorretto-21 AS dev
WORKDIR /openmrs_distro

ARG MVN_ARGS="-U -P distro"
ARG MVN_COMMAND="install"

# Copy build files
COPY pom.xml ./
COPY distro ./distro/
COPY Modulemapje/openmrs-module-referencemetadata ./Modulemapje/openmrs-module-referencemetadata/

ARG CACHE_BUST
RUN --mount=type=secret,id=m2settings,target=/usr/share/maven/ref/settings-docker.xml \
    MVN_SETTINGS_ARGS="" && \
    if [ -f /usr/share/maven/ref/settings-docker.xml ]; then MVN_SETTINGS_ARGS="-s /usr/share/maven/ref/settings-docker.xml"; fi && \
    mvn $MVN_SETTINGS_ARGS -f Modulemapje/openmrs-module-referencemetadata/pom.xml install -DskipTests

# Build the distro, but only deploy from the amd64 build
RUN --mount=type=secret,id=m2settings,target=/usr/share/maven/ref/settings-docker.xml \
    MVN_SETTINGS_ARGS="" && \
    if [ -f /usr/share/maven/ref/settings-docker.xml ]; then MVN_SETTINGS_ARGS="-s /usr/share/maven/ref/settings-docker.xml"; fi && \
    if [ "$(arch)" != "x86_64" ]; then MVN_ARGS="$MVN_ARGS -Dmaven.deploy.skip=true"; fi && \
    mvn $MVN_SETTINGS_ARGS $MVN_ARGS $MVN_COMMAND

RUN cp /openmrs_distro/distro/target/sdk-distro/web/openmrs_core/openmrs.war /openmrs/distribution/openmrs_core/

RUN cp /openmrs_distro/distro/target/sdk-distro/web/openmrs-distro.properties /openmrs/distribution/
RUN cp -R /openmrs_distro/distro/target/sdk-distro/web/openmrs_modules /openmrs/distribution/openmrs_modules/
RUN cp -R /openmrs_distro/distro/target/sdk-distro/web/openmrs_owas /openmrs/distribution/openmrs_owas/
RUN cp -R /openmrs_distro/distro/target/sdk-distro/web/openmrs_config /openmrs/distribution/openmrs_config/

# Clean up after copying needed artifacts
RUN MVN_SETTINGS_ARGS="" && \
    if [ -f /usr/share/maven/ref/settings-docker.xml ]; then MVN_SETTINGS_ARGS="-s /usr/share/maven/ref/settings-docker.xml"; fi && \
    mvn $MVN_SETTINGS_ARGS $MVN_ARGS clean

### Run Stage
# Replace '2.7.x' with the exact version of openmrs-core built for production (if available)
FROM openmrs/openmrs-core:2.8.x-amazoncorretto-21

# Do not copy the war if using the correct openmrs-core image version
COPY --from=dev /openmrs/distribution/openmrs_core/openmrs.war /openmrs/distribution/openmrs_core/

COPY --from=dev /openmrs/distribution/openmrs-distro.properties /openmrs/distribution/
COPY --from=dev /openmrs/distribution/openmrs_modules /openmrs/distribution/openmrs_modules
COPY --from=dev /openmrs/distribution/openmrs_owas /openmrs/distribution/openmrs_owas
COPY --from=dev  /openmrs/distribution/openmrs_config /openmrs/distribution/openmrs_config
