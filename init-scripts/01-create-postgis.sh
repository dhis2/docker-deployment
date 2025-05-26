#!/usr/bin/env bash

psql -v -U $POSTGRESQL_USERNAME -c "CREATE EXTENSION postgis;"
