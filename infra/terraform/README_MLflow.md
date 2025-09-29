# MLflow Experiment Tracking Conventions

## Overview

This document defines the standards and best practices for tracking machine learning experiments using MLflow within the Rehab SaaS AI/ML project. Consistent use of these conventions ensures reproducibility, clarity, and effective collaboration.

---

## 1. MLflow Tracking Setup

### Tracking URI

Set the MLflow tracking server URI to point to the deployed server:


mlflow.set_tracking_uri("http://localhost:5001")
text

Replace with your production URI as needed.

### Experiment Declaration

Define and set the experiment name:


mlflow.set_experiment("RehabSaaS_Experiment")
text

Use descriptive names that correspond to use cases or model types.

---

## 2. Naming Conventions

- **Experiments:** Use clear names reflecting tasks, e.g., `RehabSaaS_Experiment`, `PatientRisk_V1`.
- **Runs:** Optionally assign run names for clarity:


with mlflow.start_run(run_name="RandomForest_10trees_v1"):
# train code
text

---

## 3. Parameters to Track

Log hyperparameters and configuration affecting training:

- Number of trees, layers, learning rate
- Batch size, optimizer settings
- Data versions or preprocessing steps

Example:


mlflow.log_param("n_estimators", 100)
mlflow.log_param("learning_rate", 0.01)
text

---

## 4. Metrics to Track

Log evaluation metrics for model performance:

- Accuracy, precision, recall, F1-score
- Loss, RMSE, AUC-ROC
- Training or inference time

Example:


mlflow.log_metric("accuracy", accuracy)
mlflow.log_metric("rmse", rmse)
text

---

## 5. Artifacts to Log

Save relevant files with runs:

- Serialized models (`mlflow.sklearn.log_model`)
- Plots (ROC curves, confusion matrices)
- Feature importance reports
- Data preprocessing scripts or objects

Example:


mlflow.sklearn.log_model(model, "model")
mlflow.log_artifact("plots/roc_curve.png")
text

---

## 6. Model Signatures & Input Examples (Recommended)

Log model input signatures to improve reproducibility:


from mlflow.models.signature import infer_signature
signature = infer_signature(X_train, model.predict(X_train))
mlflow.sklearn.log_model(model, "model", signature=signature, input_example=X_train[:3])
text

---

## 7. Best Practices

- Use `mlflow.autolog()` for supported libraries to automate logging.
- Organize hyperparameter tuning runs as nested runs if needed.
- Avoid logging protected health information (PHI).
- Clean up old runs periodically.

---

## 8. Sample Tracking Code


import mlflow
import mlflow.sklearn
from sklearn.ensemble import RandomForestClassifier
from sklearn.datasets import load_iris
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score
mlflow.set_tracking_uri("http://localhost:5001")
mlflow.set_experiment("RehabSaaS_Experiment")
iris = load_iris()
X_train, X_test, y_train, y_test = train_test_split(iris.data, iris.target, random_state=42)
with mlflow.start_run(run_name="RandomForest_10trees"):
clf = RandomForestClassifier(n_estimators=10)
clf.fit(X_train, y_train)
preds = clf.predict(X_test)
acc = accuracy_score(y_test, preds)
text
mlflow.log_param("n_estimators", 10)
mlflow.log_metric("accuracy", acc)
mlflow.sklearn.log_model(clf, "model")

print(f"Run ID: {mlflow.active_run().info.run_id}")
print(f"Accuracy: {acc}")

text

---

## 9. Usage

- Follow these conventions when adding MLflow tracking to your training scripts.
- Maintain consistency for easy comparison and analysis.
- Confirm experiment runs appear in the MLflow server UI.

---

For questions or suggestions, please contact the ML engineering team.
