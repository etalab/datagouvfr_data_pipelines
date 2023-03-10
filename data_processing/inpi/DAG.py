from airflow.models import DAG
from datetime import timedelta
from airflow.operators.bash import BashOperator
from airflow.operators.python import PythonOperator, ShortCircuitOperator
from airflow.utils.dates import days_ago
from datagouvfr_data_pipelines.config import (
    AIRFLOW_DAG_TMP,
)
from datagouvfr_data_pipelines.data_processing.inpi.task_functions import (
    get_start_date_minio,
    get_latest_files_from_start_date,
    check_emptiness,
    upload_minio_original_files,
    get_latest_db,
    update_db,
    upload_minio_db,
    upload_minio_synthese_files,
    upload_latest_date_inpi_minio,
    clean_db_dirigeant_pp,
    clean_db_dirigeant_pm,
    create_index_clean_db,
    upload_minio_clean_db,
    create_clean_db,
    notification_mattermost,
)

TMP_FOLDER = f"{AIRFLOW_DAG_TMP}inpi/"

with DAG(
    dag_id='data_processing_inpi_dirigeants',
    schedule_interval='0 14 * * *',
    start_date=days_ago(1),
    catchup=False,
    dagrun_timeout=timedelta(minutes=(60 * 8)),
    tags=["data_processing", "inpi", "dirigeants"],
    params={},
) as dag:

    clean_previous_outputs = BashOperator(
        task_id='clean_previous_outputs',
        bash_command=f"rm -rf {TMP_FOLDER} && mkdir -p {TMP_FOLDER}"
    )

    get_start_date = PythonOperator(
        task_id="get_start_date",
        python_callable=get_start_date_minio
    )

    get_latest_files = PythonOperator(
        task_id="get_latest_files",
        python_callable=get_latest_files_from_start_date
    )

    is_empty_folders = ShortCircuitOperator(
        task_id="is_empty_folders",
        python_callable=check_emptiness
    )

    upload_inpi_files_to_minio = PythonOperator(
        task_id="upload_inpi_files_to_minio",
        python_callable=upload_minio_original_files
    )

    get_latest_sqlite_db = PythonOperator(
        task_id="get_latest_sqlite_db",
        python_callable=get_latest_db
    )

    update_sqlite_db = PythonOperator(
        task_id="update_sqlite_db",
        python_callable=update_db
    )

    upload_minio_db = PythonOperator(
        task_id="upload_minio_db",
        python_callable=upload_minio_db
    )

    upload_synthese_files_to_minio = PythonOperator(
        task_id="upload_synthese_files_to_minio",
        python_callable=upload_minio_synthese_files
    )

    create_clean_db = PythonOperator(
        task_id="create_clean_db",
        python_callable=create_clean_db
    )

    clean_db_pp = PythonOperator(
        task_id="clean_db_pp",
        python_callable=clean_db_dirigeant_pp
    )

    clean_db_pm = PythonOperator(
        task_id="clean_db_pm",
        python_callable=clean_db_dirigeant_pm
    )

    create_index_clean_db = PythonOperator(
        task_id="create_index_clean_db",
        python_callable=create_index_clean_db
    )

    upload_minio_clean_db = PythonOperator(
        task_id="upload_minio_clean_db",
        python_callable=upload_minio_clean_db
    )

    upload_latest_date_inpi = PythonOperator(
        task_id="upload_latest_date_inpi",
        python_callable=upload_latest_date_inpi_minio
    )

    notification_mattermost = PythonOperator(
        task_id="notification_mattermost",
        python_callable=notification_mattermost,
    )

    get_start_date.set_upstream(clean_previous_outputs)
    get_latest_files.set_upstream(get_start_date)
    is_empty_folders.set_upstream(get_latest_files)
    upload_inpi_files_to_minio.set_upstream(is_empty_folders)
    get_latest_sqlite_db.set_upstream(is_empty_folders)
    update_sqlite_db.set_upstream(get_latest_sqlite_db)
    upload_minio_db.set_upstream(update_sqlite_db)
    upload_synthese_files_to_minio.set_upstream(upload_minio_db)

    create_clean_db.set_upstream(update_sqlite_db)
    clean_db_pp.set_upstream(create_clean_db)
    clean_db_pm.set_upstream(clean_db_pp)
    create_index_clean_db.set_upstream(clean_db_pm)
    upload_minio_clean_db.set_upstream(create_index_clean_db)
    upload_minio_clean_db.set_upstream(upload_synthese_files_to_minio)

    upload_latest_date_inpi.set_upstream(upload_minio_clean_db)
    upload_latest_date_inpi.set_upstream(upload_inpi_files_to_minio)

    notification_mattermost.set_upstream(upload_latest_date_inpi)
