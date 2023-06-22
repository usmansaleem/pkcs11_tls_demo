# syntax=docker/dockerfile:1

# Create a custom Java runtime
FROM eclipse-temurin:17 as jre-build
RUN JAVA_TOOL_OPTIONS="-Djdk.lang.Process.launchMechanism=vfork" $JAVA_HOME/bin/jlink \
         --add-modules ALL-MODULE-PATH \
         --strip-debug \
         --no-man-pages \
         --no-header-files \
         --compress=2 \
         --output /javaruntime

# Bundle our application using jre and dist from prevous multistage builds
FROM ubuntu:latest
ENV JAVA_HOME=/opt/java/openjdk
ENV PATH "${JAVA_HOME}/bin:${PATH}"
COPY --from=jre-build /javaruntime $JAVA_HOME
COPY ./Server.java /opt/
COPY ./scripts/init-softhsm.sh /opt/

WORKDIR /opt
VOLUME /certs

RUN apt-get -y update && apt-get -y install libssl3 softhsm opensc gnutls-bin && rm -rf /var/lib/api/lists/*

ENTRYPOINT ["sh", "./init-softhsm.sh"]