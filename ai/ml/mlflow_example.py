import mlflow
import mlflow.sklearn
from sklearn.ensemble import RandomForestClassifier
from sklearn.datasets import load_iris
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score

# Set the MLflow tracking URI (adjust if MLflow tracking server is remote)
mlflow.set_tracking_uri("http://localhost:5001")

# Set experiment name
mlflow.set_experiment("RehabSaaS_Experiment")

# Load sample data
iris = load_iris()
X_train, X_test, y_train, y_test = train_test_split(iris.data, iris.target, random_state=42)

with mlflow.start_run():
    clf = RandomForestClassifier(n_estimators=10)
    clf.fit(X_train, y_train)

    preds = clf.predict(X_test)
    acc = accuracy_score(y_test, preds)

    # Log parameter
    mlflow.log_param("n_estimators", 10)
    # Log metric
    mlflow.log_metric("accuracy", acc)
    # Log model
    mlflow.sklearn.log_model(clf, "model")

    print(f"Run ID: {mlflow.active_run().info.run_id}")
    print(f"Accuracy: {acc}")
