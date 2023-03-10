from airflow.models import DAG
from airflow.operators.bash import BashOperator
from airflow.operators.python import PythonOperator
from operators.clean_folder import CleanFolderOperator
from airflow.utils.dates import days_ago
from datetime import timedelta
from datagouvfr_data_pipelines.config import (
    AIRFLOW_DAG_HOME,
    AIRFLOW_DAG_TMP,
)
from datagouvfr_data_pipelines.data_processing.dvf.task_functions import (
    create_dvf_table,
    create_stats_dvf_table,
    get_epci,
    populate_dvf_table,
    populate_stats_dvf_table,
    process_dvf_stats,
    publish_stats_dvf,
    notification_mattermost,
)

TMP_FOLDER = f"{AIRFLOW_DAG_TMP}dvf/"
DAG_FOLDER = 'datagouvfr_data_pipelines/data_processing/'
DAG_NAME = 'data_processing_dvf'
DATADIR = f"{AIRFLOW_DAG_TMP}dvf/data"

default_args = {
    'email': ['geoffrey.aldebert@data.gouv.fr'],
    'email_on_failure': True
}

with DAG(
    dag_id=DAG_NAME,
    schedule_interval='15 7 1 * *',
    start_date=days_ago(1),
    catchup=False,
    dagrun_timeout=timedelta(minutes=60),
    tags=["data_processing", "dvf", "stats"],
    default_args=default_args,
) as dag:

    clean_previous_outputs = CleanFolderOperator(
        task_id="clean_previous_outputs",
        folder_path=TMP_FOLDER
    )

    download_dvf_data = BashOperator(
        task_id='download_dvf_data',
        bash_command=(
            f"sh {AIRFLOW_DAG_HOME}{DAG_FOLDER}"
            f"dvf/scripts/script_dl_dvf.sh {DATADIR}"
        )
    )

    create_dvf_table = PythonOperator(
        task_id='create_dvf_table',
        python_callable=create_dvf_table,
    )

    populate_dvf_table = PythonOperator(
        task_id='populate_dvf_table',
        python_callable=populate_dvf_table,
    )

    get_epci = PythonOperator(
        task_id='get_epci',
        python_callable=get_epci,
    )

    process_dvf_stats = PythonOperator(
        task_id='process_dvf_stats',
        python_callable=process_dvf_stats,
    )

    create_stats_dvf_table = PythonOperator(
        task_id='create_stats_dvf_table',
        python_callable=create_stats_dvf_table,
    )

    populate_stats_dvf_table = PythonOperator(
        task_id='populate_stats_dvf_table',
        python_callable=populate_stats_dvf_table,
    )

    publish_stats_dvf = PythonOperator(
        task_id='publish_stats_dvf',
        python_callable=publish_stats_dvf,
    )

    notification_mattermost = PythonOperator(
        task_id="notification_mattermost",
        python_callable=notification_mattermost,
    )

    download_dvf_data.set_upstream(clean_previous_outputs)
    create_dvf_table.set_upstream(download_dvf_data)
    populate_dvf_table.set_upstream(create_dvf_table)
    get_epci.set_upstream(populate_dvf_table)
    process_dvf_stats.set_upstream(get_epci)
    create_stats_dvf_table.set_upstream(process_dvf_stats)
    populate_stats_dvf_table.set_upstream(create_stats_dvf_table)
    publish_stats_dvf.set_upstream(populate_stats_dvf_table)
    notification_mattermost.set_upstream(publish_stats_dvf)
