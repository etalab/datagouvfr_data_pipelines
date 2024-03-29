-- Manually run the following:
-- CREATE SCHEMA IF NOT EXISTS metric;
-- CREATE DATABASE metric;

-- Logs visits tables
CREATE TABLE IF NOT EXISTS metric.visits_datasets
(
    __id SERIAL PRIMARY KEY,
    date_metric DATE,
    dataset_id CHARACTER VARYING,
    organization_id CHARACTER VARYING,
    nb_visit INTEGER
);
CREATE TABLE IF NOT EXISTS metric.visits_reuses
(
    __id SERIAL PRIMARY KEY,
    date_metric DATE,
    reuse_id CHARACTER VARYING,
    organization_id CHARACTER VARYING,
    nb_visit INTEGER
);
CREATE TABLE IF NOT EXISTS metric.visits_organizations
(
    __id SERIAL PRIMARY KEY,
    date_metric DATE,
    organization_id CHARACTER VARYING,
    nb_visit INTEGER
);
CREATE TABLE IF NOT EXISTS metric.visits_resources
(
    __id SERIAL PRIMARY KEY,
    date_metric DATE,
    resource_id CHARACTER VARYING,
    dataset_id CHARACTER VARYING,
    organization_id CHARACTER VARYING,
    nb_visit INTEGER
);

-- Matomo tables
CREATE TABLE IF NOT EXISTS metric.matomo_datasets
(
    __id SERIAL PRIMARY KEY,
    date_metric DATE,
    dataset_id CHARACTER VARYING,
    organization_id CHARACTER VARYING,
    nb_outlink INTEGER
);
CREATE TABLE IF NOT EXISTS metric.matomo_reuses
(
    __id SERIAL PRIMARY KEY,
    date_metric DATE,
    reuse_id CHARACTER VARYING,
    organization_id CHARACTER VARYING,
    nb_outlink INTEGER
);
CREATE TABLE IF NOT EXISTS metric.matomo_organizations
(
    __id SERIAL PRIMARY KEY,
    date_metric DATE,
    organization_id CHARACTER VARYING,
    nb_outlink INTEGER
);


-- Aggregated metrics tables
CREATE MATERIALIZED VIEW IF NOT EXISTS metric.metrics_datasets AS
    SELECT visits.__id as __id,
            COALESCE(visits.date_metric, matomo.date_metric) as date_metric,
           COALESCE(visits.dataset_id, matomo.dataset_id) as dataset_id,
           COALESCE(visits.organization_id, matomo.organization_id) as organization_id,
           visits.nb_visit,
           matomo.nb_outlink,
           resources.nb_visit as resource_nb_download
    FROM metric.visits_datasets visits
    FULL OUTER JOIN metric.matomo_datasets matomo
    ON visits.dataset_id = matomo.dataset_id AND
       visits.date_metric = matomo.date_metric
    LEFT OUTER JOIN (
        SELECT dataset_id, date_metric, sum(nb_visit) as nb_visit FROM metric.visits_resources
        GROUP BY dataset_id, date_metric
    ) resources
    ON COALESCE(visits.dataset_id, matomo.dataset_id) = resources.dataset_id AND
       COALESCE(visits.date_metric, matomo.date_metric) = resources.date_metric
;


CREATE MATERIALIZED VIEW IF NOT EXISTS metric.metrics_reuses AS
    SELECT visits.__id as __id,
           COALESCE(visits.date_metric, matomo.date_metric) as date_metric,
           COALESCE(visits.reuse_id, matomo.reuse_id) as reuse_id,
           COALESCE(visits.organization_id, matomo.organization_id) as organization_id,
           visits.nb_visit,
           matomo.nb_outlink
    FROM metric.visits_reuses visits
    FULL OUTER JOIN metric.matomo_reuses matomo
    ON visits.reuse_id = matomo.reuse_id AND
       visits.date_metric = matomo.date_metric
;

CREATE MATERIALIZED VIEW IF NOT EXISTS metric.metrics_organizations AS
    SELECT visits.__id as __id,
           COALESCE(visits.date_metric, matomo.date_metric) as date_metric,
           COALESCE(visits.organization_id, matomo.organization_id) as organization_id,
           datasets.nb_visit as dataset_nb_visit,
           datasets.resource_nb_download as resource_nb_download,
           reuses.nb_visit as reuse_nb_visit,
           matomo.nb_outlink
    FROM metric.visits_organizations visits
    FULL OUTER JOIN metric.matomo_organizations matomo
    ON visits.organization_id = matomo.organization_id AND
       visits.date_metric = matomo.date_metric
    LEFT OUTER JOIN (
        SELECT organization_id, date_metric, sum(nb_visit) as nb_visit, sum(resource_nb_download) as resource_nb_download
        FROM metric.metrics_datasets
        GROUP BY organization_id, date_metric
    ) datasets
    ON COALESCE(visits.organization_id, matomo.organization_id) = datasets.organization_id AND
       COALESCE(visits.date_metric, matomo.date_metric) = datasets.date_metric
    LEFT OUTER JOIN (
        SELECT organization_id, date_metric, sum(nb_visit) as nb_visit FROM metric.metrics_reuses
        GROUP BY organization_id, date_metric
    ) reuses
    ON COALESCE(visits.organization_id, matomo.organization_id) = reuses.organization_id AND
       COALESCE(visits.date_metric, matomo.date_metric) = reuses.date_metric
;

