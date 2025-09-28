# ai/ml/mlflow_smoke.py
import mlflow, os, pathlib

mlflow.set_tracking_uri(os.getenv("MLFLOW_TRACKING_URI", "http://127.0.0.1:5000"))
mlflow.set_experiment("project/intake-audit")

path = pathlib.Path("tmp_artifact.txt")
path.write_text("hello mlflow")

with mlflow.start_run(run_name="smoke-run"):
    mlflow.log_param("test", "true")
    mlflow.log_metric("score", 0.42)
    mlflow.log_artifact(str(path), artifact_path="artifacts")

print("Run logged")