-- Monthly aggregated metrics tables
CREATE MATERIALIZED VIEW IF NOT EXISTS metric.datasets AS
    SELECT
        MIN(__id) as __id,
        dataset_id,
        to_char(date_trunc('month', date_metric) , 'YYYY-mm') AS metric_month,
        sum(nb_visit) as monthly_visit,
        sum(resource_nb_download) as monthly_download_resource
    FROM metric.metrics_datasets
    GROUP BY metric_month, dataset_id
;

CREATE MATERIALIZED VIEW IF NOT EXISTS metric.reuses AS
    SELECT
        MIN(__id) as __id,
        reuse_id,
        to_char(date_trunc('month', date_metric) , 'YYYY-mm') AS metric_month,
        sum(nb_visit) as monthly_visit
    FROM metric.metrics_reuses
    GROUP BY metric_month, reuse_id
;

CREATE MATERIALIZED VIEW IF NOT EXISTS metric.organizations AS
    SELECT
        MIN(__id) as __id,
        organization_id,
        to_char(date_trunc('month', date_metric) , 'YYYY-mm') AS metric_month,
        sum(dataset_nb_visit) as monthly_visit_dataset,
        sum(resource_nb_download) as monthly_download_resource,
        sum(reuse_nb_visit) as monthly_visit_reuse
    FROM metric.metrics_organizations
    GROUP BY metric_month, organization_id
;

CREATE MATERIALIZED VIEW IF NOT EXISTS metric.resources AS
    SELECT
        MIN(__id) as __id,
        resource_id,
        dataset_id,
        to_char(date_trunc('month', date_metric) , 'YYYY-mm') AS metric_month,
        sum(nb_visit) as monthly_download_resource
    FROM metric.visits_resources
    GROUP BY metric_month, resource_id, dataset_id
;

-- Global site table
CREATE MATERIALIZED VIEW IF NOT EXISTS metric.site AS
    SELECT __id,
           COALESCE(datasets.metric_month, reuses.metric_month) as metric_month,
           datasets.monthly_visit as monthly_visit_dataset,
           datasets.monthly_download_resource as monthly_download_resource,
           reuses.monthly_visit as monthly_visit_reuse
    FROM (
        SELECT MIN(__id) as __id,
               metric_month,
               sum(monthly_visit) as monthly_visit,
               sum(monthly_download_resource) as monthly_download_resource
        FROM metric.datasets GROUP BY metric_month ) datasets
    FULL OUTER JOIN (
        SELECT metric_month,
        sum(monthly_visit) as monthly_visit
        FROM metric.reuses GROUP BY metric_month ) reuses
    ON datasets.metric_month = reuses.metric_month
;

-- Sum tables
CREATE MATERIALIZED VIEW IF NOT EXISTS metric.datasets_total AS
    SELECT
        MIN(__id) as __id,
        dataset_id,
        sum(nb_visit) as visit,
        sum(nb_outlink) as outlink,
        sum(resource_nb_download) as download_resource
    FROM metric.metrics_datasets
    GROUP BY dataset_id
;

CREATE MATERIALIZED VIEW IF NOT EXISTS metric.reuses_total AS
    SELECT
        MIN(__id) as __id,
        reuse_id,
        sum(nb_visit) as visit,
        sum(nb_outlink) as outlink
    FROM metric.metrics_reuses
    GROUP BY reuse_id
;

CREATE MATERIALIZED VIEW IF NOT EXISTS metric.organizations_total AS
    SELECT
        MIN(__id) as __id,
        organization_id,
        sum(dataset_nb_visit) as visit_dataset,
        sum(resource_nb_download) as download_resource,
        sum(reuse_nb_visit) as visit_reuse,
        sum(nb_outlink) as outlink
    FROM metric.metrics_organizations
    GROUP BY organization_id
;

CREATE MATERIALIZED VIEW IF NOT EXISTS metric.resources_total AS
    SELECT
        MIN(__id) as __id,
        resource_id,
        dataset_id,
        sum(nb_visit) as download_resource
    FROM metric.visits_resources
    GROUP BY resource_id, dataset_id
;


CREATE INDEX IF NOT EXISTS visits_datasets_dataset_id ON metric.visits_datasets USING btree (dataset_id);
CREATE INDEX IF NOT EXISTS visits_datasets_date_metric ON metric.visits_datasets USING btree (date_metric);
CREATE INDEX IF NOT EXISTS visits_datasets_organization_id ON metric.visits_datasets USING btree (organization_id);

CREATE INDEX IF NOT EXISTS visits_organizations_organization_id ON metric.visits_organizations USING btree (organization_id);
CREATE INDEX IF NOT EXISTS visits_organizations_date_metric ON metric.visits_organizations USING btree (date_metric);

CREATE INDEX IF NOT EXISTS visits_reuses_reuse_id ON metric.visits_reuses USING btree (reuse_id);
CREATE INDEX IF NOT EXISTS visits_reuses_date_metric ON metric.visits_reuses USING btree (date_metric);
CREATE INDEX IF NOT EXISTS visits_reuses_organization_id ON metric.visits_reuses USING btree (organization_id);

CREATE INDEX IF NOT EXISTS visits_resources_resource_id ON metric.visits_resources USING btree (resource_id);
CREATE INDEX IF NOT EXISTS visits_resources_date_metric ON metric.visits_resources USING btree (date_metric);
CREATE INDEX IF NOT EXISTS visits_resources_dataset_id ON metric.visits_resources USING btree (dataset_id);
